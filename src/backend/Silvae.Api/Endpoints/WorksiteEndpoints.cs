using Silvae.Application.Worksites;

namespace Silvae.Api.Endpoints;

public static class WorksiteEndpoints
{
    public static IEndpointRouteBuilder MapWorksiteEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
                "/api/worksites",
                async (
                    WorksiteService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(
                        await service.GetAssignedAsync(cancellationToken)))
            .RequireAuthorization()
            .WithName("GetAssignedWorksites")
            .WithTags("Worksites");

        return endpoints;
    }
}
