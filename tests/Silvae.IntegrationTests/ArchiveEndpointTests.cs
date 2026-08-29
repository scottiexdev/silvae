using System.Net;
using System.Net.Http.Json;
using System.Text;
using FluentAssertions;
using Silvae.Application.Documents;
using Silvae.Application.Organizations;
using Silvae.Application.People;

namespace Silvae.IntegrationTests;

/// <summary>
/// Archivio dei documenti e abilitazioni delle persone: il materiale che
/// l'ufficio mostra a un ente finanziatore o a un RSPP.
/// </summary>
public sealed class ArchiveEndpointTests
{
    [Fact]
    public async Task ADocumentGoesUpAndComesBackDown()
    {
        await using var factory = new SilvaeApiFactory();
        using var administrator = factory.CreateClientFor(Guid.NewGuid());
        await SilvaeApiFactory.BootstrapAsync(administrator);

        using var form = new MultipartFormDataContent();
        using var file = new ByteArrayContent(
            Encoding.UTF8.GetBytes("autorizzazione al taglio"));
        form.Add(file, "file", "autorizzazione.txt");
        form.Add(new StringContent("Autorizzazione al taglio"), "title");
        form.Add(new StringContent("Autorizzazione"), "category");
        form.Add(new StringContent("2027-12-31"), "expiresOn");

        var uploaded = await administrator.PostAsync("/api/documents", form);
        uploaded.StatusCode.Should().Be(HttpStatusCode.Created);
        var document = await uploaded.Content.ReadFromJsonAsync<DocumentDto>();
        document!.SizeBytes.Should().Be(24);
        document.IsExpired.Should().BeFalse();

        var downloaded = await administrator.GetAsync(
            $"/api/documents/{document.Id}/content");

        downloaded.StatusCode.Should().Be(HttpStatusCode.OK);
        (await downloaded.Content.ReadAsStringAsync()).Should()
            .Be("autorizzazione al taglio");
    }

    [Fact]
    public async Task ACertificationIsRecordedAndReadBack()
    {
        await using var factory = new SilvaeApiFactory();
        var workerId = Guid.NewGuid();
        using var administrator = factory.CreateClientFor(Guid.NewGuid());
        await SilvaeApiFactory.BootstrapAsync(administrator);
        await administrator.PutAsJsonAsync(
            $"/api/organization/members/{workerId}",
            new UpsertMemberRequest("Mario Rossi", "Worker"));

        var created = await administrator.PostAsJsonAsync(
            "/api/certifications",
            new UpsertCertificationRequest(
                workerId,
                "Patentino motosega",
                new DateOnly(2024, 3, 1),
                new DateOnly(2029, 3, 1),
                "Ente formatore",
                null,
                null));

        created.StatusCode.Should().Be(HttpStatusCode.Created);
        var listed = await administrator
            .GetFromJsonAsync<List<CertificationDto>>("/api/certifications");
        listed.Should().ContainSingle()
            .Which.DisplayName.Should().Be("Mario Rossi");
    }

    [Fact]
    public async Task AnOperatorCannotUploadIntoTheArchive()
    {
        await using var factory = new SilvaeApiFactory();
        var workerId = Guid.NewGuid();
        using var administrator = factory.CreateClientFor(Guid.NewGuid());
        using var worker = factory.CreateClientFor(workerId);

        var organizationId = await SilvaeApiFactory.BootstrapAsync(administrator);
        await administrator.PutAsJsonAsync(
            $"/api/organization/members/{workerId}",
            new UpsertMemberRequest("Mario Rossi", "Worker"));
        worker.DefaultRequestHeaders.Add(
            "X-Organization-Id",
            organizationId.ToString());

        using var form = new MultipartFormDataContent();
        using var file = new ByteArrayContent(Encoding.UTF8.GetBytes("x"));
        form.Add(file, "file", "nota.txt");
        form.Add(new StringContent("Nota"), "title");
        form.Add(new StringContent("Autorizzazione"), "category");

        var response = await worker.PostAsync("/api/documents", form);

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }
}
