using System.Text.Json;
using FluentAssertions;
using Silvae.Application.Common;
using Silvae.Application.Identity;
using Silvae.Application.Sync;
using Silvae.Domain.DailyReports;
using Silvae.Domain.Organizations;
using Silvae.Domain.Worksites;

namespace Silvae.Application.Tests;

public sealed class SyncServiceTests
{
    private static readonly Guid OrganizationId = Guid.NewGuid();
    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid WorksiteId = Guid.NewGuid();
    private static readonly DateTimeOffset Now =
        new(2026, 7, 25, 10, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task RetryingAnOperationReturnsTheOriginalResultOnlyOnce()
    {
        var fixture = new Fixture();
        var operation = CreateOperation(expectedVersion: 0);

        var first = await fixture.Service.PushAsync(
            new PushSyncRequest([operation]),
            CancellationToken.None);
        var retry = await fixture.Service.PushAsync(
            new PushSyncRequest([operation]),
            CancellationToken.None);

        first.Operations.Single().WasDuplicate.Should().BeFalse();
        retry.Operations.Single().WasDuplicate.Should().BeTrue();
        retry.Operations.Single().Version.Should().Be(1);
        fixture.Store.Reports.Should().ContainSingle();
        fixture.Store.ProcessedOperations.Should().ContainSingle();
    }

    [Fact]
    public async Task UpdatingWithAStaleVersionReturnsAConflict()
    {
        var fixture = new Fixture();
        await fixture.Service.PushAsync(
            new PushSyncRequest([CreateOperation(expectedVersion: 0)]),
            CancellationToken.None);

        var staleOperation = CreateOperation(
            expectedVersion: 0,
            operationId: Guid.NewGuid());
        var action = () => fixture.Service.PushAsync(
            new PushSyncRequest([staleOperation]),
            CancellationToken.None);

        var exception = await action.Should()
            .ThrowAsync<SyncConflictException>();
        exception.Which.CurrentVersion.Should().Be(1);
    }

    [Fact]
    public async Task TheCrewArrivesWithTheReportAndComesBackWithThePull()
    {
        var fixture = new Fixture();

        await fixture.Service.PushAsync(
            new PushSyncRequest([
                CreateOperation(
                    expectedVersion: 0,
                    crew: [new CrewMemberPayload(UserId, 7.5m, "mezza in salita")],
                    activities: [new ActivityPayload("Sfalcio", 1200m, "mq")],
                    safetyChecks: [new SafetyCheckPayload("DPI-CASCO", true, null)]),
            ]),
            CancellationToken.None);

        var pull = await fixture.Service.PullAsync(null, CancellationToken.None);

        var report = pull.DailyReports.Should().ContainSingle().Subject;
        report.Crew.Should().ContainSingle().Which.Hours.Should().Be(7.5m);
        report.Activities.Should().ContainSingle().Which.Unit.Should().Be("mq");
        report.SafetyChecks.Should().ContainSingle().Which.Code.Should().Be("DPI-CASCO");
    }

    [Fact]
    public async Task AnAbsentCrewLeavesTheOneAlreadyRegistered()
    {
        var fixture = new Fixture();
        await fixture.Service.PushAsync(
            new PushSyncRequest([
                CreateOperation(
                    expectedVersion: 0,
                    crew: [new CrewMemberPayload(UserId, 8m, null)]),
            ]),
            CancellationToken.None);

        await fixture.Service.PushAsync(
            new PushSyncRequest([
                CreateOperation(expectedVersion: 1, operationId: Guid.NewGuid()),
            ]),
            CancellationToken.None);

        fixture.Store.Reports.Single().Crew.Should().ContainSingle();
    }

    [Fact]
    public async Task AnEmptyCrewClearsTheOneAlreadyRegistered()
    {
        var fixture = new Fixture();
        await fixture.Service.PushAsync(
            new PushSyncRequest([
                CreateOperation(
                    expectedVersion: 0,
                    crew: [new CrewMemberPayload(UserId, 8m, null)]),
            ]),
            CancellationToken.None);

        await fixture.Service.PushAsync(
            new PushSyncRequest([
                CreateOperation(
                    expectedVersion: 1,
                    operationId: Guid.NewGuid(),
                    crew: []),
            ]),
            CancellationToken.None);

        fixture.Store.Reports.Single().Crew.Should().BeEmpty();
    }

    [Fact]
    public async Task SomeoneOutsideTheOrganizationCannotBeInTheCrew()
    {
        var fixture = new Fixture();

        var action = () => fixture.Service.PushAsync(
            new PushSyncRequest([
                CreateOperation(
                    expectedVersion: 0,
                    crew: [new CrewMemberPayload(Guid.NewGuid(), 8m, null)]),
            ]),
            CancellationToken.None);

        await action.Should().ThrowAsync<SyncValidationException>();
    }

    [Fact]
    public async Task TheReportIsSubmittedThroughTheQueue()
    {
        var fixture = new Fixture();
        await fixture.Service.PushAsync(
            new PushSyncRequest([
                CreateOperation(
                    expectedVersion: 0,
                    crew: [new CrewMemberPayload(UserId, 8m, null)]),
            ]),
            CancellationToken.None);

        var result = await fixture.Service.PushAsync(
            new PushSyncRequest([
                CreateOperation(
                    expectedVersion: 1,
                    operationId: Guid.NewGuid(),
                    operationType: "submit"),
            ]),
            CancellationToken.None);

        result.Operations.Single().Version.Should().Be(2);
        fixture.Store.Reports.Single().Status.Should()
            .Be(DailyReportStatus.Submitted);
    }

    [Fact]
    public async Task AnUnknownOperationIsRejected()
    {
        var fixture = new Fixture();

        var action = () => fixture.Service.PushAsync(
            new PushSyncRequest([
                CreateOperation(expectedVersion: 0, operationType: "delete"),
            ]),
            CancellationToken.None);

        await action.Should().ThrowAsync<SyncValidationException>();
    }

    private static SyncOperationDto CreateOperation(
        long expectedVersion,
        Guid? operationId = null,
        string operationType = "upsert",
        IReadOnlyList<CrewMemberPayload>? crew = null,
        IReadOnlyList<ActivityPayload>? activities = null,
        IReadOnlyList<SafetyCheckPayload>? safetyChecks = null,
        IReadOnlyList<PhotoPayload>? photos = null)
    {
        // L'invio porta la conferma del caposquadra, non il contenuto: è
        // l'unico caso in cui il payload dell'operazione cambia forma.
        var payload = operationType == "submit"
            ? JsonSerializer.SerializeToElement(new SubmitPayload("Mario Rossi"))
            : JsonSerializer.SerializeToElement(new DailyReportPayload(
                WorksiteId,
                new DateOnly(2026, 7, 25),
                "Sfalcio",
                crew,
                activities,
                safetyChecks,
                photos));

        return new SyncOperationDto(
            operationId ?? Guid.NewGuid(),
            OrganizationId,
            Fixture.ReportId,
            "dailyReport",
            operationType,
            expectedVersion,
            payload,
            Now);
    }

    private sealed class Fixture
    {
        public static readonly Guid ReportId = Guid.NewGuid();

        private readonly TestRequestContext _requestContext = new()
        {
            UserId = UserId,
            SelectedOrganizationId = OrganizationId,
        };

        public Fixture()
        {
            Store = new InMemorySilvaeStore();
            Store.Memberships.Add(new UserMembership(
                OrganizationId,
                UserId,
                OrganizationRole.Worker,
                "Mario Rossi"));
            var worksite = new Worksite(
                WorksiteId,
                OrganizationId,
                "C-001",
                "Parco nord");
            worksite.Assign(UserId);
            Store.Worksites.Add(worksite);
            var currentUser = new CurrentUserService(_requestContext, Store);
            Service = new SyncService(
                _requestContext,
                Store,
                currentUser,
                new FixedTimeProvider(Now));
        }

        public InMemorySilvaeStore Store { get; }

        public SyncService Service { get; }
    }

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
