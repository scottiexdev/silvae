using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Domain.Organizations;

namespace Silvae.Application.Organizations;

/// <summary>
/// Crea la prima organizzazione e il suo amministratore. È l'unico punto in cui
/// una membership nasce senza che qualcuno la conceda dall'interno: chi possiede
/// il segreto di deploy è chi ha configurato l'ambiente.
/// </summary>
public sealed class OrganizationBootstrapService(
    IRequestContext requestContext,
    ISilvaeStore store,
    IBootstrapSecret bootstrapSecret)
{
    public async Task<BootstrapResultDto> CreateOrganizationAsync(
        string? presentedSecret,
        CreateOrganizationRequest request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        if (requestContext.UserId == Guid.Empty)
        {
            throw new AuthenticationRequiredException();
        }

        // Senza segreto configurato l'endpoint non esiste: un ambiente che non
        // ha ancora deciso di essere inizializzato non deve poterlo essere da
        // chiunque abbia un account.
        if (!bootstrapSecret.IsConfigured)
        {
            throw new ResourceAccessDeniedException(
                "Il bootstrap non è abilitato su questo ambiente.");
        }

        if (!bootstrapSecret.Matches(presentedSecret))
        {
            throw new ResourceAccessDeniedException(
                "Il segreto di bootstrap non è valido.");
        }

        var organization = new Organization(
            Guid.CreateVersion7(),
            request.OrganizationName);
        var membership = new UserMembership(
            organization.Id,
            requestContext.UserId,
            OrganizationRole.Administrator,
            request.DisplayName);

        store.AddOrganization(organization);
        store.AddMembership(membership);
        await store.SaveChangesAsync(cancellationToken);

        return new BootstrapResultDto(
            organization.Id,
            organization.Name,
            membership.UserId,
            membership.DisplayName,
            membership.Role.ToString());
    }
}

public sealed record CreateOrganizationRequest(
    string OrganizationName,
    string DisplayName);

public sealed record BootstrapResultDto(
    Guid OrganizationId,
    string OrganizationName,
    Guid UserId,
    string DisplayName,
    string Role);
