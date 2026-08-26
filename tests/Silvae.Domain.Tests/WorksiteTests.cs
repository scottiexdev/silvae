using FluentAssertions;
using Silvae.Domain.Worksites;

namespace Silvae.Domain.Tests;

public sealed class WorksiteTests
{
    [Fact]
    public void AWorksiteRequiresItsIdentifiers()
    {
        var action = () => new Worksite(
            Guid.Empty,
            Guid.NewGuid(),
            "W-001",
            "Parco nord");

        action.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void AssigningTheSamePersonTwiceLeavesOneAssignment()
    {
        var worksite = CreateWorksite();
        var userId = Guid.NewGuid();

        worksite.Assign(userId);
        var afterFirst = worksite.Version;
        worksite.Assign(userId);

        worksite.Assignments.Should().ContainSingle();
        worksite.Version.Should().Be(afterFirst);
    }

    [Fact]
    public void AssigningSomeoneChangesWhoSeesTheWorksiteAndSoTheVersion()
    {
        var worksite = CreateWorksite();
        var before = worksite.Version;

        worksite.Assign(Guid.NewGuid());

        worksite.Version.Should().BeGreaterThan(before);
    }

    [Fact]
    public void UnassigningSomeoneWhoWasNeverThereChangesNothing()
    {
        var worksite = CreateWorksite();
        var before = worksite.Version;

        worksite.Unassign(Guid.NewGuid());

        worksite.Version.Should().Be(before);
        worksite.Assignments.Should().BeEmpty();
    }

    [Fact]
    public void ClosingAnAlreadyClosedWorksiteChangesNothing()
    {
        var worksite = CreateWorksite();
        worksite.Close();
        var afterClose = worksite.Version;

        worksite.Close();

        worksite.IsActive.Should().BeFalse();
        worksite.Version.Should().Be(afterClose);
    }

    [Fact]
    public void AClosedWorksiteCanBeReopened()
    {
        var worksite = CreateWorksite();
        worksite.Close();

        worksite.Reopen();

        worksite.IsActive.Should().BeTrue();
    }

    [Fact]
    public void TheJobOrderCanBeDetachedButNotSetToAnEmptyIdentifier()
    {
        var worksite = CreateWorksite();
        worksite.AssignToJobOrder(Guid.NewGuid());

        var action = () => worksite.AssignToJobOrder(Guid.Empty);

        action.Should().Throw<ArgumentException>();
        worksite.AssignToJobOrder(null);
        worksite.JobOrderId.Should().BeNull();
    }

    [Fact]
    public void RenamingTrimsTheName()
    {
        var worksite = CreateWorksite();

        worksite.Rename("  Parco sud  ");

        worksite.Name.Should().Be("Parco sud");
    }

    private static Worksite CreateWorksite()
    {
        return new Worksite(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "W-001",
            "Parco nord");
    }
}
