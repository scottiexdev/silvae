using Silvae.Domain.DailyReports;
using Silvae.Domain.Documents;
using Silvae.Domain.JobOrders;
using Silvae.Domain.Organizations;
using Silvae.Domain.People;
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

    /// <summary>
    /// I report che l'ufficio cerca. Il filtro arriva già validato: qui si
    /// traduce soltanto in una query.
    /// </summary>
    Task<IReadOnlyList<DailyReport>> SearchDailyReportsAsync(
        Guid organizationId,
        Guid userId,
        bool includeAll,
        DailyReportFilter filter,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<Certification>> GetCertificationsAsync(
        Guid organizationId,
        CancellationToken cancellationToken);

    Task<Certification?> GetCertificationAsync(
        Guid organizationId,
        Guid certificationId,
        CancellationToken cancellationToken);

    /// <summary>
    /// Elenca l'archivio senza leggere i byte: una lista di documenti non deve
    /// tirare su dal database i megabyte che non mostra.
    /// </summary>
    Task<IReadOnlyList<StoredDocumentSummary>> GetDocumentSummariesAsync(
        Guid organizationId,
        Guid? worksiteId,
        CancellationToken cancellationToken);

    Task<StoredDocument?> GetDocumentAsync(
        Guid organizationId,
        Guid documentId,
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

    void AddCertification(Certification certification);

    void RemoveCertification(Certification certification);

    void AddDocument(StoredDocument document);

    void RemoveDocument(StoredDocument document);

    Task SaveChangesAsync(CancellationToken cancellationToken);
}

public sealed record ProcessedSyncOperation(
    Guid OrganizationId,
    Guid OperationId,
    Guid EntityId,
    long EntityVersion,
    DateTimeOffset ProcessedAt);

/// <summary>
/// Come l'ufficio restringe l'elenco dei report. Ogni criterio assente non
/// filtra.
/// </summary>
public sealed record DailyReportFilter(
    Guid? JobOrderId = null,
    Guid? WorksiteId = null,
    Guid? CrewUserId = null,
    DateOnly? From = null,
    DateOnly? To = null,
    DailyReportStatus? Status = null);

public sealed record StoredDocumentSummary(
    Guid Id,
    Guid? WorksiteId,
    string Title,
    string Category,
    DateOnly? IssuedOn,
    DateOnly? ExpiresOn,
    string FileName,
    string ContentType,
    int SizeBytes,
    Guid UploadedBy,
    DateTimeOffset UploadedAt);
