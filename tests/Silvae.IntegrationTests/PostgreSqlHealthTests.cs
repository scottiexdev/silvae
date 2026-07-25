using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Silvae.Infrastructure.Persistence;
using Testcontainers.PostgreSql;

namespace Silvae.IntegrationTests;

public sealed class PostgreSqlHealthTests
{
    [Fact]
    public async Task DbContextConnectsToPostgreSql()
    {
        if (!DockerIsAvailable())
        {
            return;
        }

        await using var postgres = new PostgreSqlBuilder()
            .WithImage("postgres:17-alpine")
            .WithDatabase("silvae")
            .WithUsername("postgres")
            .WithPassword("postgres")
            .Build();
        await postgres.StartAsync();

        var options = new DbContextOptionsBuilder<SilvaeDbContext>()
            .UseNpgsql(postgres.GetConnectionString())
            .Options;
        await using var dbContext = new SilvaeDbContext(options);
        await dbContext.Database.MigrateAsync();

        (await dbContext.Database.CanConnectAsync()).Should().BeTrue();
    }

    private static bool DockerIsAvailable()
    {
        return File.Exists("/var/run/docker.sock") ||
            !string.IsNullOrWhiteSpace(
                Environment.GetEnvironmentVariable("DOCKER_HOST"));
    }
}
