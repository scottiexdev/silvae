using Silvae.Application.DailyReports;

namespace Silvae.Api.Endpoints;

public static class DailyReportEndpoints
{
    public static IEndpointRouteBuilder MapDailyReportEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/daily-reports")
            .RequireAuthorization()
            .WithTags("DailyReports");

        group.MapGet(
                "/{reportId:guid}",
                async (
                    Guid reportId,
                    DailyReportService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(
                        await service.GetAsync(reportId, cancellationToken)))
            .WithName("GetDailyReport");

        // L'invio esiste anche qui, oltre che nella coda di sincronizzazione:
        // dall'ufficio si lavora online e non ha senso passare dalla outbox.
        group.MapPost(
                "/{reportId:guid}/submit",
                async (
                    Guid reportId,
                    DailyReportService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(
                        await service.SubmitAsync(reportId, cancellationToken)))
            .WithName("SubmitDailyReport");

        group.MapPost(
                "/{reportId:guid}/approve",
                async (
                    Guid reportId,
                    DailyReportService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(
                        await service.ApproveAsync(reportId, cancellationToken)))
            .WithName("ApproveDailyReport");

        group.MapPost(
                "/{reportId:guid}/reopen",
                async (
                    Guid reportId,
                    DailyReportService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(
                        await service.ReopenAsync(reportId, cancellationToken)))
            .WithName("ReopenDailyReport");

        return endpoints;
    }
}
