using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;
using Silvae.Application.DailyReports;
using Silvae.Application.Organizations;
using Silvae.Application.Sync;
using Silvae.Application.Worksites;

namespace Silvae.IntegrationTests;

/// <summary>
/// Il rapportino per intero: compilato in cantiere e sincronizzato, inviato
/// dalla coda, approvato dall'ufficio e riaperto, con l'audit che racconta il
/// percorso.
/// </summary>
public sealed class DailyReportEndpointTests
{
    private static readonly DateOnly ReportDate =
        DateOnly.FromDateTime(DateTime.UtcNow);

    [Fact]
    public async Task AReportGoesFromTheFieldToTheOfficeAndBack()
    {
        await using var factory = new SilvaeApiFactory();
        var workerId = Guid.NewGuid();
        using var administrator = factory.CreateClientFor(Guid.NewGuid());
        using var worker = factory.CreateClientFor(workerId);

        var context = await PrepareWorksiteAsync(
            factory,
            administrator,
            worker,
            workerId);
        var reportId = Guid.NewGuid();

        var pushed = await PushAsync(
            worker,
            new SyncOperationDto(
                Guid.NewGuid(),
                context.OrganizationId,
                reportId,
                "dailyReport",
                "upsert",
                0,
                Payload(
                    context.WorksiteId,
                    crew: [new CrewMemberPayload(workerId, 7.5m, "mezza in salita")],
                    activities: [new ActivityPayload("Sfalcio", 1200m, "mq")],
                    safetyChecks:
                    [
                        new SafetyCheckPayload("DPI-CASCO", true, null),
                        new SafetyCheckPayload(
                            "DPI-CUFFIE",
                            false,
                            "dimenticate in sede"),
                    ]),
                DateTimeOffset.UtcNow));
        pushed.Operations.Single().Version.Should().Be(1);

        var submitted = await PushAsync(
            worker,
            new SyncOperationDto(
                Guid.NewGuid(),
                context.OrganizationId,
                reportId,
                "dailyReport",
                "submit",
                1,
                Payload(context.WorksiteId),
                DateTimeOffset.UtcNow));
        submitted.Operations.Single().Version.Should().Be(2);

        var detail = await administrator.GetFromJsonAsync<DailyReportDetailDto>(
            $"/api/daily-reports/{reportId}");
        detail.Should().NotBeNull();
        detail!.Status.Should().Be("Submitted");
        detail.TotalHours.Should().Be(7.5m);
        detail.WorksiteCode.Should().Be("W-001");
        detail.Crew.Should().ContainSingle()
            .Which.DisplayName.Should().Be("Mario Rossi");
        detail.SafetyChecks.Should().HaveCount(2);
        detail.Audit.Select(entry => entry.Action).Should()
            .Equal("Created", "Submitted");

        var approved = await administrator.PostAsync(
            $"/api/daily-reports/{reportId}/approve",
            content: null);
        approved.StatusCode.Should().Be(HttpStatusCode.OK);
        var approvedDetail = await approved.Content
            .ReadFromJsonAsync<DailyReportDetailDto>();
        approvedDetail!.Status.Should().Be("Approved");

        var reopened = await administrator.PostAsync(
            $"/api/daily-reports/{reportId}/reopen",
            content: null);
        reopened.StatusCode.Should().Be(HttpStatusCode.OK);
        var reopenedDetail = await reopened.Content
            .ReadFromJsonAsync<DailyReportDetailDto>();
        reopenedDetail!.Status.Should().Be("Reopened");
        reopenedDetail.Audit.Should().HaveCount(4);
    }

    [Fact]
    public async Task AnOperatorCannotApproveWhatTheyWrote()
    {
        await using var factory = new SilvaeApiFactory();
        var workerId = Guid.NewGuid();
        using var administrator = factory.CreateClientFor(Guid.NewGuid());
        using var worker = factory.CreateClientFor(workerId);

        var context = await PrepareWorksiteAsync(
            factory,
            administrator,
            worker,
            workerId);
        var reportId = Guid.NewGuid();
        await PushAsync(
            worker,
            new SyncOperationDto(
                Guid.NewGuid(),
                context.OrganizationId,
                reportId,
                "dailyReport",
                "upsert",
                0,
                Payload(
                    context.WorksiteId,
                    crew: [new CrewMemberPayload(workerId, 8m, null)]),
                DateTimeOffset.UtcNow));

        var response = await worker.PostAsync(
            $"/api/daily-reports/{reportId}/approve",
            content: null);

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task AReportWithoutACrewIsNotAccepted()
    {
        await using var factory = new SilvaeApiFactory();
        var workerId = Guid.NewGuid();
        using var administrator = factory.CreateClientFor(Guid.NewGuid());
        using var worker = factory.CreateClientFor(workerId);

        var context = await PrepareWorksiteAsync(
            factory,
            administrator,
            worker,
            workerId);
        var reportId = Guid.NewGuid();
        await PushAsync(
            worker,
            new SyncOperationDto(
                Guid.NewGuid(),
                context.OrganizationId,
                reportId,
                "dailyReport",
                "upsert",
                0,
                Payload(context.WorksiteId),
                DateTimeOffset.UtcNow));

        var response = await worker.PostAsync(
            $"/api/daily-reports/{reportId}/submit",
            content: null);

        response.StatusCode.Should().Be(HttpStatusCode.Conflict);
    }

    private static JsonElement Payload(
        Guid worksiteId,
        IReadOnlyList<CrewMemberPayload>? crew = null,
        IReadOnlyList<ActivityPayload>? activities = null,
        IReadOnlyList<SafetyCheckPayload>? safetyChecks = null)
    {
        return JsonSerializer.SerializeToElement(new DailyReportPayload(
            worksiteId,
            ReportDate,
            "Giornata regolare",
            crew,
            activities,
            safetyChecks));
    }

    private static async Task<PushSyncResponse> PushAsync(
        HttpClient client,
        SyncOperationDto operation)
    {
        var response = await client.PostAsJsonAsync(
            "/api/sync/push",
            new PushSyncRequest([operation]));
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<PushSyncResponse>();
        body.Should().NotBeNull();
        return body!;
    }

    private static async Task<WorksiteContext> PrepareWorksiteAsync(
        SilvaeApiFactory factory,
        HttpClient administrator,
        HttpClient worker,
        Guid workerId)
    {
        var organizationId = await SilvaeApiFactory.BootstrapAsync(administrator);
        await administrator.PutAsJsonAsync(
            $"/api/organization/members/{workerId}",
            new UpsertMemberRequest("Mario Rossi", "Worker"));

        var response = await administrator.PostAsJsonAsync(
            "/api/worksites",
            new CreateWorksiteRequest("W-001", "Parco nord", null, null));
        var worksite = await response.Content
            .ReadFromJsonAsync<WorksiteDetailDto>();
        await administrator.PutAsync(
            $"/api/worksites/{worksite!.Worksite.Id}/assignments/{workerId}",
            content: null);

        worker.DefaultRequestHeaders.Add(
            "X-Organization-Id",
            organizationId.ToString());

        return new WorksiteContext(organizationId, worksite.Worksite.Id);
    }

    private sealed record WorksiteContext(Guid OrganizationId, Guid WorksiteId);
}
