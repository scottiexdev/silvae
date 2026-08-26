using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Application.Identity;
using Silvae.Domain.DailyReports;
using Silvae.Domain.Organizations;

namespace Silvae.Application.DailyReports;

/// <summary>
/// Consultazione e transizioni di stato del rapportino. Quello che accade in
/// cantiere passa dalla sincronizzazione, perché deve funzionare senza rete;
/// quello che accade in ufficio, approvazione e riapertura, passa da qui.
/// </summary>
public sealed class DailyReportService(
    IRequestContext requestContext,
    ISilvaeStore store,
    CurrentUserService currentUser,
    TimeProvider timeProvider)
{
    public async Task<DailyReportDetailDto> GetAsync(
        Guid reportId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        var report = await RequireReadableAsync(
            membership,
            reportId,
            cancellationToken);

        return await ToDetailAsync(report, membership.OrganizationId, cancellationToken);
    }

    public async Task<DailyReportDetailDto> SubmitAsync(
        Guid reportId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        var report = await RequireReportAsync(
            membership.OrganizationId,
            reportId,
            cancellationToken);
        DailyReportAuthorization.RequireCanEdit(report, membership, requestContext.UserId);

        report.Submit(requestContext.UserId, timeProvider.GetUtcNow());
        await store.SaveChangesAsync(cancellationToken);

        return await ToDetailAsync(report, membership.OrganizationId, cancellationToken);
    }

    public async Task<DailyReportDetailDto> ApproveAsync(
        Guid reportId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var report = await RequireReportAsync(
            membership.OrganizationId,
            reportId,
            cancellationToken);
        report.Approve(requestContext.UserId, timeProvider.GetUtcNow());
        await store.SaveChangesAsync(cancellationToken);

        return await ToDetailAsync(report, membership.OrganizationId, cancellationToken);
    }

    public async Task<DailyReportDetailDto> ReopenAsync(
        Guid reportId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var report = await RequireReportAsync(
            membership.OrganizationId,
            reportId,
            cancellationToken);
        report.Reopen(requestContext.UserId, timeProvider.GetUtcNow());
        await store.SaveChangesAsync(cancellationToken);

        return await ToDetailAsync(report, membership.OrganizationId, cancellationToken);
    }

    private async Task<DailyReport> RequireReportAsync(
        Guid organizationId,
        Guid reportId,
        CancellationToken cancellationToken)
    {
        return await store.GetDailyReportAsync(
                organizationId,
                reportId,
                cancellationToken)
            ?? throw new ResourceNotFoundException("Il rapportino non esiste.");
    }

    private async Task<DailyReport> RequireReadableAsync(
        UserMembership membership,
        Guid reportId,
        CancellationToken cancellationToken)
    {
        var report = await RequireReportAsync(
            membership.OrganizationId,
            reportId,
            cancellationToken);

        if (report.AuthorId == requestContext.UserId ||
            DailyReportAuthorization.IsOfficeRole(membership))
        {
            return report;
        }

        // Chi è assegnato al cantiere vede i rapportini di quel cantiere: la
        // squadra lavora insieme e le ore sono le stesse per tutti.
        var assigned = await store.CanAccessWorksiteAsync(
            membership.OrganizationId,
            report.WorksiteId,
            requestContext.UserId,
            includeAll: false,
            cancellationToken);

        return assigned
            ? report
            : throw new ResourceAccessDeniedException(
                "Il rapportino appartiene a un altro cantiere.");
    }

    private async Task<DailyReportDetailDto> ToDetailAsync(
        DailyReport report,
        Guid organizationId,
        CancellationToken cancellationToken)
    {
        var worksite = await store.GetWorksiteAsync(
            organizationId,
            report.WorksiteId,
            cancellationToken);
        var members = (await store.GetOrganizationMembersAsync(
                organizationId,
                cancellationToken))
            .ToDictionary(item => item.UserId);

        return new DailyReportDetailDto(
            report.Id,
            report.OrganizationId,
            report.WorksiteId,
            worksite?.Code ?? string.Empty,
            worksite?.Name ?? string.Empty,
            report.AuthorId,
            NameOf(members, report.AuthorId),
            report.ReportDate,
            report.Notes,
            report.Status.ToString(),
            report.TotalHours(),
            report.Version,
            report.CreatedAt,
            report.UpdatedAt,
            report.Crew
                .Select(member => new DailyReportCrewDto(
                    member.UserId,
                    NameOf(members, member.UserId),
                    member.Hours,
                    member.Note))
                .OrderBy(item => item.DisplayName, StringComparer.OrdinalIgnoreCase)
                .ToArray(),
            report.Activities
                .Select(activity => new DailyReportActivityDto(
                    activity.Description,
                    activity.Quantity,
                    activity.Unit))
                .ToArray(),
            report.SafetyChecks
                .Select(check => new DailyReportSafetyCheckDto(
                    check.Code,
                    check.IsCompliant,
                    check.Note))
                .OrderBy(item => item.Code, StringComparer.Ordinal)
                .ToArray(),
            report.Audit
                .OrderBy(entry => entry.OccurredAt)
                .ThenBy(entry => entry.Version)
                .Select(entry => new DailyReportAuditDto(
                    entry.Action.ToString(),
                    entry.ActorId,
                    NameOf(members, entry.ActorId),
                    entry.Version,
                    entry.OccurredAt))
                .ToArray());
    }

    private static string NameOf(
        IReadOnlyDictionary<Guid, UserMembership> members,
        Guid userId)
    {
        return members.GetValueOrDefault(userId)?.DisplayName ?? string.Empty;
    }
}

/// <summary>
/// Chi può toccare un rapportino. Vale sia per la sincronizzazione sia per gli
/// endpoint: la regola è una sola e sta qui.
/// </summary>
public static class DailyReportAuthorization
{
    public static bool IsOfficeRole(UserMembership membership)
    {
        ArgumentNullException.ThrowIfNull(membership);

        return membership.Role is OrganizationRole.Administrator or
            OrganizationRole.Coordinator;
    }

    public static void RequireCanEdit(
        DailyReport report,
        UserMembership membership,
        Guid userId)
    {
        ArgumentNullException.ThrowIfNull(report);

        if (report.AuthorId != userId && !IsOfficeRole(membership))
        {
            throw new ResourceAccessDeniedException(
                "Il rapportino appartiene a un altro operatore.");
        }
    }
}

public sealed record DailyReportDetailDto(
    Guid Id,
    Guid OrganizationId,
    Guid WorksiteId,
    string WorksiteCode,
    string WorksiteName,
    Guid AuthorId,
    string AuthorName,
    DateOnly ReportDate,
    string? Notes,
    string Status,
    decimal TotalHours,
    long Version,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    IReadOnlyList<DailyReportCrewDto> Crew,
    IReadOnlyList<DailyReportActivityDto> Activities,
    IReadOnlyList<DailyReportSafetyCheckDto> SafetyChecks,
    IReadOnlyList<DailyReportAuditDto> Audit);

public sealed record DailyReportCrewDto(
    Guid UserId,
    string DisplayName,
    decimal Hours,
    string? Note);

public sealed record DailyReportActivityDto(
    string Description,
    decimal? Quantity,
    string? Unit);

public sealed record DailyReportSafetyCheckDto(
    string Code,
    bool IsCompliant,
    string? Note);

public sealed record DailyReportAuditDto(
    string Action,
    Guid ActorId,
    string ActorName,
    long Version,
    DateTimeOffset OccurredAt);
