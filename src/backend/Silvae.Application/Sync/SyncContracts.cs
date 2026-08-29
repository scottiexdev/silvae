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
/// Il contenuto del report come lo possiede il dispositivo. Una lista
/// assente significa «non toccare»: il dispositivo che non conosce ancora una
/// parte del report non deve cancellarla sincronizzando il resto. Una lista
/// presente, anche vuota, sostituisce quella sul server.
/// </summary>
public sealed record DailyReportPayload(
    Guid WorksiteId,
    DateOnly ReportDate,
    string? Notes,
    IReadOnlyList<CrewMemberPayload>? Crew = null,
    IReadOnlyList<ActivityPayload>? Activities = null,
    IReadOnlyList<SafetyCheckPayload>? SafetyChecks = null,
    IReadOnlyList<PhotoPayload>? Photos = null);

public sealed record CrewMemberPayload(Guid UserId, decimal Hours, string? Note);

public sealed record ActivityPayload(
    string Description,
    decimal? Quantity,
    string? Unit);

public sealed record SafetyCheckPayload(string Code, bool IsCompliant, string? Note);

public sealed record PhotoPayload(
    string LocalReference,
    double? Latitude,
    double? Longitude,
    DateTimeOffset CapturedAt,
    string? Caption);

/// <summary>
/// Il payload di un'operazione di invio: la conferma del caposquadra, digitata
/// in cantiere insieme al resto e accodata come tutto il resto.
/// </summary>
public sealed record SubmitPayload(string Signature);

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
    string? Signature,
    long Version,
    DateTimeOffset UpdatedAt,
    IReadOnlyList<CrewMemberPayload> Crew,
    IReadOnlyList<ActivityPayload> Activities,
    IReadOnlyList<SafetyCheckPayload> SafetyChecks,
    IReadOnlyList<PhotoPayload> Photos);
