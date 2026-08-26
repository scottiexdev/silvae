using Silvae.Domain.DailyReports;
using Silvae.Domain.JobOrders;
using Silvae.Domain.Organizations;
using Silvae.Domain.Worksites;

namespace Silvae.Application.Abstractions;

public interface ISilvaeStore
{
    Task<IReadOnlyList<UserMembership>> GetMembershipsAsync(
        Guid userId,
        CancellationToken cancellationToken);

    Task<UserMembership?> GetMembershipAsync(
        Guid organizationId,
        Guid userId,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<JobOrder>> GetJobOrdersAsync(
        Guid organizationId,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<Worksite>> GetAssignedWorksitesAsync(
        Guid organizationId,
        Guid userId,
        bool includeAll,
        CancellationToken cancellationToken);

    Task<bool> CanAccessWorksiteAsync(
        Guid organizationId,
        Guid worksiteId,
        Guid userId,
        bool includeAll,
        CancellationToken cancellationToken);

    Task<DailyReport?> GetDailyReportAsync(
        Guid organizationId,
        Guid reportId,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<DailyReport>> GetDailyReportsChangedSinceAsync(
        Guid organizationId,
        Guid userId,
        bool includeAll,
        DateTimeOffset? changedSince,
        CancellationToken cancellationToken);

    Task<ProcessedSyncOperation?> GetProcessedOperationAsync(
        Guid organizationId,
        Guid operationId,
        CancellationToken cancellationToken);

    void AddDailyReport(DailyReport dailyReport);

    void AddProcessedOperation(ProcessedSyncOperation operation);

    Task SaveChangesAsync(CancellationToken cancellationToken);
}

public sealed record ProcessedSyncOperation(
    Guid OrganizationId,
    Guid OperationId,
    Guid EntityId,
    long EntityVersion,
    DateTimeOffset ProcessedAt);
