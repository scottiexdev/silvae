using FluentAssertions;
using Silvae.Domain.DailyReports;

namespace Silvae.Domain.Tests;

public sealed class DailyReportTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 7, 25, 8, 0, 0, TimeSpan.Zero);

    private static readonly DateOnly ReportDate = new(2026, 7, 25);

    private static readonly CrewEntry[] NoCrew = [];

    private static readonly ActivityEntry[] NoActivities = [];

    private static readonly SafetyCheckEntry[] NoSafetyChecks = [];

    [Fact]
    public void UpdateContentIncrementsVersionAndNormalizesNotes()
    {
        var report = CreateReport();
        var nextWorksiteId = Guid.NewGuid();

        report.UpdateContent(
            new DailyReportContent(
                nextWorksiteId,
                ReportDate,
                "  Potatura completata  ",
                NoCrew,
                NoActivities,
                NoSafetyChecks),
            report.AuthorId,
            Now.AddMinutes(10));

        report.Version.Should().Be(2);
        report.WorksiteId.Should().Be(nextWorksiteId);
        report.Notes.Should().Be("Potatura completata");
        report.UpdatedAt.Should().Be(Now.AddMinutes(10));
    }

    [Fact]
    public void ApprovedReportCannotBeEdited()
    {
        var report = CreateReport(CrewOf(4m));
        report.Submit(report.AuthorId, Now.AddMinutes(10));
        report.Approve(Guid.NewGuid(), Now.AddMinutes(20));

        var action = () => report.UpdateContent(
            new DailyReportContent(
                Guid.NewGuid(),
                ReportDate,
                null,
                NoCrew,
                NoActivities,
                NoSafetyChecks),
            report.AuthorId,
            Now.AddMinutes(30));

        action.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void AReportWithoutACrewCannotBeSubmitted()
    {
        var report = CreateReport();

        var action = () => report.Submit(report.AuthorId, Now.AddMinutes(10));

        action.Should().Throw<InvalidOperationException>();
        report.Status.Should().Be(DailyReportStatus.Draft);
    }

    [Fact]
    public void TheSamePersonCannotAppearTwiceInTheCrew()
    {
        var userId = Guid.NewGuid();

        var action = () => CreateReport(
            new CrewEntry(userId, 4m, null),
            new CrewEntry(userId, 2m, null));

        action.Should().Throw<ArgumentException>();
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(25)]
    public void HoursOutsideTheDayAreRejected(int hours)
    {
        var action = () => CreateReport(
            new CrewEntry(Guid.NewGuid(), hours, null));

        action.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void ANonCompliantSafetyCheckRequiresANote()
    {
        var action = () => new DailyReportSafetyCheck(
            Guid.NewGuid(),
            "DPI-CASCO",
            isCompliant: false,
            note: null);

        action.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void SafetyCheckCodesAreComparedInOneCase()
    {
        var report = CreateReport();

        var action = () => report.UpdateContent(
            new DailyReportContent(
                report.WorksiteId,
                ReportDate,
                null,
                NoCrew,
                NoActivities,
                [
                    new SafetyCheckEntry("dpi-casco", true, null),
                    new SafetyCheckEntry("DPI-CASCO", true, null),
                ]),
            report.AuthorId,
            Now.AddMinutes(5));

        action.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void TotalHoursSumsTheCrew()
    {
        var report = CreateReport(
            new CrewEntry(Guid.NewGuid(), 7.5m, null),
            new CrewEntry(Guid.NewGuid(), 4m, "mezza giornata"));

        report.TotalHours().Should().Be(11.5m);
    }

    [Fact]
    public void TheAuditKeepsTheWholePathIncludingTheReopening()
    {
        var report = CreateReport(CrewOf(8m));
        var coordinator = Guid.NewGuid();

        report.Submit(report.AuthorId, Now.AddMinutes(10));
        report.Approve(coordinator, Now.AddMinutes(20));
        report.Reopen(coordinator, Now.AddMinutes(30));

        report.Audit.Select(entry => entry.Action).Should().Equal(
            DailyReportAction.Created,
            DailyReportAction.Submitted,
            DailyReportAction.Approved,
            DailyReportAction.Reopened);
        report.Audit[^1].ActorId.Should().Be(coordinator);
        report.Status.Should().Be(DailyReportStatus.Reopened);
    }

    [Fact]
    public void AReopenedReportCanBeEditedAgain()
    {
        var report = CreateReport(CrewOf(8m));
        report.Submit(report.AuthorId, Now.AddMinutes(10));
        report.Reopen(Guid.NewGuid(), Now.AddMinutes(20));

        report.UpdateContent(
            new DailyReportContent(
                report.WorksiteId,
                ReportDate,
                "Corretto",
                [new CrewEntry(Guid.NewGuid(), 6m, null)],
                NoActivities,
                NoSafetyChecks),
            report.AuthorId,
            Now.AddMinutes(30));

        report.Notes.Should().Be("Corretto");
        report.Crew.Should().ContainSingle();
    }

    [Fact]
    public void AReportInTheFutureIsRejected()
    {
        var action = () => DailyReport.Create(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            new DailyReportContent(
                Guid.NewGuid(),
                ReportDate.AddDays(5),
                null,
                NoCrew,
                NoActivities,
                NoSafetyChecks),
            Now);

        action.Should().Throw<ArgumentOutOfRangeException>();
    }

    private static CrewEntry CrewOf(decimal hours)
    {
        return new CrewEntry(Guid.NewGuid(), hours, null);
    }

    private static DailyReport CreateReport(params CrewEntry[] crew)
    {
        return DailyReport.Create(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            new DailyReportContent(
                Guid.NewGuid(),
                ReportDate,
                null,
                crew,
                NoActivities,
                NoSafetyChecks),
            Now);
    }
}
