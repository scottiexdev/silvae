using Silvae.Domain.Organizations;

namespace Silvae.Application.Common;

/// <summary>
/// Autorizzazione applicativa sull'anagrafica. Il ruolo arriva sempre dalla
/// membership verificata sul database, mai da un valore inviato dal client.
/// </summary>
public static class RoleAuthorization
{
    /// <summary>
    /// Commesse, cantieri e assegnazioni: chi coordina il lavoro li gestisce.
    /// </summary>
    public static void RequireRegistryManager(UserMembership membership)
    {
        ArgumentNullException.ThrowIfNull(membership);

        if (membership.Role is not (OrganizationRole.Administrator or
            OrganizationRole.Coordinator))
        {
            throw new ResourceAccessDeniedException(
                "Solo un amministratore o un coordinatore può modificare l'anagrafica.");
        }
    }

    /// <summary>
    /// Membership e ruoli: decidere chi entra nell'organizzazione resta
    /// dell'amministratore.
    /// </summary>
    public static void RequireAdministrator(UserMembership membership)
    {
        ArgumentNullException.ThrowIfNull(membership);

        if (membership.Role != OrganizationRole.Administrator)
        {
            throw new ResourceAccessDeniedException(
                "Solo un amministratore può gestire i membri dell'organizzazione.");
        }
    }
}
