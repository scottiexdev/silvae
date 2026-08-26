using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Application.Identity;
using Silvae.Domain.JobOrders;
using Silvae.Domain.Organizations;
using Silvae.Domain.Worksites;

namespace Silvae.Application.Worksites;

public sealed class WorksiteService(
    IRequestContext requestContext,
    ISilvaeStore store,
    CurrentUserService currentUser)
{
    public async Task<IReadOnlyList<WorksiteDto>> GetAssignedAsync(
        bool includeInactive,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        var includeAll = CanSeeEveryWorksite(membership);
        var worksites = await store.GetWorksitesAsync(
            membership.OrganizationId,
            requestContext.UserId,
            includeAll,

            // Un cantiere chiuso riguarda chi tiene l'anagrafica, non chi ci
            // deve andare domani mattina.
            includeInactive && includeAll,
            cancellationToken);
        var jobOrders = await GetJobOrdersByIdAsync(
            membership.OrganizationId,
            cancellationToken);

        return worksites.Select(item => ToDto(item, jobOrders)).ToArray();
    }

    public async Task<WorksiteDetailDto> GetAsync(
        Guid worksiteId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var worksite = await RequireWorksiteAsync(
            membership.OrganizationId,
            worksiteId,
            cancellationToken);

        return await ToDetailAsync(
            worksite,
            membership.OrganizationId,
            cancellationToken);
    }

    public async Task<WorksiteDetailDto> CreateAsync(
        CreateWorksiteRequest request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var code = RegistryCode.Normalize(request.Code, "del cantiere");
        if (await store.WorksiteCodeExistsAsync(
                membership.OrganizationId,
                code,
                cancellationToken))
        {
            throw new RegistryConflictException(
                "Esiste già un cantiere con questo codice.");
        }

        var worksite = new Worksite(
            Guid.CreateVersion7(),
            membership.OrganizationId,
            code,
            request.Name);

        if (!string.IsNullOrWhiteSpace(request.Address))
        {
            worksite.SetAddress(request.Address);
        }

        if (request.JobOrderId is { } jobOrderId)
        {
            await RequireJobOrderAsync(
                membership.OrganizationId,
                jobOrderId,
                cancellationToken);
            worksite.AssignToJobOrder(jobOrderId);
        }

        store.AddWorksite(worksite);
        await store.SaveChangesAsync(cancellationToken);

        return await ToDetailAsync(
            worksite,
            membership.OrganizationId,
            cancellationToken);
    }

    public async Task<WorksiteDetailDto> UpdateAsync(
        Guid worksiteId,
        UpdateWorksiteRequest request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var worksite = await RequireWorksiteAsync(
            membership.OrganizationId,
            worksiteId,
            cancellationToken);

        if (request.Name is not null)
        {
            worksite.Rename(request.Name);
        }

        if (request.Address is not null)
        {
            worksite.SetAddress(request.Address);
        }

        if (request.JobOrderId is { } jobOrderId)
        {
            // Un identificativo vuoto stacca il cantiere dalla commessa: il
            // campo assente significa già "lascia com'è" e da solo non
            // distinguerebbe le due intenzioni.
            if (jobOrderId == Guid.Empty)
            {
                worksite.AssignToJobOrder(null);
            }
            else
            {
                await RequireJobOrderAsync(
                    membership.OrganizationId,
                    jobOrderId,
                    cancellationToken);
                worksite.AssignToJobOrder(jobOrderId);
            }
        }

        if (request.IsActive is { } isActive)
        {
            if (isActive)
            {
                worksite.Reopen();
            }
            else
            {
                worksite.Close();
            }
        }

        await store.SaveChangesAsync(cancellationToken);

        return await ToDetailAsync(
            worksite,
            membership.OrganizationId,
            cancellationToken);
    }

    public async Task<WorksiteDetailDto> AssignAsync(
        Guid worksiteId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var worksite = await RequireWorksiteAsync(
            membership.OrganizationId,
            worksiteId,
            cancellationToken);

        // L'assegnazione decide cosa l'operatore vede e sincronizza: assegnare
        // chi non è membro dell'organizzazione aprirebbe un varco nel tenant.
        _ = await store.GetMembershipAsync(
                membership.OrganizationId,
                userId,
                cancellationToken)
            ?? throw new RegistryValidationException(
                "La persona non appartiene all'organizzazione.");

        worksite.Assign(userId);
        await store.SaveChangesAsync(cancellationToken);

        return await ToDetailAsync(
            worksite,
            membership.OrganizationId,
            cancellationToken);
    }

    public async Task<WorksiteDetailDto> UnassignAsync(
        Guid worksiteId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var worksite = await RequireWorksiteAsync(
            membership.OrganizationId,
            worksiteId,
            cancellationToken);

        worksite.Unassign(userId);
        await store.SaveChangesAsync(cancellationToken);

        return await ToDetailAsync(
            worksite,
            membership.OrganizationId,
            cancellationToken);
    }

    private static bool CanSeeEveryWorksite(UserMembership membership)
    {
        return membership.Role is OrganizationRole.Administrator or
            OrganizationRole.Coordinator;
    }

    private static WorksiteDto ToDto(
        Worksite worksite,
        IReadOnlyDictionary<Guid, JobOrder> jobOrders)
    {
        var jobOrder = worksite.JobOrderId is null
            ? null
            : jobOrders.GetValueOrDefault(worksite.JobOrderId.Value);

        return new WorksiteDto(
            worksite.Id,
            worksite.Code,
            worksite.Name,
            worksite.Address,
            worksite.JobOrderId,
            jobOrder?.Code,
            jobOrder?.Name,
            worksite.IsActive,
            worksite.Version,
            worksite.UpdatedAt);
    }

    private async Task<Dictionary<Guid, JobOrder>> GetJobOrdersByIdAsync(
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        var jobOrders = await store.GetJobOrdersAsync(
            organizationId,
            cancellationToken);

        return jobOrders.ToDictionary(item => item.Id);
    }

    private async Task<Worksite> RequireWorksiteAsync(
        Guid organizationId,
        Guid worksiteId,
        CancellationToken cancellationToken)
    {
        return await store.GetWorksiteAsync(
                organizationId,
                worksiteId,
                cancellationToken)
            ?? throw new ResourceNotFoundException("Il cantiere non esiste.");
    }

    private async Task RequireJobOrderAsync(
        Guid organizationId,
        Guid jobOrderId,
        CancellationToken cancellationToken)
    {
        _ = await store.GetJobOrderAsync(
                organizationId,
                jobOrderId,
                cancellationToken)
            ?? throw new RegistryValidationException("La commessa non esiste.");
    }

    private async Task<WorksiteDetailDto> ToDetailAsync(
        Worksite worksite,
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        var jobOrders = await GetJobOrdersByIdAsync(organizationId, cancellationToken);
        var members = (await store.GetOrganizationMembersAsync(
                organizationId,
                cancellationToken))
            .ToDictionary(item => item.UserId);

        var assignments = worksite.Assignments
            .Select(assignment =>
            {
                var member = members.GetValueOrDefault(assignment.UserId);
                return new WorksiteMemberDto(
                    assignment.UserId,
                    member?.DisplayName ?? string.Empty,
                    member?.Role.ToString() ?? string.Empty);
            })
            .OrderBy(item => item.DisplayName, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return new WorksiteDetailDto(
            ToDto(worksite, jobOrders),
            assignments);
    }
}

public sealed record WorksiteDto(
    Guid Id,
    string Code,
    string Name,
    string? Address,
    Guid? JobOrderId,
    string? JobOrderCode,
    string? JobOrderName,
    bool IsActive,
    long Version,
    DateTimeOffset UpdatedAt);

public sealed record WorksiteDetailDto(
    WorksiteDto Worksite,
    IReadOnlyList<WorksiteMemberDto> Assignments);

public sealed record WorksiteMemberDto(
    Guid UserId,
    string DisplayName,
    string Role);

public sealed record CreateWorksiteRequest(
    string Code,
    string Name,
    string? Address,
    Guid? JobOrderId);

/// <summary>
/// Modifica parziale: un campo assente resta com'è. L'indirizzo si svuota con
/// una stringa vuota e la commessa si stacca con un identificativo vuoto.
/// </summary>
public sealed record UpdateWorksiteRequest(
    string? Name,
    string? Address,
    Guid? JobOrderId,
    bool? IsActive);
