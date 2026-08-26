using Silvae.Application.Abstractions;
using Silvae.Domain.DailyReports;
using Silvae.Domain.JobOrders;
using Silvae.Domain.Organizations;
using Silvae.Domain.Worksites;

namespace Silvae.Application.Tests;

/// <summary>
/// Store in memoria condiviso dai test applicativi. Tiene le stesse istanze che
/// restituisce, così una modifica fatta da un servizio resta visibile al test
/// senza passare da un salvataggio.
/// </summary>
internal sealed class InMemorySilvaeStore : ISilvaeStore
{
    public List<Organization> Organizations { get; } = [];

    public List<UserMembership> Memberships { get; } = [];

    public List<JobOrder> JobOrders { get; } = [];

    public List<Worksite> Worksites { get; } = [];

    public List<DailyReport> Reports { get; } = [];

    public List<ProcessedSyncOperation> ProcessedOperations { get; } = [];

    public int SaveCount { get; private set; }

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

    public Task<IReadOnlyList<UserMembership>> GetOrganizationMembersAsync(
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        return Task.FromResult<IReadOnlyList<UserMembership>>(
            Memberships
                .Where(item => item.OrganizationId == organizationId)
                .ToArray());
    }

    public Task<Organization?> GetOrganizationAsync(
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        return Task.FromResult(
            Organizations.SingleOrDefault(item => item.Id == organizationId));
    }

    public Task<IReadOnlyList<JobOrder>> GetJobOrdersAsync(
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        return Task.FromResult<IReadOnlyList<JobOrder>>(
            JobOrders.Where(item => item.OrganizationId == organizationId)
                .ToArray());
    }

    public Task<JobOrder?> GetJobOrderAsync(
        Guid organizationId,
        Guid jobOrderId,
        CancellationToken cancellationToken)
    {
        return Task.FromResult(JobOrders.SingleOrDefault(item =>
            item.OrganizationId == organizationId && item.Id == jobOrderId));
    }

    public Task<bool> JobOrderCodeExistsAsync(
        Guid organizationId,
        string code,
        CancellationToken cancellationToken)
    {
        return Task.FromResult(JobOrders.Any(item =>
            item.OrganizationId == organizationId && item.Code == code));
    }

    public Task<IReadOnlyList<Worksite>> GetWorksitesAsync(
        Guid organizationId,
        Guid userId,
        bool includeAll,
        bool includeInactive,
        CancellationToken cancellationToken)
    {
        return Task.FromResult<IReadOnlyList<Worksite>>(
            Worksites.Where(item =>
                item.OrganizationId == organizationId &&
                (includeInactive || item.IsActive) &&
                (includeAll ||
                    item.Assignments.Any(assignment =>
                        assignment.UserId == userId))).ToArray());
    }

    public Task<Worksite?> GetWorksiteAsync(
        Guid organizationId,
        Guid worksiteId,
        CancellationToken cancellationToken)
    {
        return Task.FromResult(Worksites.SingleOrDefault(item =>
            item.OrganizationId == organizationId && item.Id == worksiteId));
    }

    public Task<bool> WorksiteCodeExistsAsync(
        Guid organizationId,
        string code,
        CancellationToken cancellationToken)
    {
        return Task.FromResult(Worksites.Any(item =>
            item.OrganizationId == organizationId && item.Code == code));
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

    public void AddOrganization(Organization organization) =>
        Organizations.Add(organization);

    public void AddMembership(UserMembership membership) =>
        Memberships.Add(membership);

    public Task RemoveMemberAsync(
        Guid organizationId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        foreach (var worksite in Worksites.Where(item =>
            item.OrganizationId == organizationId))
        {
            worksite.Unassign(userId);
        }

        Memberships.RemoveAll(item =>
            item.OrganizationId == organizationId && item.UserId == userId);

        return Task.CompletedTask;
    }

    public void AddJobOrder(JobOrder jobOrder) => JobOrders.Add(jobOrder);

    public void AddWorksite(Worksite worksite) => Worksites.Add(worksite);

    public void AddDailyReport(DailyReport dailyReport) => Reports.Add(dailyReport);

    public void AddProcessedOperation(ProcessedSyncOperation operation) =>
        ProcessedOperations.Add(operation);

    public Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        SaveCount++;
        return Task.CompletedTask;
    }
}

internal sealed class TestRequestContext : IRequestContext
{
    public Guid UserId { get; init; }

    public Guid? SelectedOrganizationId { get; init; }
}
