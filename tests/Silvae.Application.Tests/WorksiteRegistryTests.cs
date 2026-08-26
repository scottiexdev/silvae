using FluentAssertions;
using Silvae.Application.Common;
using Silvae.Application.JobOrders;
using Silvae.Application.Worksites;
using Silvae.Domain.Organizations;
using Silvae.Domain.Worksites;

namespace Silvae.Application.Tests;

public sealed class WorksiteRegistryTests
{
    [Fact]
    public async Task AWorksiteCanBeCreatedBeforeItsJobOrderExists()
    {
        var fixture = new RegistryFixture(OrganizationRole.Coordinator);

        var created = await fixture.Worksites.CreateAsync(
            new CreateWorksiteRequest("c-001", "Parco nord", "Via Roma 1", null),
            CancellationToken.None);

        created.Worksite.Code.Should().Be("C-001");
        created.Worksite.JobOrderId.Should().BeNull();
        created.Worksite.Address.Should().Be("Via Roma 1");
        created.Assignments.Should().BeEmpty();
    }

    [Fact]
    public async Task AWorksiteUnderAJobOrderCarriesItsCodeAndName()
    {
        var fixture = new RegistryFixture(OrganizationRole.Coordinator);
        var jobOrder = await fixture.JobOrders.CreateAsync(
            new CreateJobOrderRequest("C-001", "Sfalcio comunale", null),
            CancellationToken.None);

        var created = await fixture.Worksites.CreateAsync(
            new CreateWorksiteRequest("W-001", "Parco nord", null, jobOrder.Id),
            CancellationToken.None);

        created.Worksite.JobOrderId.Should().Be(jobOrder.Id);
        created.Worksite.JobOrderCode.Should().Be("C-001");
        created.Worksite.JobOrderName.Should().Be("Sfalcio comunale");
    }

    [Fact]
    public async Task AWorksiteCannotPointToAJobOrderThatDoesNotExist()
    {
        var fixture = new RegistryFixture(OrganizationRole.Coordinator);

        var action = () => fixture.Worksites.CreateAsync(
            new CreateWorksiteRequest("W-001", "Parco nord", null, Guid.NewGuid()),
            CancellationToken.None);

        await action.Should().ThrowAsync<RegistryValidationException>();
    }

    [Fact]
    public async Task AssigningSomeoneOutsideTheOrganizationIsRejected()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);
        var created = await fixture.Worksites.CreateAsync(
            new CreateWorksiteRequest("W-001", "Parco nord", null, null),
            CancellationToken.None);

        var action = () => fixture.Worksites.AssignAsync(
            created.Worksite.Id,
            Guid.NewGuid(),
            CancellationToken.None);

        await action.Should().ThrowAsync<RegistryValidationException>();
    }

    [Fact]
    public async Task TheOperatorSeesTheWorksiteOnlyOnceAssigned()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);
        var created = await fixture.Worksites.CreateAsync(
            new CreateWorksiteRequest("W-001", "Parco nord", null, null),
            CancellationToken.None);
        var asWorker = fixture.WorksitesSeenBy(RegistryFixture.WorkerId);

        var before = await asWorker.GetAssignedAsync(false, CancellationToken.None);
        var assigned = await fixture.Worksites.AssignAsync(
            created.Worksite.Id,
            RegistryFixture.WorkerId,
            CancellationToken.None);
        var after = await asWorker.GetAssignedAsync(false, CancellationToken.None);

        before.Should().BeEmpty();
        assigned.Assignments.Should().ContainSingle()
            .Which.DisplayName.Should().Be("Mario Rossi");
        after.Should().ContainSingle().Which.Id.Should().Be(created.Worksite.Id);
    }

    [Fact]
    public async Task AssigningTwiceDoesNotDuplicateTheAssignment()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);
        var created = await fixture.Worksites.CreateAsync(
            new CreateWorksiteRequest("W-001", "Parco nord", null, null),
            CancellationToken.None);
        await fixture.Worksites.AssignAsync(
            created.Worksite.Id,
            RegistryFixture.WorkerId,
            CancellationToken.None);

        var second = await fixture.Worksites.AssignAsync(
            created.Worksite.Id,
            RegistryFixture.WorkerId,
            CancellationToken.None);

        second.Assignments.Should().ContainSingle();
    }

    [Fact]
    public async Task UnassigningTakesTheWorksiteAwayFromTheOperator()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);
        var created = await fixture.Worksites.CreateAsync(
            new CreateWorksiteRequest("W-001", "Parco nord", null, null),
            CancellationToken.None);
        await fixture.Worksites.AssignAsync(
            created.Worksite.Id,
            RegistryFixture.WorkerId,
            CancellationToken.None);

        await fixture.Worksites.UnassignAsync(
            created.Worksite.Id,
            RegistryFixture.WorkerId,
            CancellationToken.None);

        var asWorker = fixture.WorksitesSeenBy(RegistryFixture.WorkerId);
        var visible = await asWorker.GetAssignedAsync(false, CancellationToken.None);
        visible.Should().BeEmpty();
    }

    [Fact]
    public async Task AClosedWorksiteDisappearsForTheOperatorAndStaysForTheOffice()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);
        var created = await fixture.Worksites.CreateAsync(
            new CreateWorksiteRequest("W-001", "Parco nord", null, null),
            CancellationToken.None);
        await fixture.Worksites.AssignAsync(
            created.Worksite.Id,
            RegistryFixture.WorkerId,
            CancellationToken.None);

        await fixture.Worksites.UpdateAsync(
            created.Worksite.Id,
            new UpdateWorksiteRequest(null, null, null, IsActive: false),
            CancellationToken.None);

        var asWorker = fixture.WorksitesSeenBy(RegistryFixture.WorkerId);
        var forTheOperator = await asWorker.GetAssignedAsync(
            false,
            CancellationToken.None);
        var forTheOffice = await fixture.Worksites.GetAssignedAsync(
            true,
            CancellationToken.None);

        forTheOperator.Should().BeEmpty();
        forTheOffice.Should().ContainSingle().Which.IsActive.Should().BeFalse();
    }

    [Fact]
    public async Task AnOperatorCannotAskForTheClosedWorksites()
    {
        var fixture = new RegistryFixture(OrganizationRole.Worker);
        var worksite = new Worksite(
            Guid.NewGuid(),
            RegistryFixture.OrganizationId,
            "W-001",
            "Parco nord");
        worksite.Assign(RegistryFixture.CallerId);
        worksite.Close();
        fixture.Store.Worksites.Add(worksite);

        var visible = await fixture.Worksites.GetAssignedAsync(
            true,
            CancellationToken.None);

        visible.Should().BeEmpty();
    }

    [Fact]
    public async Task DetachingTheJobOrderLeavesTheWorksiteInPlace()
    {
        var fixture = new RegistryFixture(OrganizationRole.Coordinator);
        var jobOrder = await fixture.JobOrders.CreateAsync(
            new CreateJobOrderRequest("C-001", "Sfalcio comunale", null),
            CancellationToken.None);
        var created = await fixture.Worksites.CreateAsync(
            new CreateWorksiteRequest("W-001", "Parco nord", null, jobOrder.Id),
            CancellationToken.None);

        var detached = await fixture.Worksites.UpdateAsync(
            created.Worksite.Id,
            new UpdateWorksiteRequest(null, null, Guid.Empty, null),
            CancellationToken.None);

        detached.Worksite.JobOrderId.Should().BeNull();
        detached.Worksite.JobOrderCode.Should().BeNull();
    }

    [Fact]
    public async Task AWorkerCannotReadTheTeamOfAWorksite()
    {
        var fixture = new RegistryFixture(OrganizationRole.Worker);
        var worksite = new Worksite(
            Guid.NewGuid(),
            RegistryFixture.OrganizationId,
            "W-001",
            "Parco nord");
        worksite.Assign(RegistryFixture.CallerId);
        fixture.Store.Worksites.Add(worksite);

        var action = () => fixture.Worksites.GetAsync(
            worksite.Id,
            CancellationToken.None);

        await action.Should().ThrowAsync<ResourceAccessDeniedException>();
    }
}
