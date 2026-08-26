using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Silvae.Infrastructure.Persistence;

namespace Silvae.IntegrationTests;

public sealed class DevelopmentSeedTests
{
    private static readonly Guid UserId =
        Guid.Parse("0a5d4f3e-2b1c-4d5e-8f60-71a2b3c4d5e6");

    [Fact]
    public async Task SeedingGivesTheUserAnAssignedWorksite()
    {
        await using var dbContext = NewContext(nameof(SeedingGivesTheUserAnAssignedWorksite));

        var seeded = await DevelopmentSeed.ApplyAsync(
            dbContext,
            UserId,
            "Operatore di prova",
            CancellationToken.None);

        seeded.Should().BeTrue();
        var membership = await dbContext.UserMemberships.SingleAsync();
        membership.UserId.Should().Be(UserId);
        membership.OrganizationId.Should().Be(DevelopmentSeed.OrganizationId);

        var worksites = await dbContext.Worksites
            .Include(item => item.Assignments)
            .ToListAsync();
        worksites.Should().HaveCount(2);
        worksites.Should().OnlyContain(item => item.JobOrderId != null);
        worksites.Should().OnlyContain(
            item => item.Assignments.Any(assignment => assignment.UserId == UserId));
    }

    [Fact]
    public async Task SeedingTwiceDoesNotDuplicateAnything()
    {
        await using var dbContext = NewContext(nameof(SeedingTwiceDoesNotDuplicateAnything));

        await DevelopmentSeed.ApplyAsync(
            dbContext,
            UserId,
            "Operatore di prova",
            CancellationToken.None);
        var seededAgain = await DevelopmentSeed.ApplyAsync(
            dbContext,
            UserId,
            "Operatore di prova",
            CancellationToken.None);

        seededAgain.Should().BeFalse();
        (await dbContext.Worksites.CountAsync()).Should().Be(2);
        (await dbContext.Organizations.CountAsync()).Should().Be(1);
    }

    private static SilvaeDbContext NewContext(string name)
    {
        var options = new DbContextOptionsBuilder<SilvaeDbContext>()
            .UseInMemoryDatabase(name)
            .Options;
        return new SilvaeDbContext(options);
    }
}
