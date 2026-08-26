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

    Task<IReadOnlyList<UserMembership>> GetOrganizationMembersAsync(
        Guid organizationId,
        CancellationToken cancellationToken);

    Task<Organization?> GetOrganizationAsync(
        Guid organizationId,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<JobOrder>> GetJobOrdersAsync(
        Guid organizationId,
        CancellationToken cancellationToken);

    Task<JobOrder?> GetJobOrderAsync(
        Guid organizationId,
        Guid jobOrderId,
        CancellationToken cancellationToken);

    Task<bool> JobOrderCodeExistsAsync(
        Guid organizationId,
        string code,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<Worksite>> GetWorksitesAsync(
        Guid organizationId,
        Guid userId,
        bool includeAll,
        bool includeInactive,
        CancellationToken cancellationToken);

    Task<Worksite?> GetWorksiteAsync(
        Guid organizationId,
        Guid worksiteId,
        CancellationToken cancellationToken);

    Task<bool> WorksiteCodeExistsAsync(
        Guid organizationId,
        string code,
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

    void AddOrganization(Organization organization);

    void AddMembership(UserMembership membership);

    /// <summary>
    /// Toglie la persona dall'organizzazione insieme alle sue assegnazioni ai
    /// cantieri: una membership rimossa che lasciasse dietro di sé le
    /// assegnazioni continuerebbe a decidere chi vede quel cantiere.
    /// </summary>
    Task RemoveMemberAsync(
        Guid organizationId,
        Guid userId,
        CancellationToken cancellationToken);

    void AddJobOrder(JobOrder jobOrder);

    void AddWorksite(Worksite worksite);

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
