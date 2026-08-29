using System.Text.Json;
using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Application.DailyReports;
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
        var includeAll = DailyReportAuthorization.IsOfficeRole(membership);
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

    private static bool IsOperation(string value, string expected)
    {
        return string.Equals(value, expected, StringComparison.OrdinalIgnoreCase);
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
            report.Signature,
            report.Version,
            report.UpdatedAt,
            report.Crew
                .Select(member => new CrewMemberPayload(
                    member.UserId,
                    member.Hours,
                    member.Note))
                .ToArray(),
            report.Activities
                .Select(activity => new ActivityPayload(
                    activity.Description,
                    activity.Quantity,
                    activity.Unit))
                .ToArray(),
            report.SafetyChecks
                .Select(check => new SafetyCheckPayload(
                    check.Code,
                    check.IsCompliant,
                    check.Note))
                .ToArray(),
            report.Photos
                .Select(photo => new PhotoPayload(
                    photo.LocalReference,
                    photo.Latitude,
                    photo.Longitude,
                    photo.CapturedAt,
                    photo.Caption))
                .ToArray());
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

        if (!IsOperation(operation.EntityType, "dailyReport"))
        {
            throw new SyncValidationException(
                "Questa versione sincronizza soltanto i report.");
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

        var now = timeProvider.GetUtcNow();
        DailyReport report;

        if (IsOperation(operation.OperationType, "upsert"))
        {
            report = await UpsertAsync(membership, operation, now, cancellationToken);
        }
        else if (IsOperation(operation.OperationType, "submit"))
        {
            // L'invio parte dal cantiere, spesso senza rete: passa dalla coda
            // come le modifiche, con la stessa versione attesa e la stessa
            // protezione contro i doppioni.
            report = await SubmitAsync(membership, operation, now, cancellationToken);
        }
        else
        {
            throw new SyncValidationException(
                "Le operazioni ammesse sono upsert e submit.");
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

    private async Task<DailyReport> UpsertAsync(
        UserMembership membership,
        SyncOperationDto operation,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        DailyReportPayload payload;
        try
        {
            payload = operation.Payload.Deserialize<DailyReportPayload>(SerializerOptions)
                ?? throw new JsonException();
        }
        catch (JsonException)
        {
            throw new SyncValidationException(
                "Il payload del report non è valido.");
        }

        var includeAll = DailyReportAuthorization.IsOfficeRole(membership);
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

        var report = await store.GetDailyReportAsync(
            membership.OrganizationId,
            operation.EntityId,
            cancellationToken);
        var content = await BuildContentAsync(
            membership.OrganizationId,
            payload,
            report,
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
                requestContext.UserId,
                content,
                now);
            store.AddDailyReport(report);
            return report;
        }

        if (report.Version != operation.ExpectedVersion)
        {
            throw new SyncConflictException(report.Version);
        }

        DailyReportAuthorization.RequireCanEdit(
            report,
            membership,
            requestContext.UserId);
        report.UpdateContent(content, requestContext.UserId, now);

        return report;
    }

    private async Task<DailyReport> SubmitAsync(
        UserMembership membership,
        SyncOperationDto operation,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        var report = await store.GetDailyReportAsync(
                membership.OrganizationId,
                operation.EntityId,
                cancellationToken)
            ?? throw new SyncValidationException(
                "Il report da inviare non esiste sul server.");

        if (report.Version != operation.ExpectedVersion)
        {
            throw new SyncConflictException(report.Version);
        }

        SubmitPayload submitPayload;
        try
        {
            submitPayload = operation.Payload.Deserialize<SubmitPayload>(SerializerOptions)
                ?? throw new JsonException();
        }
        catch (JsonException)
        {
            throw new SyncValidationException(
                "L'invio richiede la conferma del caposquadra.");
        }

        DailyReportAuthorization.RequireCanEdit(
            report,
            membership,
            requestContext.UserId);
        report.Submit(requestContext.UserId, submitPayload.Signature, now);

        return report;
    }

    /// <summary>
    /// Traduce il payload in contenuto di dominio. Una lista assente lascia
    /// intatta quella già registrata: un dispositivo che conosce solo una parte
    /// del report non deve cancellare il resto sincronizzando.
    /// </summary>
    private async Task<DailyReportContent> BuildContentAsync(
        Guid organizationId,
        DailyReportPayload payload,
        DailyReport? existing,
        CancellationToken cancellationToken)
    {
        IReadOnlyList<CrewEntry> crew;
        if (payload.Crew is null)
        {
            crew = existing?.Crew
                .Select(member => new CrewEntry(
                    member.UserId,
                    member.Hours,
                    member.Note))
                .ToArray() ?? [];
        }
        else
        {
            await EnsureCrewBelongsToOrganizationAsync(
                organizationId,
                payload.Crew,
                cancellationToken);
            crew = payload.Crew
                .Select(member => new CrewEntry(
                    member.UserId,
                    member.Hours,
                    member.Note))
                .ToArray();
        }

        var activities = payload.Activities is null
            ? existing?.Activities
                .Select(activity => new ActivityEntry(
                    activity.Description,
                    activity.Quantity,
                    activity.Unit))
                .ToArray() ?? []
            : payload.Activities
                .Select(activity => new ActivityEntry(
                    activity.Description,
                    activity.Quantity,
                    activity.Unit))
                .ToArray();

        var photos = payload.Photos is null
            ? existing?.Photos
                .Select(photo => new PhotoEntry(
                    photo.LocalReference,
                    photo.Latitude,
                    photo.Longitude,
                    photo.CapturedAt,
                    photo.Caption))
                .ToArray() ?? []
            : payload.Photos
                .Select(photo => new PhotoEntry(
                    photo.LocalReference,
                    photo.Latitude,
                    photo.Longitude,
                    photo.CapturedAt,
                    photo.Caption))
                .ToArray();

        var safetyChecks = payload.SafetyChecks is null
            ? existing?.SafetyChecks
                .Select(check => new SafetyCheckEntry(
                    check.Code,
                    check.IsCompliant,
                    check.Note))
                .ToArray() ?? []
            : payload.SafetyChecks
                .Select(check => new SafetyCheckEntry(
                    check.Code,
                    check.IsCompliant,
                    check.Note))
                .ToArray();

        return new DailyReportContent(
            payload.WorksiteId,
            payload.ReportDate,
            payload.Notes,
            crew,
            activities,
            safetyChecks,
            photos);
    }

    private async Task EnsureCrewBelongsToOrganizationAsync(
        Guid organizationId,
        IReadOnlyList<CrewMemberPayload> crew,
        CancellationToken cancellationToken)
    {
        if (crew.Count == 0)
        {
            return;
        }

        var members = (await store.GetOrganizationMembersAsync(
                organizationId,
                cancellationToken))
            .Select(member => member.UserId)
            .ToHashSet();

        // Le ore di chi non appartiene all'organizzazione finirebbero nella
        // rendicontazione di un tenant che non lo conosce.
        if (crew.Any(member => !members.Contains(member.UserId)))
        {
            throw new SyncValidationException(
                "La squadra contiene una persona esterna all'organizzazione.");
        }
    }
}
