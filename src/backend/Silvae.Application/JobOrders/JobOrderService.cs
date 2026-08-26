using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Application.Identity;
using Silvae.Domain.JobOrders;

namespace Silvae.Application.JobOrders;

public sealed class JobOrderService(
    ISilvaeStore store,
    CurrentUserService currentUser)
{
    /// <summary>
    /// Le commesse sono visibili a tutta l'organizzazione: il caposquadra deve
    /// sapere sotto quale lavoro ricade il cantiere in cui si trova.
    /// </summary>
    public async Task<IReadOnlyList<JobOrderDto>> GetAllAsync(
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        var jobOrders = await store.GetJobOrdersAsync(
            membership.OrganizationId,
            cancellationToken);

        return jobOrders.Select(ToDto).ToArray();
    }

    public async Task<JobOrderDto> GetAsync(
        Guid jobOrderId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        var jobOrder = await store.GetJobOrderAsync(
                membership.OrganizationId,
                jobOrderId,
                cancellationToken)
            ?? throw new ResourceNotFoundException("La commessa non esiste.");

        return ToDto(jobOrder);
    }

    public async Task<JobOrderDto> CreateAsync(
        CreateJobOrderRequest request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var code = RegistryCode.Normalize(request.Code, "della commessa");
        if (await store.JobOrderCodeExistsAsync(
                membership.OrganizationId,
                code,
                cancellationToken))
        {
            throw new RegistryConflictException(
                "Esiste già una commessa con questo codice.");
        }

        var jobOrder = new JobOrder(
            Guid.CreateVersion7(),
            membership.OrganizationId,
            code,
            request.Name,
            request.Customer);

        store.AddJobOrder(jobOrder);
        await store.SaveChangesAsync(cancellationToken);

        return ToDto(jobOrder);
    }

    public async Task<JobOrderDto> UpdateAsync(
        Guid jobOrderId,
        UpdateJobOrderRequest request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var jobOrder = await store.GetJobOrderAsync(
                membership.OrganizationId,
                jobOrderId,
                cancellationToken)
            ?? throw new ResourceNotFoundException("La commessa non esiste.");

        if (request.Name is not null)
        {
            jobOrder.Rename(request.Name);
        }

        if (request.Customer is not null)
        {
            jobOrder.SetCustomer(request.Customer);
        }

        if (request.IsActive is { } isActive)
        {
            if (isActive)
            {
                jobOrder.Reopen();
            }
            else
            {
                jobOrder.Close();
            }
        }

        await store.SaveChangesAsync(cancellationToken);

        return ToDto(jobOrder);
    }

    private static JobOrderDto ToDto(JobOrder jobOrder)
    {
        return new JobOrderDto(
            jobOrder.Id,
            jobOrder.Code,
            jobOrder.Name,
            jobOrder.Customer,
            jobOrder.IsActive,
            jobOrder.Version,
            jobOrder.UpdatedAt);
    }
}

public sealed record JobOrderDto(
    Guid Id,
    string Code,
    string Name,
    string? Customer,
    bool IsActive,
    long Version,
    DateTimeOffset UpdatedAt);

public sealed record CreateJobOrderRequest(
    string Code,
    string Name,
    string? Customer);

/// <summary>
/// Modifica parziale: un campo assente resta com'è. Per svuotare il cliente si
/// invia una stringa vuota, che non è la stessa cosa di non inviare il campo.
/// </summary>
public sealed record UpdateJobOrderRequest(
    string? Name,
    string? Customer,
    bool? IsActive);
