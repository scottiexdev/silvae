using System.Globalization;
using Silvae.Application.JobOrders;

namespace Silvae.Api.Endpoints;

public static class JobOrderEndpoints
{
    public static IEndpointRouteBuilder MapJobOrderEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/job-orders")
            .RequireAuthorization()
            .WithTags("JobOrders");

        group.MapGet(
                "",
                async (
                    JobOrderService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.GetAllAsync(cancellationToken)))
            .WithName("GetJobOrders");

        group.MapGet(
                "/{jobOrderId:guid}",
                async (
                    Guid jobOrderId,
                    JobOrderService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(
                        await service.GetAsync(jobOrderId, cancellationToken)))
            .WithName("GetJobOrder");

        group.MapPost(
                "",
                async (
                    CreateJobOrderRequest request,
                    JobOrderService service,
                    CancellationToken cancellationToken) =>
                {
                    var jobOrder = await service.CreateAsync(
                        request,
                        cancellationToken);
                    return TypedResults.Created(
                        string.Create(
                            CultureInfo.InvariantCulture,
                            $"/api/job-orders/{jobOrder.Id}"),
                        jobOrder);
                })
            .WithName("CreateJobOrder");

        group.MapPatch(
                "/{jobOrderId:guid}",
                async (
                    Guid jobOrderId,
                    UpdateJobOrderRequest request,
                    JobOrderService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.UpdateAsync(
                        jobOrderId,
                        request,
                        cancellationToken)))
            .WithName("UpdateJobOrder");

        return endpoints;
    }
}
