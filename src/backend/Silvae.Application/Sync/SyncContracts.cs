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

/// <summary>
/// Il contenuto del rapportino come lo possiede il dispositivo. Una lista
/// assente significa «non toccare»: il dispositivo che non conosce ancora una
/// parte del rapportino non deve cancellarla sincronizzando il resto. Una lista
/// presente, anche vuota, sostituisce quella sul server.
/// </summary>
public sealed record DailyReportPayload(
    Guid WorksiteId,
    DateOnly ReportDate,
    string? Notes,
    IReadOnlyList<CrewMemberPayload>? Crew = null,
    IReadOnlyList<ActivityPayload>? Activities = null,
    IReadOnlyList<SafetyCheckPayload>? SafetyChecks = null);

public sealed record CrewMemberPayload(Guid UserId, decimal Hours, string? Note);

public sealed record ActivityPayload(
    string Description,
    decimal? Quantity,
    string? Unit);

public sealed record SafetyCheckPayload(string Code, bool IsCompliant, string? Note);

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
    DateTimeOffset UpdatedAt,
    IReadOnlyList<CrewMemberPayload> Crew,
    IReadOnlyList<ActivityPayload> Activities,
    IReadOnlyList<SafetyCheckPayload> SafetyChecks);
