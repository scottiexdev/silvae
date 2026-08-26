using Microsoft.EntityFrameworkCore;
using Silvae.Application.Abstractions;
using Silvae.Domain.DailyReports;
using Silvae.Domain.JobOrders;
using Silvae.Domain.Organizations;
using Silvae.Domain.Worksites;

namespace Silvae.Infrastructure.Persistence;

public sealed class EfSilvaeStore(SilvaeDbContext dbContext) : ISilvaeStore
{
    public async Task<IReadOnlyList<UserMembership>> GetMembershipsAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        return await dbContext.UserMemberships
            .Where(item => item.UserId == userId)
            .OrderBy(item => item.OrganizationId)
            .ToListAsync(cancellationToken);
    }

    public Task<UserMembership?> GetMembershipAsync(
        Guid organizationId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        return dbContext.UserMemberships.SingleOrDefaultAsync(
            item => item.OrganizationId == organizationId &&
                item.UserId == userId,
            cancellationToken);
    }

    public async Task<IReadOnlyList<JobOrder>> GetJobOrdersAsync(
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        return await dbContext.JobOrders
            .AsNoTracking()
            .Where(item => item.OrganizationId == organizationId)
            .OrderBy(item => item.Code)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Worksite>> GetAssignedWorksitesAsync(
        Guid organizationId,
        Guid userId,
        bool includeAll,
        CancellationToken cancellationToken)
    {
        var query = dbContext.Worksites
            .AsNoTracking()
            .Where(item => item.OrganizationId == organizationId && item.IsActive);

        if (!includeAll)
        {
            query = query.Where(item =>
                item.Assignments.Any(assignment => assignment.UserId == userId));
        }

        return await query
            .OrderBy(item => item.Code)
            .ToListAsync(cancellationToken);
    }

    public Task<bool> CanAccessWorksiteAsync(
        Guid organizationId,
        Guid worksiteId,
        Guid userId,
        bool includeAll,
        CancellationToken cancellationToken)
    {
        return dbContext.Worksites.AnyAsync(
            item => item.Id == worksiteId &&
                item.OrganizationId == organizationId &&
                item.IsActive &&
                (includeAll ||
                    item.Assignments.Any(assignment =>
                        assignment.UserId == userId)),
            cancellationToken);
    }

    public Task<DailyReport?> GetDailyReportAsync(
        Guid organizationId,
        Guid reportId,
        CancellationToken cancellationToken)
    {
        return dbContext.DailyReports.SingleOrDefaultAsync(
            item => item.OrganizationId == organizationId &&
                item.Id == reportId,
            cancellationToken);
    }

    public async Task<IReadOnlyList<DailyReport>> GetDailyReportsChangedSinceAsync(
        Guid organizationId,
        Guid userId,
        bool includeAll,
        DateTimeOffset? changedSince,
        CancellationToken cancellationToken)
    {
        var query = dbContext.DailyReports
            .AsNoTracking()
            .Where(item => item.OrganizationId == organizationId);

        if (changedSince is not null)
        {
            query = query.Where(item => item.UpdatedAt > changedSince);
        }

        if (!includeAll)
        {
            query = query.Where(item =>
                item.AuthorId == userId ||
                dbContext.WorksiteAssignments.Any(assignment =>
                    assignment.WorksiteId == item.WorksiteId &&
                    assignment.UserId == userId));
        }

        return await query
            .OrderBy(item => item.UpdatedAt)
            .ThenBy(item => item.Id)
            .ToListAsync(cancellationToken);
    }

    public async Task<ProcessedSyncOperation?> GetProcessedOperationAsync(
        Guid organizationId,
        Guid operationId,
        CancellationToken cancellationToken)
    {
        var item = await dbContext.ProcessedSyncOperations
            .AsNoTracking()
            .SingleOrDefaultAsync(
            item => item.OrganizationId == organizationId &&
                item.OperationId == operationId,
            cancellationToken);

        return item is null
            ? null
            : new ProcessedSyncOperation(
                item.OrganizationId,
                item.OperationId,
                item.EntityId,
                item.EntityVersion,
                item.ProcessedAt);
    }

    public void AddDailyReport(DailyReport dailyReport)
    {
        dbContext.DailyReports.Add(dailyReport);
    }

    public void AddProcessedOperation(ProcessedSyncOperation operation)
    {
        dbContext.ProcessedSyncOperations.Add(new ProcessedSyncOperationEntity
        {
            OrganizationId = operation.OrganizationId,
            OperationId = operation.OperationId,
            EntityId = operation.EntityId,
            EntityVersion = operation.EntityVersion,
            ProcessedAt = operation.ProcessedAt,
        });
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        return dbContext.SaveChangesAsync(cancellationToken);
    }
}
