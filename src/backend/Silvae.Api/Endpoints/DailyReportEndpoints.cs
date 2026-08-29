using Silvae.Api.Endpoints.Filters;
using Silvae.Application.DailyReports;
using Silvae.Application.Identity;
using Silvae.Infrastructure.Export;

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
                "",
                async (
                    [AsParameters] DailyReportQuery query,
                    DailyReportService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.SearchAsync(
                        query.ToFilter(),
                        cancellationToken)))
            .WithName("SearchDailyReports");

        group.MapGet(
                "/export.csv",
                async (
                    [AsParameters] DailyReportQuery query,
                    DailyReportService service,
                    CancellationToken cancellationToken) =>
                {
                    var rows = await service.ExportAsync(
                        query.ToFilter(),
                        cancellationToken);
                    return Results.File(
                        DailyReportExporter.ToCsv(rows),
                        "text/csv",
                        "rendicontazione.csv");
                })
            .WithName("ExportDailyReportsCsv");

        group.MapGet(
                "/export.pdf",
                async (
                    [AsParameters] DailyReportQuery query,
                    DailyReportService service,
                    CurrentUserService currentUser,
                    TimeProvider timeProvider,
                    CancellationToken cancellationToken) =>
                {
                    var rows = await service.ExportAsync(
                        query.ToFilter(),
                        cancellationToken);
                    var membership =
                        await currentUser.GetSelectedMembershipAsync(cancellationToken);
                    return Results.File(
                        DailyReportExporter.ToPdf(
                            rows,
                            membership.DisplayName,
                            timeProvider.GetUtcNow()),
                        "application/pdf",
                        "rendicontazione.pdf");
                })
            .WithName("ExportDailyReportsPdf");

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
                    SubmitDailyReportRequest request,
                    DailyReportService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.SubmitAsync(
                        reportId,
                        request.Signature,
                        cancellationToken)))
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
