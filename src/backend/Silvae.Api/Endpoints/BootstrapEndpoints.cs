using Microsoft.AspNetCore.Mvc;
using Silvae.Application.Organizations;

namespace Silvae.Api.Endpoints;

public static class BootstrapEndpoints
{
    public static IEndpointRouteBuilder MapBootstrapEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost(
                "/api/bootstrap/organization",
                async (
                    [FromHeader(Name = "X-Bootstrap-Secret")] string? bootstrapSecret,
                    CreateOrganizationRequest request,
                    OrganizationBootstrapService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.CreateOrganizationAsync(
                        bootstrapSecret,
                        request,
                        cancellationToken)))
            .RequireAuthorization()
            .WithName("BootstrapOrganization")
            .WithTags("Bootstrap");

        return endpoints;
    }
}
