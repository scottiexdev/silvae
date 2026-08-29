using FluentAssertions;
using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Application.DailyReports;
using Silvae.Application.Identity;
using Silvae.Domain.DailyReports;
using Silvae.Domain.Organizations;
using Silvae.Domain.Worksites;

namespace Silvae.Application.Tests;

public sealed class DailyReportServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 7, 25, 17, 0, 0, TimeSpan.Zero);

    private static readonly ActivityEntry[] NoActivities = [];

    private static readonly SafetyCheckEntry[] NoSafetyChecks = [];

    private static readonly PhotoEntry[] NoPhotos = [];

    [Fact]
    public async Task TheOfficeApprovesAReportSentFromTheField()
    {
        var fixture = new Fixture(OrganizationRole.Coordinator);
        var report = fixture.AddReport();
        report.Submit(Fixture.WorkerId, "Mario Rossi", Now);

        var approved = await fixture.Service.ApproveAsync(
            report.Id,
            CancellationToken.None);

        approved.Status.Should().Be(nameof(DailyReportStatus.Approved));
        approved.Audit[^1].Action.Should().Be(nameof(DailyReportAction.Approved));
        approved.Audit[^1].ActorId.Should().Be(Fixture.CallerId);
    }

    [Fact]
    public async Task AnOperatorCannotApproveTheirOwnReport()
    {
        var fixture = new Fixture(OrganizationRole.Worker);
        var report = fixture.AddReport(authorId: Fixture.CallerId);
        report.Submit(Fixture.CallerId, "Chi chiama", Now);

        var action = () => fixture.Service.ApproveAsync(
            report.Id,
            CancellationToken.None);

        await action.Should().ThrowAsync<ResourceAccessDeniedException>();
    }

    [Fact]
    public async Task ADraftCannotBeApprovedBeforeItIsSent()
    {
        var fixture = new Fixture(OrganizationRole.Administrator);
        var report = fixture.AddReport();

        var action = () => fixture.Service.ApproveAsync(
            report.Id,
            CancellationToken.None);

        await action.Should().ThrowAsync<InvalidOperationException>();
    }

    [Fact]
    public async Task ReopeningPutsTheReportBackInTheHandsOfTheField()
    {
        var fixture = new Fixture(OrganizationRole.Coordinator);
        var report = fixture.AddReport();
        report.Submit(Fixture.WorkerId, "Mario Rossi", Now);
        await fixture.Service.ApproveAsync(report.Id, CancellationToken.None);

        var reopened = await fixture.Service.ReopenAsync(
            report.Id,
            CancellationToken.None);

        reopened.Status.Should().Be(nameof(DailyReportStatus.Reopened));
        reopened.Audit.Should().HaveCount(4);
    }

    [Fact]
    public async Task TheAuthorSendsTheirOwnReport()
    {
        var fixture = new Fixture(OrganizationRole.Worker);
        var report = fixture.AddReport(authorId: Fixture.CallerId);

        var submitted = await fixture.Service.SubmitAsync(
            report.Id,
            "Luca Bianchi",
            CancellationToken.None);

        submitted.Status.Should().Be(nameof(DailyReportStatus.Submitted));
        submitted.TotalHours.Should().Be(8m);
        submitted.Signature.Should().Be("Luca Bianchi");
        submitted.SignedBy.Should().Be(Fixture.CallerId);
    }

    [Fact]
    public async Task AReportWithoutTheCrewLeaderConfirmationIsNotSent()
    {
        var fixture = new Fixture(OrganizationRole.Worker);
        var report = fixture.AddReport(authorId: Fixture.CallerId);

        var action = () => fixture.Service.SubmitAsync(
            report.Id,
            "   ",
            CancellationToken.None);

        await action.Should().ThrowAsync<ArgumentException>();
        report.Status.Should().Be(DailyReportStatus.Draft);
    }

    [Fact]
    public async Task ReopeningClearsTheConfirmationSoItIsGivenAgain()
    {
        var fixture = new Fixture(OrganizationRole.Coordinator);
        var report = fixture.AddReport();
        report.Submit(Fixture.WorkerId, "Mario Rossi", Now);

        var reopened = await fixture.Service.ReopenAsync(
            report.Id,
            CancellationToken.None);

        reopened.Signature.Should().BeNull();
        reopened.SignedAt.Should().BeNull();
    }

    [Fact]
    public async Task TheOfficeFiltersTheReportsByWorksiteAndDate()
    {
        var fixture = new Fixture(OrganizationRole.Coordinator);
        fixture.AddReport();
        fixture.AddReport(worksiteId: Guid.NewGuid());

        var found = await fixture.Service.SearchAsync(
            new DailyReportFilter(
                WorksiteId: Fixture.WorksiteId,
                From: new DateOnly(2026, 7, 1),
                To: new DateOnly(2026, 7, 31)),
            CancellationToken.None);

        found.Should().ContainSingle()
            .Which.WorksiteCode.Should().Be("W-001");
    }

    [Fact]
    public async Task TheExportHasOneRowPerPersonAndDay()
    {
        var fixture = new Fixture(OrganizationRole.Coordinator);
        fixture.AddReport();

        var rows = await fixture.Service.ExportAsync(
            new DailyReportFilter(),
            CancellationToken.None);

        rows.Should().ContainSingle();
        rows[0].DisplayName.Should().Be("Mario Rossi");
        rows[0].Hours.Should().Be(8m);
        rows[0].WorksiteCode.Should().Be("W-001");
    }

    [Fact]
    public async Task AReportOfAnotherOperatorOnAnotherWorksiteIsNotVisible()
    {
        var fixture = new Fixture(OrganizationRole.Worker);
        var report = fixture.AddReport(worksiteId: Guid.NewGuid());

        var action = () => fixture.Service.GetAsync(
            report.Id,
            CancellationToken.None);

        await action.Should().ThrowAsync<ResourceAccessDeniedException>();
    }

    [Fact]
    public async Task TheDetailNamesThePeopleAndTheWorksite()
    {
        var fixture = new Fixture(OrganizationRole.Coordinator);
        var report = fixture.AddReport();

        var detail = await fixture.Service.GetAsync(
            report.Id,
            CancellationToken.None);

        detail.WorksiteCode.Should().Be("W-001");
        detail.Crew.Should().ContainSingle()
            .Which.DisplayName.Should().Be("Mario Rossi");
        detail.Audit.Should().ContainSingle()
            .Which.Action.Should().Be(nameof(DailyReportAction.Created));
    }

    private sealed class Fixture
    {
        public Fixture(OrganizationRole callerRole)
        {
            Store = new InMemorySilvaeStore();
            Store.Organizations.Add(
                new Organization(OrganizationId, "Cooperativa Verde"));
            Store.Memberships.Add(new UserMembership(
                OrganizationId,
                CallerId,
                callerRole,
                "Chi chiama"));
            Store.Memberships.Add(new UserMembership(
                OrganizationId,
                WorkerId,
                OrganizationRole.Worker,
                "Mario Rossi"));

            var worksite = new Worksite(
                WorksiteId,
                OrganizationId,
                "W-001",
                "Parco nord");
            worksite.Assign(WorkerId);
            worksite.Assign(CallerId);
            Store.Worksites.Add(worksite);

            var requestContext = new TestRequestContext
            {
                UserId = CallerId,
                SelectedOrganizationId = OrganizationId,
            };
            Service = new DailyReportService(
                requestContext,
                Store,
                new CurrentUserService(requestContext, Store),
                new FixedTimeProvider(Now));
        }

        public static Guid OrganizationId { get; } = Guid.NewGuid();

        public static Guid CallerId { get; } = Guid.NewGuid();

        public static Guid WorkerId { get; } = Guid.NewGuid();

        public static Guid WorksiteId { get; } = Guid.NewGuid();

        public InMemorySilvaeStore Store { get; }

        public DailyReportService Service { get; }

        public DailyReport AddReport(Guid? authorId = null, Guid? worksiteId = null)
        {
            var report = DailyReport.Create(
                Guid.NewGuid(),
                OrganizationId,
                authorId ?? WorkerId,
                new DailyReportContent(
                    worksiteId ?? WorksiteId,
                    new DateOnly(2026, 7, 25),
                    "Giornata regolare",
                    [new CrewEntry(WorkerId, 8m, null)],
                    NoActivities,
                    NoSafetyChecks,
                    NoPhotos),
                Now);
            Store.Reports.Add(report);
            return report;
        }
    }

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
