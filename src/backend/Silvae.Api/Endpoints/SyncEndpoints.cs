using Silvae.Application.Sync;

namespace Silvae.Api.Endpoints;

public static class SyncEndpoints
{
    public static IEndpointRouteBuilder MapSyncEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/sync")
            .RequireAuthorization()
            .WithTags("Sync");

        group.MapPost(
                "/push",
                async (
                    PushSyncRequest request,
                    SyncService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(
                        await service.PushAsync(request, cancellationToken)))
            .WithName("PushSyncOperations");

        group.MapGet(
                "/pull",
                async (
                    DateTimeOffset? changedSince,
                    SyncService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(
                        await service.PullAsync(
                            changedSince,
                            cancellationToken)))
            .WithName("PullSyncChanges");

        return endpoints;
    }
}
