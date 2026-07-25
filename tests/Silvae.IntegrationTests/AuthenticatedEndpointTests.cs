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
using Silvae.Application.Identity;
using Silvae.Domain.Organizations;
using Silvae.Infrastructure.Persistence;

namespace Silvae.IntegrationTests;

public sealed class AuthenticatedEndpointTests
{
    private static readonly Guid UserId =
        Guid.Parse("e84cf775-1a64-4f42-99a3-b6fa2c900475");
    private static readonly Guid OrganizationId =
        Guid.Parse("1fa7d916-d7b6-479f-94ec-ae61d1ce83f0");

    [Fact]
    public async Task GetMeUsesAuthenticatedIdentityAndValidatedMembership()
    {
        await using var factory = new AuthenticatedApiFactory();
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add(
            "X-Organization-Id",
            OrganizationId.ToString());

        var response = await client.GetAsync("/api/me");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<CurrentUserDto>();
        body.Should().NotBeNull();
        body!.UserId.Should().Be(UserId);
        body.SelectedOrganizationId.Should().Be(OrganizationId);
    }

    [Fact]
    public async Task GetMeRejectsAnOrganizationOutsideTheMembership()
    {
        await using var factory = new AuthenticatedApiFactory();
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add(
            "X-Organization-Id",
            Guid.NewGuid().ToString());

        var response = await client.GetAsync("/api/me");

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    private sealed class AuthenticatedApiFactory : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
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
                    .AddScheme<
                        AuthenticationSchemeOptions,
                        TestAuthenticationHandler>(
                        TestAuthenticationHandler.SchemeName,
                        options => { });
            });
        }

        protected override void ConfigureClient(HttpClient client)
        {
            using var scope = Services.CreateScope();
            var database = scope.ServiceProvider
                .GetRequiredService<SilvaeDbContext>();
            if (!database.Organizations.Any(item =>
                    item.Id == OrganizationId))
            {
                database.Organizations.Add(
                    new Organization(OrganizationId, "Cooperativa Verde"));
                database.UserMemberships.Add(
                    new UserMembership(
                        OrganizationId,
                        UserId,
                        OrganizationRole.Worker,
                        "Mario Rossi"));
                database.SaveChanges();
            }

            base.ConfigureClient(client);
        }
    }

    private sealed class TestAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(
            options,
            logger,
            encoder)
    {
        public const string SchemeName = "Test";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var identity = new ClaimsIdentity(
                [new Claim("sub", UserId.ToString())],
                SchemeName);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, SchemeName);
            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }
}
