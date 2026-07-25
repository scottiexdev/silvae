using Microsoft.EntityFrameworkCore;
using Silvae.Domain.DailyReports;
using Silvae.Domain.Organizations;
using Silvae.Domain.Worksites;

namespace Silvae.Infrastructure.Persistence;

public sealed class SilvaeDbContext(DbContextOptions<SilvaeDbContext> options)
    : DbContext(options)
{
    public DbSet<Organization> Organizations => Set<Organization>();

    public DbSet<UserMembership> UserMemberships => Set<UserMembership>();

    public DbSet<Worksite> Worksites => Set<Worksite>();

    public DbSet<WorksiteAssignment> WorksiteAssignments =>
        Set<WorksiteAssignment>();

    public DbSet<DailyReport> DailyReports => Set<DailyReport>();

    public DbSet<ProcessedSyncOperationEntity> ProcessedSyncOperations =>
        Set<ProcessedSyncOperationEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Organization>(entity =>
        {
            entity.ToTable("organizations");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Name).HasMaxLength(200);
        });

        modelBuilder.Entity<UserMembership>(entity =>
        {
            entity.ToTable("user_memberships");
            entity.HasKey(item => new { item.OrganizationId, item.UserId });
            entity.Property(item => item.Role).HasConversion<string>().HasMaxLength(32);
            entity.Property(item => item.DisplayName).HasMaxLength(200);
            entity.HasOne<Organization>()
                .WithMany()
                .HasForeignKey(item => item.OrganizationId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Worksite>(entity =>
        {
            entity.ToTable("worksites");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Code).HasMaxLength(64);
            entity.Property(item => item.Name).HasMaxLength(200);
            entity.Property(item => item.Address).HasMaxLength(500);
            entity.HasIndex(item => new { item.OrganizationId, item.Code }).IsUnique();
            entity.HasOne<Organization>()
                .WithMany()
                .HasForeignKey(item => item.OrganizationId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(item => item.Assignments)
                .WithOne()
                .HasForeignKey(item => item.WorksiteId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.Navigation(item => item.Assignments)
                .UsePropertyAccessMode(PropertyAccessMode.Field);
        });

        modelBuilder.Entity<WorksiteAssignment>(entity =>
        {
            entity.ToTable("worksite_assignments");
            entity.HasKey(item => new { item.WorksiteId, item.UserId });
            entity.HasIndex(item => item.UserId);
        });

        modelBuilder.Entity<DailyReport>(entity =>
        {
            entity.ToTable("daily_reports");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Notes).HasMaxLength(4000);
            entity.Property(item => item.Status).HasConversion<string>().HasMaxLength(32);
            entity.HasIndex(item => new
            {
                item.OrganizationId,
                item.UpdatedAt,
            });
            entity.HasOne<Organization>()
                .WithMany()
                .HasForeignKey(item => item.OrganizationId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<Worksite>()
                .WithMany()
                .HasForeignKey(item => item.WorksiteId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ProcessedSyncOperationEntity>(entity =>
        {
            entity.ToTable("processed_sync_operations");
            entity.HasKey(item => new { item.OrganizationId, item.OperationId });
            entity.HasIndex(item => item.ProcessedAt);
            entity.HasOne<Organization>()
                .WithMany()
                .HasForeignKey(item => item.OrganizationId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}

public sealed class ProcessedSyncOperationEntity
{
    public Guid OrganizationId { get; set; }

    public Guid OperationId { get; set; }

    public Guid EntityId { get; set; }

    public long EntityVersion { get; set; }

    public DateTimeOffset ProcessedAt { get; set; }
}
