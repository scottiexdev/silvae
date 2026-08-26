using Microsoft.EntityFrameworkCore;
using Silvae.Domain.DailyReports;
using Silvae.Domain.JobOrders;
using Silvae.Domain.Organizations;
using Silvae.Domain.Worksites;

namespace Silvae.Infrastructure.Persistence;

public sealed class SilvaeDbContext(DbContextOptions<SilvaeDbContext> options)
    : DbContext(options)
{
    public DbSet<Organization> Organizations => Set<Organization>();

    public DbSet<UserMembership> UserMemberships => Set<UserMembership>();

    public DbSet<JobOrder> JobOrders => Set<JobOrder>();

    public DbSet<Worksite> Worksites => Set<Worksite>();

    public DbSet<WorksiteAssignment> WorksiteAssignments =>
        Set<WorksiteAssignment>();

    public DbSet<DailyReport> DailyReports => Set<DailyReport>();

    public DbSet<DailyReportCrewMember> DailyReportCrew =>
        Set<DailyReportCrewMember>();

    public DbSet<DailyReportActivity> DailyReportActivities =>
        Set<DailyReportActivity>();

    public DbSet<DailyReportSafetyCheck> DailyReportSafetyChecks =>
        Set<DailyReportSafetyCheck>();

    public DbSet<DailyReportAuditEntry> DailyReportAudit =>
        Set<DailyReportAuditEntry>();

    public DbSet<ProcessedSyncOperationEntity> ProcessedSyncOperations =>
        Set<ProcessedSyncOperationEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Organization>(entity =>
        {
            entity.ToTable("organizations");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Id).ValueGeneratedNever();
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

        modelBuilder.Entity<JobOrder>(entity =>
        {
            entity.ToTable("job_orders");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Id).ValueGeneratedNever();
            entity.Property(item => item.Code).HasMaxLength(64);
            entity.Property(item => item.Name).HasMaxLength(200);
            entity.Property(item => item.Customer).HasMaxLength(200);
            entity.HasIndex(item => new { item.OrganizationId, item.Code }).IsUnique();
            entity.HasOne<Organization>()
                .WithMany()
                .HasForeignKey(item => item.OrganizationId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Worksite>(entity =>
        {
            entity.ToTable("worksites");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Id).ValueGeneratedNever();
            entity.Property(item => item.Code).HasMaxLength(64);
            entity.Property(item => item.Name).HasMaxLength(200);
            entity.Property(item => item.Address).HasMaxLength(500);
            entity.HasIndex(item => new { item.OrganizationId, item.Code }).IsUnique();
            entity.HasIndex(item => item.JobOrderId);
            entity.HasOne<Organization>()
                .WithMany()
                .HasForeignKey(item => item.OrganizationId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<JobOrder>()
                .WithMany()
                .HasForeignKey(item => item.JobOrderId)
                .OnDelete(DeleteBehavior.SetNull);
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
            entity.Property(item => item.Id).ValueGeneratedNever();
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
            entity.HasMany(item => item.Crew)
                .WithOne()
                .HasForeignKey(item => item.DailyReportId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(item => item.Activities)
                .WithOne()
                .HasForeignKey(item => item.DailyReportId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(item => item.SafetyChecks)
                .WithOne()
                .HasForeignKey(item => item.DailyReportId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(item => item.Audit)
                .WithOne()
                .HasForeignKey(item => item.DailyReportId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.Navigation(item => item.Crew)
                .UsePropertyAccessMode(PropertyAccessMode.Field);
            entity.Navigation(item => item.Activities)
                .UsePropertyAccessMode(PropertyAccessMode.Field);
            entity.Navigation(item => item.SafetyChecks)
                .UsePropertyAccessMode(PropertyAccessMode.Field);
            entity.Navigation(item => item.Audit)
                .UsePropertyAccessMode(PropertyAccessMode.Field);
        });

        modelBuilder.Entity<DailyReportCrewMember>(entity =>
        {
            entity.ToTable("daily_report_crew");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Id).ValueGeneratedNever();
            entity.Property(item => item.Hours).HasPrecision(5, 2);
            entity.Property(item => item.Note).HasMaxLength(500);
            entity.HasIndex(item => item.DailyReportId);
            entity.HasIndex(item => item.UserId);
        });

        modelBuilder.Entity<DailyReportActivity>(entity =>
        {
            entity.ToTable("daily_report_activities");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Id).ValueGeneratedNever();
            entity.Property(item => item.Description).HasMaxLength(500);
            entity.Property(item => item.Quantity).HasPrecision(12, 2);
            entity.Property(item => item.Unit).HasMaxLength(16);
            entity.HasIndex(item => item.DailyReportId);
        });

        modelBuilder.Entity<DailyReportSafetyCheck>(entity =>
        {
            entity.ToTable("daily_report_safety_checks");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Id).ValueGeneratedNever();
            entity.Property(item => item.Code).HasMaxLength(64);
            entity.Property(item => item.Note).HasMaxLength(500);
            entity.HasIndex(item => item.DailyReportId);
        });

        modelBuilder.Entity<DailyReportAuditEntry>(entity =>
        {
            entity.ToTable("daily_report_audit");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Id).ValueGeneratedNever();
            entity.Property(item => item.Action).HasConversion<string>().HasMaxLength(32);
            entity.HasIndex(item => new { item.DailyReportId, item.OccurredAt });
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
