using Silvae.Application.Organizations;

namespace Silvae.Api.Endpoints;

public static class OrganizationEndpoints
{
    public static IEndpointRouteBuilder MapOrganizationEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        // L'organizzazione è sempre quella selezionata dal contesto
        // autenticato: nel percorso non compare perché non la sceglie l'URL.
        var group = endpoints.MapGroup("/api/organization/members")
            .RequireAuthorization()
            .WithTags("Organization");

        group.MapGet(
                "",
                async (
                    MembershipService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(
                        await service.GetMembersAsync(cancellationToken)))
            .WithName("GetOrganizationMembers");

        group.MapPut(
                "/{userId:guid}",
                async (
                    Guid userId,
                    UpsertMemberRequest request,
                    MembershipService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.UpsertAsync(
                        userId,
                        request,
                        cancellationToken)))
            .WithName("UpsertOrganizationMember");

        group.MapDelete(
                "/{userId:guid}",
                async (
                    Guid userId,
                    MembershipService service,
                    CancellationToken cancellationToken) =>
                {
                    await service.RemoveAsync(userId, cancellationToken);
                    return TypedResults.NoContent();
                })
            .WithName("RemoveOrganizationMember");

        return endpoints;
    }
}
