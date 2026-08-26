using FluentAssertions;
using Silvae.Application.Common;
using Silvae.Application.JobOrders;
using Silvae.Domain.JobOrders;
using Silvae.Domain.Organizations;

namespace Silvae.Application.Tests;

public sealed class JobOrderServiceTests
{
    [Fact]
    public async Task CreatingAJobOrderNormalizesTheCode()
    {
        var fixture = new RegistryFixture(OrganizationRole.Coordinator);

        var jobOrder = await fixture.JobOrders.CreateAsync(
            new CreateJobOrderRequest(" c-001 ", " Sfalcio comunale ", "  "),
            CancellationToken.None);

        jobOrder.Code.Should().Be("C-001");
        jobOrder.Name.Should().Be("Sfalcio comunale");
        jobOrder.Customer.Should().BeNull();
        jobOrder.IsActive.Should().BeTrue();
        fixture.Store.JobOrders.Should().ContainSingle();
    }

    [Fact]
    public async Task TheSameCodeWrittenInMinusculeIsStillADuplicate()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);
        await fixture.JobOrders.CreateAsync(
            new CreateJobOrderRequest("C-001", "Sfalcio comunale", null),
            CancellationToken.None);

        var action = () => fixture.JobOrders.CreateAsync(
            new CreateJobOrderRequest("c-001", "Doppione", null),
            CancellationToken.None);

        await action.Should().ThrowAsync<RegistryConflictException>();
    }

    [Fact]
    public async Task AWorkerCannotWriteTheRegistry()
    {
        var fixture = new RegistryFixture(OrganizationRole.Worker);

        var action = () => fixture.JobOrders.CreateAsync(
            new CreateJobOrderRequest("C-001", "Sfalcio comunale", null),
            CancellationToken.None);

        await action.Should().ThrowAsync<ResourceAccessDeniedException>();
    }

    [Fact]
    public async Task AWorkerStillReadsTheJobOrdersOfTheOrganization()
    {
        var fixture = new RegistryFixture(OrganizationRole.Worker);
        fixture.Store.JobOrders.Add(new JobOrder(
            Guid.NewGuid(),
            RegistryFixture.OrganizationId,
            "C-001",
            "Sfalcio comunale"));

        var jobOrders = await fixture.JobOrders.GetAllAsync(CancellationToken.None);

        jobOrders.Should().ContainSingle().Which.Code.Should().Be("C-001");
    }

    [Fact]
    public async Task ClosingAJobOrderBumpsItsVersion()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);
        var created = await fixture.JobOrders.CreateAsync(
            new CreateJobOrderRequest("C-001", "Sfalcio comunale", "Comune di Trento"),
            CancellationToken.None);

        var closed = await fixture.JobOrders.UpdateAsync(
            created.Id,
            new UpdateJobOrderRequest(null, null, IsActive: false),
            CancellationToken.None);

        closed.IsActive.Should().BeFalse();
        closed.Version.Should().BeGreaterThan(created.Version);
        closed.Customer.Should().Be("Comune di Trento");
    }

    [Fact]
    public async Task UpdatingAJobOrderOfAnotherOrganizationFindsNothing()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);
        fixture.Store.JobOrders.Add(new JobOrder(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "C-999",
            "Commessa altrui"));

        var action = () => fixture.JobOrders.UpdateAsync(
            fixture.Store.JobOrders[0].Id,
            new UpdateJobOrderRequest("Rinominata", null, null),
            CancellationToken.None);

        await action.Should().ThrowAsync<ResourceNotFoundException>();
    }
}
