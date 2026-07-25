using Silvae.Application.Identity;

namespace Silvae.Api.Endpoints;

public static class IdentityEndpoints
{
    public static IEndpointRouteBuilder MapIdentityEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
                "/api/me",
                async (
                    CurrentUserService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.GetAsync(cancellationToken)))
            .RequireAuthorization()
            .WithName("GetCurrentUser")
            .WithTags("Identity");

        return endpoints;
    }
}
