using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Silvae.Application.Identity;
using Silvae.Application.JobOrders;
using Silvae.Application.Organizations;
using Silvae.Application.Worksites;

namespace Silvae.IntegrationTests;

/// <summary>
/// Il percorso che mancava: da un database vuoto a un cantiere che l'operatore
/// vede sul telefono, senza inserire righe a mano nel database.
/// </summary>
public sealed class RegistryEndpointTests
{
    [Fact]
    public async Task AnEmptyDatabaseReachesAWorksiteTheOperatorCanSee()
    {
        await using var factory = new SilvaeApiFactory();
        var administratorId = Guid.NewGuid();
        var workerId = Guid.NewGuid();
        using var administrator = factory.CreateClientFor(administratorId);

        var organizationId = await SilvaeApiFactory.BootstrapAsync(administrator);

        var member = await administrator.PutAsJsonAsync(
            $"/api/organization/members/{workerId}",
            new UpsertMemberRequest("Mario Rossi", "Worker"));
        member.StatusCode.Should().Be(HttpStatusCode.OK);

        var jobOrderResponse = await administrator.PostAsJsonAsync(
            "/api/job-orders",
            new CreateJobOrderRequest("C-001", "Sfalcio comunale", "Comune di Trento"));
        jobOrderResponse.StatusCode.Should().Be(HttpStatusCode.Created);
        var jobOrder = await jobOrderResponse.Content.ReadFromJsonAsync<JobOrderDto>();
        jobOrder.Should().NotBeNull();

        var worksiteResponse = await administrator.PostAsJsonAsync(
            "/api/worksites",
            new CreateWorksiteRequest(
                "W-001",
                "Parco nord",
                "Via Roma 1",
                jobOrder!.Id));
        worksiteResponse.StatusCode.Should().Be(HttpStatusCode.Created);
        var worksite = await worksiteResponse.Content
            .ReadFromJsonAsync<WorksiteDetailDto>();
        worksite.Should().NotBeNull();

        var assignment = await administrator.PutAsync(
            $"/api/worksites/{worksite!.Worksite.Id}/assignments/{workerId}",
            content: null);
        assignment.StatusCode.Should().Be(HttpStatusCode.OK);

        using var worker = factory.CreateClientFor(workerId);
        var identity = await worker.GetFromJsonAsync<CurrentUserDto>("/api/me");
        identity.Should().NotBeNull();
        identity!.SelectedOrganizationId.Should().Be(organizationId);

        var visible = await worker.GetFromJsonAsync<WorksiteDto[]>("/api/worksites");
        visible.Should().ContainSingle();
        visible![0].Code.Should().Be("W-001");
        visible[0].JobOrderCode.Should().Be("C-001");
    }

    [Fact]
    public async Task WithoutTheDeploySecretNoOrganizationIsCreated()
    {
        await using var factory = new SilvaeApiFactory();
        using var client = factory.CreateClientFor(Guid.NewGuid());

        var response = await client.PostAsJsonAsync(
            "/api/bootstrap/organization",
            new CreateOrganizationRequest("Cooperativa Verde", "Alberto"));

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task AnOperatorCannotWriteTheRegistry()
    {
        await using var factory = new SilvaeApiFactory();
        var administratorId = Guid.NewGuid();
        var workerId = Guid.NewGuid();
        using var administrator = factory.CreateClientFor(administratorId);
        var organizationId = await SilvaeApiFactory.BootstrapAsync(administrator);
        await administrator.PutAsJsonAsync(
            $"/api/organization/members/{workerId}",
            new UpsertMemberRequest("Mario Rossi", "Worker"));

        using var worker = factory.CreateClientFor(workerId);
        worker.DefaultRequestHeaders.Add(
            "X-Organization-Id",
            organizationId.ToString());
        var response = await worker.PostAsJsonAsync(
            "/api/job-orders",
            new CreateJobOrderRequest("C-002", "Potatura", null));

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task TheSameWorksiteCodeTwiceIsAConflict()
    {
        await using var factory = new SilvaeApiFactory();
        using var administrator = factory.CreateClientFor(Guid.NewGuid());
        await SilvaeApiFactory.BootstrapAsync(administrator);
        await administrator.PostAsJsonAsync(
            "/api/worksites",
            new CreateWorksiteRequest("W-001", "Parco nord", null, null));

        var duplicate = await administrator.PostAsJsonAsync(
            "/api/worksites",
            new CreateWorksiteRequest("w-001", "Doppione", null, null));

        duplicate.StatusCode.Should().Be(HttpStatusCode.Conflict);
    }

    [Fact]
    public async Task AnUnknownWorksiteIsNotFound()
    {
        await using var factory = new SilvaeApiFactory();
        using var administrator = factory.CreateClientFor(Guid.NewGuid());
        await SilvaeApiFactory.BootstrapAsync(administrator);

        var response = await administrator.GetAsync(
            $"/api/worksites/{Guid.NewGuid()}");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }
}
