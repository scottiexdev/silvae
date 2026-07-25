using System.Text.Json;
using FluentAssertions;
using Silvae.Application.Abstractions;
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

    private static SyncOperationDto CreateOperation(
        long expectedVersion,
        Guid? operationId = null)
    {
        var payload = JsonSerializer.SerializeToElement(new DailyReportPayload(
            WorksiteId,
            new DateOnly(2026, 7, 25),
            "Sfalcio"));

        return new SyncOperationDto(
            operationId ?? Guid.NewGuid(),
            OrganizationId,
            Fixture.ReportId,
            "dailyReport",
            "upsert",
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
            Store = new TestStore();
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

        public TestStore Store { get; }

        public SyncService Service { get; }
    }

    private sealed class TestRequestContext : IRequestContext
    {
        public Guid UserId { get; init; }

        public Guid? SelectedOrganizationId { get; init; }
    }

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    private sealed class TestStore : ISilvaeStore
    {
        public List<UserMembership> Memberships { get; } = [];

        public List<Worksite> Worksites { get; } = [];

        public List<DailyReport> Reports { get; } = [];

        public List<ProcessedSyncOperation> ProcessedOperations { get; } = [];

        public Task<IReadOnlyList<UserMembership>> GetMembershipsAsync(
            Guid userId,
            CancellationToken cancellationToken)
        {
            return Task.FromResult<IReadOnlyList<UserMembership>>(
                Memberships.Where(item => item.UserId == userId).ToArray());
        }

        public Task<UserMembership?> GetMembershipAsync(
            Guid organizationId,
            Guid userId,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Memberships.SingleOrDefault(item =>
                item.OrganizationId == organizationId && item.UserId == userId));
        }

        public Task<IReadOnlyList<Worksite>> GetAssignedWorksitesAsync(
            Guid organizationId,
            Guid userId,
            bool includeAll,
            CancellationToken cancellationToken)
        {
            return Task.FromResult<IReadOnlyList<Worksite>>(
                Worksites.Where(item =>
                    item.OrganizationId == organizationId &&
                    (includeAll ||
                        item.Assignments.Any(assignment =>
                            assignment.UserId == userId))).ToArray());
        }

        public Task<bool> CanAccessWorksiteAsync(
            Guid organizationId,
            Guid worksiteId,
            Guid userId,
            bool includeAll,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Worksites.Any(item =>
                item.OrganizationId == organizationId &&
                item.Id == worksiteId &&
                (includeAll ||
                    item.Assignments.Any(assignment =>
                        assignment.UserId == userId))));
        }

        public Task<DailyReport?> GetDailyReportAsync(
            Guid organizationId,
            Guid reportId,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Reports.SingleOrDefault(item =>
                item.OrganizationId == organizationId && item.Id == reportId));
        }

        public Task<IReadOnlyList<DailyReport>> GetDailyReportsChangedSinceAsync(
            Guid organizationId,
            Guid userId,
            bool includeAll,
            DateTimeOffset? changedSince,
            CancellationToken cancellationToken)
        {
            return Task.FromResult<IReadOnlyList<DailyReport>>(
                Reports.Where(item =>
                    item.OrganizationId == organizationId &&
                    (changedSince is null || item.UpdatedAt > changedSince)).ToArray());
        }

        public Task<ProcessedSyncOperation?> GetProcessedOperationAsync(
            Guid organizationId,
            Guid operationId,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(ProcessedOperations.SingleOrDefault(item =>
                item.OrganizationId == organizationId &&
                item.OperationId == operationId));
        }

        public void AddDailyReport(DailyReport dailyReport) =>
            Reports.Add(dailyReport);

        public void AddProcessedOperation(ProcessedSyncOperation operation) =>
            ProcessedOperations.Add(operation);

        public Task SaveChangesAsync(CancellationToken cancellationToken) =>
            Task.CompletedTask;
    }
}
