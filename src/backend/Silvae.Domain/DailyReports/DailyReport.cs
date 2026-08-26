namespace Silvae.Domain.DailyReports;

public enum DailyReportStatus
{
    Draft,
    Submitted,
    Approved,
    Reopened,
}

public sealed class DailyReport
{
    private readonly List<DailyReportCrewMember> _crew = [];
    private readonly List<DailyReportActivity> _activities = [];
    private readonly List<DailyReportSafetyCheck> _safetyChecks = [];
    private readonly List<DailyReportAuditEntry> _audit = [];

    private DailyReport()
    {
    }

    private DailyReport(
        Guid id,
        Guid organizationId,
        Guid authorId,
        DailyReportContent content,
        DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(content);

        if (id == Guid.Empty ||
            organizationId == Guid.Empty ||
            content.WorksiteId == Guid.Empty ||
            authorId == Guid.Empty)
        {
            throw new ArgumentException("Gli identificativi sono obbligatori.");
        }

        EnsureDateIsNotInTheFuture(content.ReportDate, now);

        Id = id;
        OrganizationId = organizationId;
        WorksiteId = content.WorksiteId;
        AuthorId = authorId;
        ReportDate = content.ReportDate;
        Notes = NormalizeNotes(content.Notes);
        Status = DailyReportStatus.Draft;
        Version = 1;
        CreatedAt = now;
        UpdatedAt = now;
        ReplaceContent(content);
        Record(DailyReportAction.Created, authorId, now);
    }

    public Guid Id { get; private set; }

    public Guid OrganizationId { get; private set; }

    public Guid WorksiteId { get; private set; }

    public Guid AuthorId { get; private set; }

    public DateOnly ReportDate { get; private set; }

    public string? Notes { get; private set; }

    public DailyReportStatus Status { get; private set; }

    public long Version { get; private set; }

    public DateTimeOffset CreatedAt { get; private set; }

    public DateTimeOffset UpdatedAt { get; private set; }

    public IReadOnlyList<DailyReportCrewMember> Crew => _crew;

    public IReadOnlyList<DailyReportActivity> Activities => _activities;

    public IReadOnlyList<DailyReportSafetyCheck> SafetyChecks => _safetyChecks;

    /// <summary>
    /// Traccia in sola aggiunta di chi ha fatto cosa. Un rapportino approvato
    /// e poi riaperto deve poter raccontare il proprio percorso: davanti a un
    /// controllo la domanda non è com'è adesso, ma come ci è arrivato.
    /// </summary>
    public IReadOnlyList<DailyReportAuditEntry> Audit => _audit;

    public static DailyReport Create(
        Guid id,
        Guid organizationId,
        Guid authorId,
        DailyReportContent content,
        DateTimeOffset now)
    {
        return new DailyReport(id, organizationId, authorId, content, now);
    }

    /// <summary>
    /// Sostituisce l'intero contenuto del rapportino. Il rapportino è un
    /// documento e il dispositivo ne possiede la versione offline: una fusione
    /// parziale lato server contraddirebbe la outbox, che accorpa le modifiche
    /// successive in un'unica operazione.
    /// </summary>
    public void UpdateContent(
        DailyReportContent content,
        Guid actorId,
        DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(content);

        if (Status is not (DailyReportStatus.Draft or DailyReportStatus.Reopened))
        {
            throw new InvalidOperationException(
                "Solo un rapportino in bozza o riaperto può essere modificato.");
        }

        if (content.WorksiteId == Guid.Empty)
        {
            throw new ArgumentException(
                "Il cantiere è obbligatorio.",
                nameof(content));
        }

        EnsureDateIsNotInTheFuture(content.ReportDate, now);

        WorksiteId = content.WorksiteId;
        ReportDate = content.ReportDate;
        Notes = NormalizeNotes(content.Notes);
        ReplaceContent(content);
        Touch(now);
        Record(DailyReportAction.Updated, actorId, now);
    }

    public void Submit(Guid actorId, DateTimeOffset now)
    {
        if (Status is not (DailyReportStatus.Draft or DailyReportStatus.Reopened))
        {
            throw new InvalidOperationException("Il rapportino non può essere inviato.");
        }

        // Un rapportino senza nessuno in squadra non rendiconta niente: è la
        // riga che l'ufficio userà per le ore, e mancherebbe.
        if (_crew.Count == 0)
        {
            throw new InvalidOperationException(
                "Un rapportino senza squadra non può essere inviato.");
        }

        Status = DailyReportStatus.Submitted;
        Touch(now);
        Record(DailyReportAction.Submitted, actorId, now);
    }

    public void Approve(Guid actorId, DateTimeOffset now)
    {
        if (Status != DailyReportStatus.Submitted)
        {
            throw new InvalidOperationException(
                "Solo un rapportino inviato può essere approvato.");
        }

        Status = DailyReportStatus.Approved;
        Touch(now);
        Record(DailyReportAction.Approved, actorId, now);
    }

    public void Reopen(Guid actorId, DateTimeOffset now)
    {
        if (Status is not (DailyReportStatus.Submitted or DailyReportStatus.Approved))
        {
            throw new InvalidOperationException(
                "Solo un rapportino inviato o approvato può essere riaperto.");
        }

        Status = DailyReportStatus.Reopened;
        Touch(now);
        Record(DailyReportAction.Reopened, actorId, now);
    }

    public decimal TotalHours()
    {
        return _crew.Sum(member => member.Hours);
    }

    private static void EnsureDateIsNotInTheFuture(
        DateOnly reportDate,
        DateTimeOffset now)
    {
        if (reportDate > DateOnly.FromDateTime(now.UtcDateTime).AddDays(1))
        {
            throw new ArgumentOutOfRangeException(
                nameof(reportDate),
                "La data del rapportino non può essere nel futuro.");
        }
    }

    private static string? NormalizeNotes(string? notes)
    {
        var value = string.IsNullOrWhiteSpace(notes) ? null : notes.Trim();
        return value?.Length > 4000
            ? throw new ArgumentException(
                "Le note non possono superare 4000 caratteri.",
                nameof(notes))
            : value;
    }

    private void ReplaceContent(DailyReportContent content)
    {
        _crew.Clear();
        foreach (var entry in content.Crew)
        {
            if (_crew.Any(member => member.UserId == entry.UserId))
            {
                throw new ArgumentException(
                    "La stessa persona non può comparire due volte in squadra.",
                    nameof(content));
            }

            _crew.Add(new DailyReportCrewMember(Id, entry.UserId, entry.Hours, entry.Note));
        }

        _activities.Clear();
        foreach (var entry in content.Activities)
        {
            _activities.Add(new DailyReportActivity(
                Id,
                entry.Description,
                entry.Quantity,
                entry.Unit));
        }

        _safetyChecks.Clear();
        foreach (var entry in content.SafetyChecks)
        {
            var check = new DailyReportSafetyCheck(
                Id,
                entry.Code,
                entry.IsCompliant,
                entry.Note);
            if (_safetyChecks.Any(item => item.Code == check.Code))
            {
                throw new ArgumentException(
                    "La stessa voce di sicurezza non può comparire due volte.",
                    nameof(content));
            }

            _safetyChecks.Add(check);
        }
    }

    private void Record(DailyReportAction action, Guid actorId, DateTimeOffset now)
    {
        _audit.Add(new DailyReportAuditEntry(Id, action, actorId, Version, now));
    }

    private void Touch(DateTimeOffset now)
    {
        Version++;
        UpdatedAt = now;
    }
}

public enum DailyReportAction
{
    Created,
    Updated,
    Submitted,
    Approved,
    Reopened,
}

/// <summary>
/// Il contenuto che il dispositivo possiede e invia per intero.
/// </summary>
public sealed record DailyReportContent(
    Guid WorksiteId,
    DateOnly ReportDate,
    string? Notes,
    IReadOnlyList<CrewEntry> Crew,
    IReadOnlyList<ActivityEntry> Activities,
    IReadOnlyList<SafetyCheckEntry> SafetyChecks);

public sealed record CrewEntry(Guid UserId, decimal Hours, string? Note);

public sealed record ActivityEntry(string Description, decimal? Quantity, string? Unit);

public sealed record SafetyCheckEntry(string Code, bool IsCompliant, string? Note);

public sealed class DailyReportCrewMember
{
    private DailyReportCrewMember()
    {
    }

    public DailyReportCrewMember(
        Guid dailyReportId,
        Guid userId,
        decimal hours,
        string? note)
    {
        if (userId == Guid.Empty)
        {
            throw new ArgumentException("L'operatore è obbligatorio.", nameof(userId));
        }

        if (hours <= 0m || hours > 24m)
        {
            throw new ArgumentOutOfRangeException(
                nameof(hours),
                "Le ore devono stare fra 0 escluso e 24.");
        }

        Id = Guid.CreateVersion7();
        DailyReportId = dailyReportId;
        UserId = userId;
        Hours = decimal.Round(hours, 2);
        Note = ShortText.Normalize(note, 500, nameof(note));
    }

    public Guid Id { get; private set; }

    public Guid DailyReportId { get; private set; }

    public Guid UserId { get; private set; }

    public decimal Hours { get; private set; }

    public string? Note { get; private set; }
}

public sealed class DailyReportActivity
{
    private DailyReportActivity()
    {
    }

    public DailyReportActivity(
        Guid dailyReportId,
        string description,
        decimal? quantity,
        string? unit)
    {
        if (quantity is < 0m)
        {
            throw new ArgumentOutOfRangeException(
                nameof(quantity),
                "La quantità non può essere negativa.");
        }

        Id = Guid.CreateVersion7();
        DailyReportId = dailyReportId;
        Description = ShortText.Require(description, 500, nameof(description));
        Quantity = quantity is null ? null : decimal.Round(quantity.Value, 2);
        Unit = ShortText.Normalize(unit, 16, nameof(unit));
    }

    public Guid Id { get; private set; }

    public Guid DailyReportId { get; private set; }

    public string Description { get; private set; } = string.Empty;

    /// <summary>
    /// Quantità e unità restano facoltative: servono alla rendicontazione
    /// quando la lavorazione si misura, e non tutte si misurano.
    /// </summary>
    public decimal? Quantity { get; private set; }

    public string? Unit { get; private set; }
}

public sealed class DailyReportSafetyCheck
{
    private DailyReportSafetyCheck()
    {
    }

    public DailyReportSafetyCheck(
        Guid dailyReportId,
        string code,
        bool isCompliant,
        string? note)
    {
        var normalizedNote = ShortText.Normalize(note, 500, nameof(note));

        // Una non conformità senza spiegazione non è una registrazione, è un
        // buco: chi legge il rapportino a mesi di distanza deve sapere cosa
        // mancava e perché si è lavorato lo stesso.
        if (!isCompliant && normalizedNote is null)
        {
            throw new ArgumentException(
                "Una voce di sicurezza non conforme richiede una nota.",
                nameof(note));
        }

        Id = Guid.CreateVersion7();
        DailyReportId = dailyReportId;
        Code = ShortText.Require(code, 64, nameof(code)).ToUpperInvariant();
        IsCompliant = isCompliant;
        Note = normalizedNote;
    }

    public Guid Id { get; private set; }

    public Guid DailyReportId { get; private set; }

    public string Code { get; private set; } = string.Empty;

    public bool IsCompliant { get; private set; }

    public string? Note { get; private set; }
}

public sealed class DailyReportAuditEntry
{
    private DailyReportAuditEntry()
    {
    }

    public DailyReportAuditEntry(
        Guid dailyReportId,
        DailyReportAction action,
        Guid actorId,
        long version,
        DateTimeOffset occurredAt)
    {
        Id = Guid.CreateVersion7();
        DailyReportId = dailyReportId;
        Action = action;
        ActorId = actorId;
        Version = version;
        OccurredAt = occurredAt;
    }

    public Guid Id { get; private set; }

    public Guid DailyReportId { get; private set; }

    public DailyReportAction Action { get; private set; }

    public Guid ActorId { get; private set; }

    public long Version { get; private set; }

    public DateTimeOffset OccurredAt { get; private set; }
}

internal static class ShortText
{
    public static string Require(string value, int maximumLength, string parameterName)
    {
        return Normalize(value, maximumLength, parameterName)
            ?? throw new ArgumentException("Il valore è obbligatorio.", parameterName);
    }

    public static string? Normalize(string? value, int maximumLength, string parameterName)
    {
        var trimmed = string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        return trimmed?.Length > maximumLength
            ? throw new ArgumentException(
                "Il valore supera la lunghezza consentita.",
                parameterName)
            : trimmed;
    }
}
