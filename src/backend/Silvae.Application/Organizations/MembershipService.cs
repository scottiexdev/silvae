using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Application.Identity;
using Silvae.Domain.Organizations;

namespace Silvae.Application.Organizations;

public sealed class MembershipService(
    ISilvaeStore store,
    CurrentUserService currentUser)
{
    public async Task<IReadOnlyList<OrganizationMemberDto>> GetMembersAsync(
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var members = await store.GetOrganizationMembersAsync(
            membership.OrganizationId,
            cancellationToken);

        return members
            .Select(ToDto)
            .OrderBy(item => item.DisplayName, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    /// <summary>
    /// Aggiunge la persona all'organizzazione o ne aggiorna ruolo e nome.
    /// L'identificativo è quello dell'utente Supabase, che deve essersi già
    /// registrato: qui non si creano account, si concede l'accesso a un
    /// account che esiste.
    /// </summary>
    public async Task<OrganizationMemberDto> UpsertAsync(
        Guid userId,
        UpsertMemberRequest request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireAdministrator(membership);

        if (userId == Guid.Empty)
        {
            throw new RegistryValidationException(
                "L'identificativo della persona è obbligatorio.");
        }

        var role = ParseRole(request.Role);
        var members = await store.GetOrganizationMembersAsync(
            membership.OrganizationId,
            cancellationToken);
        var existing = members.SingleOrDefault(item => item.UserId == userId);

        if (existing is null)
        {
            var created = new UserMembership(
                membership.OrganizationId,
                userId,
                role,
                request.DisplayName);
            store.AddMembership(created);
            await store.SaveChangesAsync(cancellationToken);

            return ToDto(created);
        }

        if (existing.Role == OrganizationRole.Administrator &&
            role != OrganizationRole.Administrator)
        {
            EnsureAnotherAdministratorRemains(members, userId);
        }

        existing.ChangeRole(role);
        existing.Rename(request.DisplayName);
        await store.SaveChangesAsync(cancellationToken);

        return ToDto(existing);
    }

    public async Task RemoveAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireAdministrator(membership);

        var members = await store.GetOrganizationMembersAsync(
            membership.OrganizationId,
            cancellationToken);
        var existing = members.SingleOrDefault(item => item.UserId == userId)
            ?? throw new ResourceNotFoundException(
                "La persona non appartiene all'organizzazione.");

        if (existing.Role == OrganizationRole.Administrator)
        {
            EnsureAnotherAdministratorRemains(members, userId);
        }

        await store.RemoveMemberAsync(
            membership.OrganizationId,
            userId,
            cancellationToken);
        await store.SaveChangesAsync(cancellationToken);
    }

    /// <summary>
    /// Un'organizzazione senza amministratori non è più governabile da nessuno:
    /// gli endpoint di anagrafica richiedono un amministratore e il bootstrap
    /// richiede il segreto di deploy, che sul telefono di chi resta non c'è.
    /// </summary>
    private static void EnsureAnotherAdministratorRemains(
        IReadOnlyList<UserMembership> members,
        Guid userId)
    {
        var otherAdministrators = members.Count(item =>
            item.Role == OrganizationRole.Administrator &&
            item.UserId != userId);

        if (otherAdministrators == 0)
        {
            throw new RegistryConflictException(
                "L'organizzazione deve conservare almeno un amministratore.");
        }
    }

    private static OrganizationRole ParseRole(string role)
    {
        return Enum.TryParse<OrganizationRole>(role, ignoreCase: true, out var parsed)
            ? parsed
            : throw new RegistryValidationException(
                "Il ruolo deve essere Administrator, Coordinator, CrewLeader o Worker.");
    }

    private static OrganizationMemberDto ToDto(UserMembership membership)
    {
        return new OrganizationMemberDto(
            membership.UserId,
            membership.DisplayName,
            membership.Role.ToString());
    }
}

public sealed record OrganizationMemberDto(
    Guid UserId,
    string DisplayName,
    string Role);

public sealed record UpsertMemberRequest(
    string DisplayName,
    string Role);
