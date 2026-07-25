using System.Text.Json;
using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Application.Identity;
using Silvae.Domain.DailyReports;
using Silvae.Domain.Organizations;

namespace Silvae.Application.Sync;

public sealed class SyncService(
    IRequestContext requestContext,
    ISilvaeStore store,
    CurrentUserService currentUser,
    TimeProvider timeProvider)
{
    private static readonly JsonSerializerOptions SerializerOptions =
        new(JsonSerializerDefaults.Web);

    public async Task<PushSyncResponse> PushAsync(
        PushSyncRequest request,
        CancellationToken cancellationToken)
    {
        if (request.Operations.Count is < 1 or > 100)
        {
            throw new SyncValidationException(
                "Una richiesta di sincronizzazione deve contenere da 1 a 100 operazioni.");
        }

        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        var results = new List<SyncOperationResultDto>(request.Operations.Count);

        foreach (var operation in request.Operations)
        {
            results.Add(await ProcessAsync(
                membership,
                operation,
                cancellationToken));
        }

        return new PushSyncResponse(results, timeProvider.GetUtcNow());
    }

    public async Task<PullSyncResponse> PullAsync(
        DateTimeOffset? changedSince,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        var includeAll = CanAccessAllWorksites(membership);
        var reports = await store.GetDailyReportsChangedSinceAsync(
            membership.OrganizationId,
            requestContext.UserId,
            includeAll,
            changedSince,
            cancellationToken);

        return new PullSyncResponse(
            reports.Select(ToSyncDto).ToArray(),
            timeProvider.GetUtcNow());
    }

    private async Task<SyncOperationResultDto> ProcessAsync(
        UserMembership membership,
        SyncOperationDto operation,
        CancellationToken cancellationToken)
    {
        if (operation.OperationId == Guid.Empty || operation.EntityId == Guid.Empty)
        {
            throw new SyncValidationException(
                "operationId ed entityId sono obbligatori.");
        }

        if (operation.OrganizationId != membership.OrganizationId)
        {
            throw new OrganizationAccessDeniedException();
        }

        if (!string.Equals(
                operation.EntityType,
                "dailyReport",
                StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(
                operation.OperationType,
                "upsert",
                StringComparison.OrdinalIgnoreCase))
        {
            throw new SyncValidationException(
                "Questa versione supporta solo l'upsert di dailyReport.");
        }

        var processedOperation = await store.GetProcessedOperationAsync(
                membership.OrganizationId,
                operation.OperationId,
                cancellationToken);
        if (processedOperation is not null)
        {
            return new SyncOperationResultDto(
                operation.OperationId,
                processedOperation.EntityId,
                processedOperation.EntityVersion,
                true);
        }

        DailyReportPayload payload;
        try
        {
            payload = operation.Payload.Deserialize<DailyReportPayload>(SerializerOptions)
                ?? throw new JsonException();
        }
        catch (JsonException)
        {
            throw new SyncValidationException(
                "Il payload del rapportino non è valido.");
        }

        var includeAll = CanAccessAllWorksites(membership);
        if (!await store.CanAccessWorksiteAsync(
                membership.OrganizationId,
                payload.WorksiteId,
                requestContext.UserId,
                includeAll,
                cancellationToken))
        {
            throw new ResourceAccessDeniedException(
                "Il cantiere non è assegnato all'utente.");
        }

        var now = timeProvider.GetUtcNow();
        var report = await store.GetDailyReportAsync(
            membership.OrganizationId,
            operation.EntityId,
            cancellationToken);

        if (report is null)
        {
            if (operation.ExpectedVersion != 0)
            {
                throw new SyncConflictException(0);
            }

            report = DailyReport.Create(
                operation.EntityId,
                membership.OrganizationId,
                payload.WorksiteId,
                requestContext.UserId,
                payload.ReportDate,
                payload.Notes,
                now);
            store.AddDailyReport(report);
        }
        else
        {
            if (report.Version != operation.ExpectedVersion)
            {
                throw new SyncConflictException(report.Version);
            }

            if (report.AuthorId != requestContext.UserId &&
                membership.Role is not (
                    OrganizationRole.Administrator or OrganizationRole.Coordinator))
            {
                throw new ResourceAccessDeniedException(
                    "Il rapportino appartiene a un altro operatore.");
            }

            report.UpdateDraft(
                payload.WorksiteId,
                payload.ReportDate,
                payload.Notes,
                now);
        }

        store.AddProcessedOperation(new ProcessedSyncOperation(
            membership.OrganizationId,
            operation.OperationId,
            operation.EntityId,
            report.Version,
            now));
        await store.SaveChangesAsync(cancellationToken);

        return new SyncOperationResultDto(
            operation.OperationId,
            operation.EntityId,
            report.Version,
            false);
    }

    private static bool CanAccessAllWorksites(UserMembership membership)
    {
        return membership.Role is
            OrganizationRole.Administrator or OrganizationRole.Coordinator;
    }

    private static DailyReportSyncDto ToSyncDto(DailyReport report)
    {
        return new DailyReportSyncDto(
            report.Id,
            report.OrganizationId,
            report.WorksiteId,
            report.AuthorId,
            report.ReportDate,
            report.Notes,
            report.Status.ToString(),
            report.Version,
            report.UpdatedAt);
    }
}
