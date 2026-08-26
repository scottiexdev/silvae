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

    /// <summary>
    /// Restituisce membership tracciate: da qui passa anche il cambio di ruolo,
    /// che modifica l'entità restituita.
    /// </summary>
    public async Task<IReadOnlyList<UserMembership>> GetOrganizationMembersAsync(
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        return await dbContext.UserMemberships
            .Where(item => item.OrganizationId == organizationId)
            .OrderBy(item => item.DisplayName)
            .ToListAsync(cancellationToken);
    }

    public Task<Organization?> GetOrganizationAsync(
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        return dbContext.Organizations.SingleOrDefaultAsync(
            item => item.Id == organizationId,
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

    public Task<JobOrder?> GetJobOrderAsync(
        Guid organizationId,
        Guid jobOrderId,
        CancellationToken cancellationToken)
    {
        return dbContext.JobOrders.SingleOrDefaultAsync(
            item => item.OrganizationId == organizationId && item.Id == jobOrderId,
            cancellationToken);
    }

    public Task<bool> JobOrderCodeExistsAsync(
        Guid organizationId,
        string code,
        CancellationToken cancellationToken)
    {
        return dbContext.JobOrders.AnyAsync(
            item => item.OrganizationId == organizationId && item.Code == code,
            cancellationToken);
    }

    public async Task<IReadOnlyList<Worksite>> GetWorksitesAsync(
        Guid organizationId,
        Guid userId,
        bool includeAll,
        bool includeInactive,
        CancellationToken cancellationToken)
    {
        var query = dbContext.Worksites
            .AsNoTracking()
            .Where(item => item.OrganizationId == organizationId);

        if (!includeInactive)
        {
            query = query.Where(item => item.IsActive);
        }

        if (!includeAll)
        {
            query = query.Where(item =>
                item.Assignments.Any(assignment => assignment.UserId == userId));
        }

        return await query
            .OrderBy(item => item.Code)
            .ToListAsync(cancellationToken);
    }

    /// <summary>
    /// Restituisce il cantiere tracciato con le sue assegnazioni: è l'aggregato
    /// su cui l'anagrafica scrive.
    /// </summary>
    public Task<Worksite?> GetWorksiteAsync(
        Guid organizationId,
        Guid worksiteId,
        CancellationToken cancellationToken)
    {
        return dbContext.Worksites
            .Include(item => item.Assignments)
            .SingleOrDefaultAsync(
                item => item.OrganizationId == organizationId &&
                    item.Id == worksiteId,
                cancellationToken);
    }

    public Task<bool> WorksiteCodeExistsAsync(
        Guid organizationId,
        string code,
        CancellationToken cancellationToken)
    {
        return dbContext.Worksites.AnyAsync(
            item => item.OrganizationId == organizationId && item.Code == code,
            cancellationToken);
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

    /// <summary>
    /// Il rapportino arriva con il suo contenuto: squadra, attività, sicurezza
    /// e audit fanno parte dell'aggregato e l'upsert li sostituisce insieme.
    /// </summary>
    public Task<DailyReport?> GetDailyReportAsync(
        Guid organizationId,
        Guid reportId,
        CancellationToken cancellationToken)
    {
        return dbContext.DailyReports
            .Include(item => item.Crew)
            .Include(item => item.Activities)
            .Include(item => item.SafetyChecks)
            .Include(item => item.Audit)
            .SingleOrDefaultAsync(
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
            .Include(item => item.Crew)
            .Include(item => item.Activities)
            .Include(item => item.SafetyChecks)
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

    public void AddOrganization(Organization organization)
    {
        dbContext.Organizations.Add(organization);
    }

    public void AddMembership(UserMembership membership)
    {
        dbContext.UserMemberships.Add(membership);
    }

    public async Task RemoveMemberAsync(
        Guid organizationId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var assignments = await dbContext.WorksiteAssignments
            .Where(assignment => assignment.UserId == userId &&
                dbContext.Worksites.Any(worksite =>
                    worksite.Id == assignment.WorksiteId &&
                    worksite.OrganizationId == organizationId))
            .ToListAsync(cancellationToken);
        dbContext.WorksiteAssignments.RemoveRange(assignments);

        var membership = await GetMembershipAsync(
            organizationId,
            userId,
            cancellationToken);
        if (membership is not null)
        {
            dbContext.UserMemberships.Remove(membership);
        }
    }

    public void AddJobOrder(JobOrder jobOrder)
    {
        dbContext.JobOrders.Add(jobOrder);
    }

    public void AddWorksite(Worksite worksite)
    {
        dbContext.Worksites.Add(worksite);
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
