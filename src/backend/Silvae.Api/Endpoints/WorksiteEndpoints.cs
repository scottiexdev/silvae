using System.Globalization;
using Silvae.Application.Worksites;

namespace Silvae.Api.Endpoints;

public static class WorksiteEndpoints
{
    public static IEndpointRouteBuilder MapWorksiteEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/worksites")
            .RequireAuthorization()
            .WithTags("Worksites");

        group.MapGet(
                "",
                async (
                    bool? includeInactive,
                    WorksiteService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.GetAssignedAsync(
                        includeInactive ?? false,
                        cancellationToken)))
            .WithName("GetAssignedWorksites");

        group.MapGet(
                "/{worksiteId:guid}",
                async (
                    Guid worksiteId,
                    WorksiteService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(
                        await service.GetAsync(worksiteId, cancellationToken)))
            .WithName("GetWorksite");

        group.MapPost(
                "",
                async (
                    CreateWorksiteRequest request,
                    WorksiteService service,
                    CancellationToken cancellationToken) =>
                {
                    var worksite = await service.CreateAsync(
                        request,
                        cancellationToken);
                    return TypedResults.Created(
                        string.Create(
                            CultureInfo.InvariantCulture,
                            $"/api/worksites/{worksite.Worksite.Id}"),
                        worksite);
                })
            .WithName("CreateWorksite");

        group.MapPatch(
                "/{worksiteId:guid}",
                async (
                    Guid worksiteId,
                    UpdateWorksiteRequest request,
                    WorksiteService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.UpdateAsync(
                        worksiteId,
                        request,
                        cancellationToken)))
            .WithName("UpdateWorksite");

        group.MapPut(
                "/{worksiteId:guid}/assignments/{userId:guid}",
                async (
                    Guid worksiteId,
                    Guid userId,
                    WorksiteService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.AssignAsync(
                        worksiteId,
                        userId,
                        cancellationToken)))
            .WithName("AssignWorksiteMember");

        group.MapDelete(
                "/{worksiteId:guid}/assignments/{userId:guid}",
                async (
                    Guid worksiteId,
                    Guid userId,
                    WorksiteService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.UnassignAsync(
                        worksiteId,
                        userId,
                        cancellationToken)))
            .WithName("UnassignWorksiteMember");

        return endpoints;
    }
}
