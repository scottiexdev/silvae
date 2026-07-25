using System.Text.Json;

namespace Silvae.Application.Sync;

public sealed record PushSyncRequest(IReadOnlyList<SyncOperationDto> Operations);

public sealed record SyncOperationDto(
    Guid OperationId,
    Guid OrganizationId,
    Guid EntityId,
    string EntityType,
    string OperationType,
    long ExpectedVersion,
    JsonElement Payload,
    DateTimeOffset CreatedAt);

public sealed record DailyReportPayload(
    Guid WorksiteId,
    DateOnly ReportDate,
    string? Notes);

public sealed record PushSyncResponse(
    IReadOnlyList<SyncOperationResultDto> Operations,
    DateTimeOffset ServerTime);

public sealed record SyncOperationResultDto(
    Guid OperationId,
    Guid EntityId,
    long Version,
    bool WasDuplicate);

public sealed record PullSyncResponse(
    IReadOnlyList<DailyReportSyncDto> DailyReports,
    DateTimeOffset ServerTime);

public sealed record DailyReportSyncDto(
    Guid Id,
    Guid OrganizationId,
    Guid WorksiteId,
    Guid AuthorId,
    DateOnly ReportDate,
    string? Notes,
    string Status,
    long Version,
    DateTimeOffset UpdatedAt);
