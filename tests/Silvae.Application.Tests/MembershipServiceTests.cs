using FluentAssertions;
using Silvae.Application.Common;
using Silvae.Application.Organizations;
using Silvae.Application.Worksites;
using Silvae.Domain.Organizations;

namespace Silvae.Application.Tests;

public sealed class MembershipServiceTests
{
    [Fact]
    public async Task AnAdministratorAddsAPersonAlreadyRegisteredOnSupabase()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);
        var newUserId = Guid.NewGuid();

        var member = await fixture.Members.UpsertAsync(
            newUserId,
            new UpsertMemberRequest("Luigi Bianchi", "CrewLeader"),
            CancellationToken.None);

        member.UserId.Should().Be(newUserId);
        member.Role.Should().Be("CrewLeader");
        fixture.Store.Memberships.Should().HaveCount(3);
    }

    [Fact]
    public async Task AnUnknownRoleIsRejected()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);

        var action = () => fixture.Members.UpsertAsync(
            Guid.NewGuid(),
            new UpsertMemberRequest("Luigi Bianchi", "Padrone"),
            CancellationToken.None);

        await action.Should().ThrowAsync<RegistryValidationException>();
    }

    [Fact]
    public async Task ACoordinatorCannotChangeWhoBelongsToTheOrganization()
    {
        var fixture = new RegistryFixture(OrganizationRole.Coordinator);

        var action = () => fixture.Members.UpsertAsync(
            Guid.NewGuid(),
            new UpsertMemberRequest("Luigi Bianchi", "Worker"),
            CancellationToken.None);

        await action.Should().ThrowAsync<ResourceAccessDeniedException>();
    }

    [Fact]
    public async Task TheLastAdministratorCannotBeDemoted()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);

        var action = () => fixture.Members.UpsertAsync(
            RegistryFixture.CallerId,
            new UpsertMemberRequest("Chi chiama", "Coordinator"),
            CancellationToken.None);

        await action.Should().ThrowAsync<RegistryConflictException>();
    }

    [Fact]
    public async Task TheLastAdministratorCannotBeRemoved()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);

        var action = () => fixture.Members.RemoveAsync(
            RegistryFixture.CallerId,
            CancellationToken.None);

        await action.Should().ThrowAsync<RegistryConflictException>();
    }

    [Fact]
    public async Task AnAdministratorStepsDownOnceAnotherOneExists()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);
        await fixture.Members.UpsertAsync(
            RegistryFixture.WorkerId,
            new UpsertMemberRequest("Mario Rossi", "Administrator"),
            CancellationToken.None);

        var demoted = await fixture.Members.UpsertAsync(
            RegistryFixture.CallerId,
            new UpsertMemberRequest("Chi chiama", "Coordinator"),
            CancellationToken.None);

        demoted.Role.Should().Be("Coordinator");
    }

    [Fact]
    public async Task RemovingAPersonAlsoTakesThemOffTheirWorksites()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);
        var created = await fixture.Worksites.CreateAsync(
            new CreateWorksiteRequest("W-001", "Parco nord", null, null),
            CancellationToken.None);
        await fixture.Worksites.AssignAsync(
            created.Worksite.Id,
            RegistryFixture.WorkerId,
            CancellationToken.None);

        await fixture.Members.RemoveAsync(
            RegistryFixture.WorkerId,
            CancellationToken.None);

        var worksite = await fixture.Worksites.GetAsync(
            created.Worksite.Id,
            CancellationToken.None);
        worksite.Assignments.Should().BeEmpty();
        fixture.Store.Memberships.Should().ContainSingle();
    }

    [Fact]
    public async Task RemovingSomeoneWhoIsNotAMemberFindsNothing()
    {
        var fixture = new RegistryFixture(OrganizationRole.Administrator);

        var action = () => fixture.Members.RemoveAsync(
            Guid.NewGuid(),
            CancellationToken.None);

        await action.Should().ThrowAsync<ResourceNotFoundException>();
    }
}
