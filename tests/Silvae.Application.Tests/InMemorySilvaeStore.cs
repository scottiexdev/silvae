using Silvae.Application.Abstractions;
using Silvae.Domain.DailyReports;
using Silvae.Domain.Documents;
using Silvae.Domain.JobOrders;
using Silvae.Domain.Organizations;
using Silvae.Domain.People;
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

    public List<Certification> Certifications { get; } = [];

    public List<StoredDocument> Documents { get; } = [];

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

    public Task<IReadOnlyList<DailyReport>> SearchDailyReportsAsync(
        Guid organizationId,
        Guid userId,
        bool includeAll,
        DailyReportFilter filter,
        CancellationToken cancellationToken)
    {
        return Task.FromResult<IReadOnlyList<DailyReport>>(
            Reports.Where(item =>
                item.OrganizationId == organizationId &&
                (includeAll || item.AuthorId == userId) &&
                (filter.WorksiteId is null || item.WorksiteId == filter.WorksiteId) &&
                (filter.JobOrderId is null || Worksites.Any(worksite =>
                    worksite.Id == item.WorksiteId &&
                    worksite.JobOrderId == filter.JobOrderId)) &&
                (filter.CrewUserId is null || item.Crew.Any(member =>
                    member.UserId == filter.CrewUserId)) &&
                (filter.From is null || item.ReportDate >= filter.From) &&
                (filter.To is null || item.ReportDate <= filter.To) &&
                (filter.Status is null || item.Status == filter.Status))
                .ToArray());
    }

    public Task<IReadOnlyList<Certification>> GetCertificationsAsync(
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        return Task.FromResult<IReadOnlyList<Certification>>(
            Certifications
                .Where(item => item.OrganizationId == organizationId)
                .ToArray());
    }

    public Task<Certification?> GetCertificationAsync(
        Guid organizationId,
        Guid certificationId,
        CancellationToken cancellationToken)
    {
        return Task.FromResult(Certifications.SingleOrDefault(item =>
            item.OrganizationId == organizationId && item.Id == certificationId));
    }

    public Task<IReadOnlyList<StoredDocumentSummary>> GetDocumentSummariesAsync(
        Guid organizationId,
        Guid? worksiteId,
        CancellationToken cancellationToken)
    {
        return Task.FromResult<IReadOnlyList<StoredDocumentSummary>>(
            Documents
                .Where(item => item.OrganizationId == organizationId &&
                    (worksiteId is null || item.WorksiteId == worksiteId))
                .Select(item => new StoredDocumentSummary(
                    item.Id,
                    item.WorksiteId,
                    item.Title,
                    item.Category,
                    item.IssuedOn,
                    item.ExpiresOn,
                    item.FileName,
                    item.ContentType,
                    item.SizeBytes,
                    item.UploadedBy,
                    item.UploadedAt))
                .ToArray());
    }

    public Task<StoredDocument?> GetDocumentAsync(
        Guid organizationId,
        Guid documentId,
        CancellationToken cancellationToken)
    {
        return Task.FromResult(Documents.SingleOrDefault(item =>
            item.OrganizationId == organizationId && item.Id == documentId));
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

    public void AddCertification(Certification certification) =>
        Certifications.Add(certification);

    public void RemoveCertification(Certification certification) =>
        Certifications.Remove(certification);

    public void AddDocument(StoredDocument document) => Documents.Add(document);

    public void RemoveDocument(StoredDocument document) => Documents.Remove(document);

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
