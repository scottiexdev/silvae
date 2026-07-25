namespace Silvae.Api.Endpoints;

public static class HealthEndpoints
{
    public static IEndpointRouteBuilder MapHealthEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
                "/api/health",
                () => TypedResults.Ok(new HealthResponse("healthy")))
            .WithName("GetHealth")
            .WithTags("System");

        return endpoints;
    }
}

public sealed record HealthResponse(string Status);
