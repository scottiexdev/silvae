using FluentAssertions;
using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Application.Organizations;
using Silvae.Domain.Organizations;

namespace Silvae.Application.Tests;

public sealed class OrganizationBootstrapServiceTests
{
    private const string Secret = "segreto-di-deploy";

    private static readonly Guid UserId = Guid.NewGuid();

    [Fact]
    public async Task TheDeploySecretCreatesTheOrganizationAndItsFirstAdministrator()
    {
        var store = new InMemorySilvaeStore();
        var service = CreateService(store, Secret);

        var result = await service.CreateOrganizationAsync(
            Secret,
            new CreateOrganizationRequest("Cooperativa Verde", "Alberto"),
            CancellationToken.None);

        result.Role.Should().Be(nameof(OrganizationRole.Administrator));
        result.UserId.Should().Be(UserId);
        store.Organizations.Should().ContainSingle()
            .Which.Name.Should().Be("Cooperativa Verde");
        store.Memberships.Should().ContainSingle()
            .Which.OrganizationId.Should().Be(result.OrganizationId);
    }

    [Fact]
    public async Task AWrongSecretCreatesNothing()
    {
        var store = new InMemorySilvaeStore();
        var service = CreateService(store, Secret);

        var action = () => service.CreateOrganizationAsync(
            "segreto-sbagliato",
            new CreateOrganizationRequest("Cooperativa Verde", "Alberto"),
            CancellationToken.None);

        await action.Should().ThrowAsync<ResourceAccessDeniedException>();
        store.Organizations.Should().BeEmpty();
    }

    [Fact]
    public async Task WithoutAConfiguredSecretTheBootstrapIsClosed()
    {
        var store = new InMemorySilvaeStore();
        var service = CreateService(store, configuredSecret: null);

        var action = () => service.CreateOrganizationAsync(
            null,
            new CreateOrganizationRequest("Cooperativa Verde", "Alberto"),
            CancellationToken.None);

        await action.Should().ThrowAsync<ResourceAccessDeniedException>();
        store.Organizations.Should().BeEmpty();
    }

    [Fact]
    public async Task AnAnonymousCallerHasNoIdentityToMakeAdministrator()
    {
        var store = new InMemorySilvaeStore();
        var service = new OrganizationBootstrapService(
            new TestRequestContext { UserId = Guid.Empty },
            store,
            new TestBootstrapSecret(Secret));

        var action = () => service.CreateOrganizationAsync(
            Secret,
            new CreateOrganizationRequest("Cooperativa Verde", "Alberto"),
            CancellationToken.None);

        await action.Should().ThrowAsync<AuthenticationRequiredException>();
    }

    private static OrganizationBootstrapService CreateService(
        InMemorySilvaeStore store,
        string? configuredSecret)
    {
        return new OrganizationBootstrapService(
            new TestRequestContext { UserId = UserId },
            store,
            new TestBootstrapSecret(configuredSecret));
    }

    private sealed class TestBootstrapSecret(string? secret) : IBootstrapSecret
    {
        public bool IsConfigured => secret is not null;

        public bool Matches(string? candidate) =>
            secret is not null && string.Equals(secret, candidate, StringComparison.Ordinal);
    }
}
