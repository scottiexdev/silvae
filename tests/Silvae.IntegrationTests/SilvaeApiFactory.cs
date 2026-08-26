using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using FluentAssertions;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Silvae.Application.Organizations;

namespace Silvae.IntegrationTests;

/// <summary>
/// L'API con il segreto di bootstrap configurato e l'identità presa da un
/// header: serve a far parlare con lo stesso backend l'amministratore e
/// l'operatore, come farebbero due telefoni.
/// </summary>
internal sealed class SilvaeApiFactory : WebApplicationFactory<Program>
{
    public const string BootstrapSecret = "segreto-di-prova";

    public HttpClient CreateClientFor(Guid userId)
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Add(
            TestAuthenticationHandler.UserHeader,
            userId.ToString());
        return client;
    }

    /// <summary>
    /// Crea l'organizzazione e seleziona il tenant sul client, come fa l'app.
    /// </summary>
    public static async Task<Guid> BootstrapAsync(HttpClient client)
    {
        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            "/api/bootstrap/organization")
        {
            Content = JsonContent.Create(
                new CreateOrganizationRequest("Cooperativa Verde", "Alberto")),
        };
        request.Headers.Add("X-Bootstrap-Secret", BootstrapSecret);

        var response = await client.SendAsync(request);
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var result = await response.Content.ReadFromJsonAsync<BootstrapResultDto>();
        result.Should().NotBeNull();

        client.DefaultRequestHeaders.Add(
            "X-Organization-Id",
            result!.OrganizationId.ToString());

        return result.OrganizationId;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.UseSetting("SILVAE_BOOTSTRAP_SECRET", BootstrapSecret);
        builder.ConfigureTestServices(services =>
        {
            services
                .AddAuthentication(options =>
                {
                    options.DefaultAuthenticateScheme =
                        TestAuthenticationHandler.SchemeName;
                    options.DefaultChallengeScheme =
                        TestAuthenticationHandler.SchemeName;
                })
                .AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                    TestAuthenticationHandler.SchemeName,
                    options => { });
        });
    }
}

internal sealed class TestAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "Test";

    public const string UserHeader = "X-Test-User";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var header = Request.Headers[UserHeader].FirstOrDefault();
        if (!Guid.TryParse(header, out var userId))
        {
            return Task.FromResult(AuthenticateResult.NoResult());
        }

        var identity = new ClaimsIdentity(
            [new Claim("sub", userId.ToString())],
            SchemeName);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
