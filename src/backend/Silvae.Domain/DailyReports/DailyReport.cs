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
    private DailyReport()
    {
    }

    private DailyReport(
        Guid id,
        Guid organizationId,
        Guid worksiteId,
        Guid authorId,
        DateOnly reportDate,
        string? notes,
        DateTimeOffset now)
    {
        if (id == Guid.Empty ||
            organizationId == Guid.Empty ||
            worksiteId == Guid.Empty ||
            authorId == Guid.Empty)
        {
            throw new ArgumentException("Gli identificativi sono obbligatori.");
        }

        if (reportDate > DateOnly.FromDateTime(now.UtcDateTime).AddDays(1))
        {
            throw new ArgumentOutOfRangeException(
                nameof(reportDate),
                "La data del rapportino non può essere nel futuro.");
        }

        Id = id;
        OrganizationId = organizationId;
        WorksiteId = worksiteId;
        AuthorId = authorId;
        ReportDate = reportDate;
        Notes = NormalizeNotes(notes);
        Status = DailyReportStatus.Draft;
        Version = 1;
        CreatedAt = now;
        UpdatedAt = now;
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

    public static DailyReport Create(
        Guid id,
        Guid organizationId,
        Guid worksiteId,
        Guid authorId,
        DateOnly reportDate,
        string? notes,
        DateTimeOffset now)
    {
        return new DailyReport(
            id,
            organizationId,
            worksiteId,
            authorId,
            reportDate,
            notes,
            now);
    }

    public void UpdateDraft(
        Guid worksiteId,
        DateOnly reportDate,
        string? notes,
        DateTimeOffset now)
    {
        if (Status is not (DailyReportStatus.Draft or DailyReportStatus.Reopened))
        {
            throw new InvalidOperationException(
                "Solo un rapportino in bozza o riaperto può essere modificato.");
        }

        if (worksiteId == Guid.Empty)
        {
            throw new ArgumentException("Il cantiere è obbligatorio.", nameof(worksiteId));
        }

        if (reportDate > DateOnly.FromDateTime(now.UtcDateTime).AddDays(1))
        {
            throw new ArgumentOutOfRangeException(
                nameof(reportDate),
                "La data del rapportino non può essere nel futuro.");
        }

        WorksiteId = worksiteId;
        ReportDate = reportDate;
        Notes = NormalizeNotes(notes);
        Version++;
        UpdatedAt = now;
    }

    public void Submit(DateTimeOffset now)
    {
        if (Status is not (DailyReportStatus.Draft or DailyReportStatus.Reopened))
        {
            throw new InvalidOperationException("Il rapportino non può essere inviato.");
        }

        Status = DailyReportStatus.Submitted;
        Version++;
        UpdatedAt = now;
    }

    public void Approve(DateTimeOffset now)
    {
        if (Status != DailyReportStatus.Submitted)
        {
            throw new InvalidOperationException(
                "Solo un rapportino inviato può essere approvato.");
        }

        Status = DailyReportStatus.Approved;
        Version++;
        UpdatedAt = now;
    }

    public void Reopen(DateTimeOffset now)
    {
        if (Status is not (DailyReportStatus.Submitted or DailyReportStatus.Approved))
        {
            throw new InvalidOperationException(
                "Solo un rapportino inviato o approvato può essere riaperto.");
        }

        Status = DailyReportStatus.Reopened;
        Version++;
        UpdatedAt = now;
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
}
