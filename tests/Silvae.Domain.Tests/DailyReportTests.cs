using FluentAssertions;
using Silvae.Domain.DailyReports;

namespace Silvae.Domain.Tests;

public sealed class DailyReportTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 7, 25, 8, 0, 0, TimeSpan.Zero);

    [Fact]
    public void UpdateDraftIncrementsVersionAndNormalizesNotes()
    {
        var report = CreateReport();
        var nextWorksiteId = Guid.NewGuid();

        report.UpdateDraft(
            nextWorksiteId,
            new DateOnly(2026, 7, 25),
            "  Potatura completata  ",
            Now.AddMinutes(10));

        report.Version.Should().Be(2);
        report.WorksiteId.Should().Be(nextWorksiteId);
        report.Notes.Should().Be("Potatura completata");
        report.UpdatedAt.Should().Be(Now.AddMinutes(10));
    }

    [Fact]
    public void ApprovedReportCannotBeEdited()
    {
        var report = CreateReport();
        report.Submit(Now.AddMinutes(10));
        report.Approve(Now.AddMinutes(20));

        var action = () => report.UpdateDraft(
            Guid.NewGuid(),
            new DateOnly(2026, 7, 25),
            null,
            Now.AddMinutes(30));

        action.Should().Throw<InvalidOperationException>();
    }

    private static DailyReport CreateReport()
    {
        return DailyReport.Create(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            new DateOnly(2026, 7, 25),
            null,
            Now);
    }
}
