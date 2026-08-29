using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Application.Identity;
using Silvae.Domain.Organizations;
using Silvae.Domain.People;

namespace Silvae.Application.People;

/// <summary>
/// Competenze e abilitazioni delle persone. È materia d'ufficio: chi le
/// registra è chi risponde davanti a un ente finanziatore o a un RSPP.
/// </summary>
public sealed class CertificationService(
    ISilvaeStore store,
    CurrentUserService currentUser,
    TimeProvider timeProvider)
{
    public async Task<IReadOnlyList<CertificationDto>> GetAllAsync(
        Guid? userId,
        DateOnly? validOn,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var members = await GetMembersByIdAsync(
            membership.OrganizationId,
            cancellationToken);
        var certifications = await store.GetCertificationsAsync(
            membership.OrganizationId,
            cancellationToken);

        return certifications
            .Where(item => userId is null || item.UserId == userId)
            .Where(item => validOn is null || item.IsValidOn(validOn.Value))
            .Select(item => ToDto(item, members, Today()))
            .OrderBy(item => item.DisplayName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(item => item.Kind, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    /// <summary>
    /// Le abilitazioni che scadono entro la finestra indicata, più quelle già
    /// scadute: chi prepara il cantiere della settimana prossima deve vedere
    /// entrambe nello stesso elenco.
    /// </summary>
    public async Task<IReadOnlyList<CertificationDto>> GetExpiringAsync(
        int withinDays,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        if (withinDays is < 0 or > 3650)
        {
            throw new RegistryValidationException(
                "La finestra deve stare fra 0 e 3650 giorni.");
        }

        var today = Today();
        var limit = today.AddDays(withinDays);
        var members = await GetMembersByIdAsync(
            membership.OrganizationId,
            cancellationToken);
        var certifications = await store.GetCertificationsAsync(
            membership.OrganizationId,
            cancellationToken);

        return certifications
            .Where(item => item.ExpiresOn is { } expiresOn && expiresOn <= limit)
            .Select(item => ToDto(item, members, today))
            .OrderBy(item => item.ExpiresOn)
            .ToArray();
    }

    /// <summary>
    /// L'estrazione per l'ispezione: per ogni giornata dichiarata, chi era in
    /// cantiere e con quali abilitazioni valide <em>a quella data</em>. È la
    /// domanda che fa un RSPP, e a cui la sola scadenza corrente non risponde.
    /// </summary>
    public async Task<IReadOnlyList<InspectionDayDto>> GetInspectionAsync(
        Guid? worksiteId,
        DateOnly from,
        DateOnly to,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        if (to < from)
        {
            throw new RegistryValidationException(
                "La data finale non può precedere quella iniziale.");
        }

        var members = await GetMembersByIdAsync(
            membership.OrganizationId,
            cancellationToken);
        var certifications = await store.GetCertificationsAsync(
            membership.OrganizationId,
            cancellationToken);
        var reports = await store.SearchDailyReportsAsync(
            membership.OrganizationId,
            membership.UserId,
            includeAll: true,
            new DailyReportFilter(WorksiteId: worksiteId, From: from, To: to),
            cancellationToken);
        var worksites = (await store.GetWorksitesAsync(
                membership.OrganizationId,
                membership.UserId,
                includeAll: true,
                includeInactive: true,
                cancellationToken))
            .ToDictionary(item => item.Id);

        return reports
            .Select(report => new InspectionDayDto(
                report.Id,
                report.ReportDate,
                report.WorksiteId,
                worksites.GetValueOrDefault(report.WorksiteId)?.Code ?? string.Empty,
                worksites.GetValueOrDefault(report.WorksiteId)?.Name ?? string.Empty,
                report.Status.ToString(),
                report.Crew
                    .Select(member => new InspectionPersonDto(
                        member.UserId,
                        members.GetValueOrDefault(member.UserId)?.DisplayName
                            ?? string.Empty,
                        member.Hours,
                        certifications
                            .Where(item => item.UserId == member.UserId &&
                                item.IsValidOn(report.ReportDate))
                            .Select(item => new InspectionCertificationDto(
                                item.Kind,
                                item.Issuer,
                                item.ValidFrom,
                                item.ExpiresOn,
                                item.DocumentId))
                            .OrderBy(item => item.Kind, StringComparer.OrdinalIgnoreCase)
                            .ToArray()))
                    .OrderBy(item => item.DisplayName, StringComparer.OrdinalIgnoreCase)
                    .ToArray()))
            .OrderBy(item => item.ReportDate)
            .ThenBy(item => item.WorksiteCode, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public async Task<CertificationDto> CreateAsync(
        UpsertCertificationRequest request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var members = await GetMembersByIdAsync(
            membership.OrganizationId,
            cancellationToken);
        if (!members.ContainsKey(request.UserId))
        {
            throw new RegistryValidationException(
                "La persona non appartiene all'organizzazione.");
        }

        await RequireDocumentAsync(
            membership.OrganizationId,
            request.DocumentId,
            cancellationToken);

        var certification = new Certification(
            Guid.CreateVersion7(),
            membership.OrganizationId,
            request.UserId,
            request.Kind,
            request.ValidFrom,
            request.ExpiresOn,
            request.Issuer,
            request.Notes,
            request.DocumentId);

        store.AddCertification(certification);
        await store.SaveChangesAsync(cancellationToken);

        return ToDto(certification, members, Today());
    }

    public async Task<CertificationDto> UpdateAsync(
        Guid certificationId,
        UpsertCertificationRequest request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var certification = await RequireCertificationAsync(
            membership.OrganizationId,
            certificationId,
            cancellationToken);
        await RequireDocumentAsync(
            membership.OrganizationId,
            request.DocumentId,
            cancellationToken);

        certification.Update(
            request.Kind,
            request.ValidFrom,
            request.ExpiresOn,
            request.Issuer,
            request.Notes,
            request.DocumentId);
        await store.SaveChangesAsync(cancellationToken);

        var members = await GetMembersByIdAsync(
            membership.OrganizationId,
            cancellationToken);

        return ToDto(certification, members, Today());
    }

    public async Task DeleteAsync(
        Guid certificationId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var certification = await RequireCertificationAsync(
            membership.OrganizationId,
            certificationId,
            cancellationToken);

        store.RemoveCertification(certification);
        await store.SaveChangesAsync(cancellationToken);
    }

    private static CertificationDto ToDto(
        Certification certification,
        IReadOnlyDictionary<Guid, UserMembership> members,
        DateOnly today)
    {
        return new CertificationDto(
            certification.Id,
            certification.UserId,
            members.GetValueOrDefault(certification.UserId)?.DisplayName
                ?? string.Empty,
            certification.Kind,
            certification.Issuer,
            certification.ValidFrom,
            certification.ExpiresOn,
            certification.Notes,
            certification.DocumentId,
            certification.IsValidOn(today),
            certification.ExpiresOn is { } expiresOn
                ? expiresOn.DayNumber - today.DayNumber
                : null,
            certification.UpdatedAt);
    }

    private DateOnly Today()
    {
        return DateOnly.FromDateTime(timeProvider.GetUtcNow().UtcDateTime);
    }

    private async Task<Dictionary<Guid, UserMembership>> GetMembersByIdAsync(
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        var members = await store.GetOrganizationMembersAsync(
            organizationId,
            cancellationToken);

        return members.ToDictionary(item => item.UserId);
    }

    private async Task<Certification> RequireCertificationAsync(
        Guid organizationId,
        Guid certificationId,
        CancellationToken cancellationToken)
    {
        return await store.GetCertificationAsync(
                organizationId,
                certificationId,
                cancellationToken)
            ?? throw new ResourceNotFoundException("L'abilitazione non esiste.");
    }

    private async Task RequireDocumentAsync(
        Guid organizationId,
        Guid? documentId,
        CancellationToken cancellationToken)
    {
        if (documentId is not { } id)
        {
            return;
        }

        // Un attestato allegato che punta al documento di un'altra
        // organizzazione sarebbe una perdita di dati fra tenant.
        _ = await store.GetDocumentAsync(organizationId, id, cancellationToken)
            ?? throw new RegistryValidationException("L'attestato allegato non esiste.");
    }
}

public sealed record CertificationDto(
    Guid Id,
    Guid UserId,
    string DisplayName,
    string Kind,
    string? Issuer,
    DateOnly ValidFrom,
    DateOnly? ExpiresOn,
    string? Notes,
    Guid? DocumentId,
    bool IsValidToday,
    int? DaysToExpiry,
    DateTimeOffset UpdatedAt);

public sealed record UpsertCertificationRequest(
    Guid UserId,
    string Kind,
    DateOnly ValidFrom,
    DateOnly? ExpiresOn,
    string? Issuer,
    string? Notes,
    Guid? DocumentId);

public sealed record InspectionDayDto(
    Guid ReportId,
    DateOnly ReportDate,
    Guid WorksiteId,
    string WorksiteCode,
    string WorksiteName,
    string Status,
    IReadOnlyList<InspectionPersonDto> Crew);

public sealed record InspectionPersonDto(
    Guid UserId,
    string DisplayName,
    decimal Hours,
    IReadOnlyList<InspectionCertificationDto> Certifications);

public sealed record InspectionCertificationDto(
    string Kind,
    string? Issuer,
    DateOnly ValidFrom,
    DateOnly? ExpiresOn,
    Guid? DocumentId);
