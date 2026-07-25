using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Silvae.Infrastructure.Persistence.Migrations;

[DbContext(typeof(SilvaeDbContext))]
[Migration("20260725120000_InitialCreate")]
public sealed class InitialCreate : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "organizations",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                Name = table.Column<string>(
                    type: "character varying(200)",
                    maxLength: 200,
                    nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_organizations", item => item.Id);
            });

        migrationBuilder.CreateTable(
            name: "user_memberships",
            columns: table => new
            {
                OrganizationId = table.Column<Guid>(
                    type: "uuid",
                    nullable: false),
                UserId = table.Column<Guid>(type: "uuid", nullable: false),
                Role = table.Column<string>(
                    type: "character varying(32)",
                    maxLength: 32,
                    nullable: false),
                DisplayName = table.Column<string>(
                    type: "character varying(200)",
                    maxLength: 200,
                    nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey(
                    "PK_user_memberships",
                    item => new { item.OrganizationId, item.UserId });
                table.ForeignKey(
                    name: "FK_user_memberships_organizations_OrganizationId",
                    column: item => item.OrganizationId,
                    principalTable: "organizations",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "worksites",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                OrganizationId = table.Column<Guid>(
                    type: "uuid",
                    nullable: false),
                Code = table.Column<string>(
                    type: "character varying(64)",
                    maxLength: 64,
                    nullable: false),
                Name = table.Column<string>(
                    type: "character varying(200)",
                    maxLength: 200,
                    nullable: false),
                Address = table.Column<string>(
                    type: "character varying(500)",
                    maxLength: 500,
                    nullable: true),
                IsActive = table.Column<bool>(
                    type: "boolean",
                    nullable: false),
                Version = table.Column<long>(type: "bigint", nullable: false),
                UpdatedAt = table.Column<DateTimeOffset>(
                    type: "timestamp with time zone",
                    nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_worksites", item => item.Id);
                table.ForeignKey(
                    name: "FK_worksites_organizations_OrganizationId",
                    column: item => item.OrganizationId,
                    principalTable: "organizations",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "daily_reports",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                OrganizationId = table.Column<Guid>(
                    type: "uuid",
                    nullable: false),
                WorksiteId = table.Column<Guid>(
                    type: "uuid",
                    nullable: false),
                AuthorId = table.Column<Guid>(type: "uuid", nullable: false),
                ReportDate = table.Column<DateOnly>(type: "date", nullable: false),
                Notes = table.Column<string>(
                    type: "character varying(4000)",
                    maxLength: 4000,
                    nullable: true),
                Status = table.Column<string>(
                    type: "character varying(32)",
                    maxLength: 32,
                    nullable: false),
                Version = table.Column<long>(type: "bigint", nullable: false),
                CreatedAt = table.Column<DateTimeOffset>(
                    type: "timestamp with time zone",
                    nullable: false),
                UpdatedAt = table.Column<DateTimeOffset>(
                    type: "timestamp with time zone",
                    nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_daily_reports", item => item.Id);
                table.ForeignKey(
                    name: "FK_daily_reports_organizations_OrganizationId",
                    column: item => item.OrganizationId,
                    principalTable: "organizations",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_daily_reports_worksites_WorksiteId",
                    column: item => item.WorksiteId,
                    principalTable: "worksites",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "processed_sync_operations",
            columns: table => new
            {
                OrganizationId = table.Column<Guid>(
                    type: "uuid",
                    nullable: false),
                OperationId = table.Column<Guid>(
                    type: "uuid",
                    nullable: false),
                EntityId = table.Column<Guid>(type: "uuid", nullable: false),
                EntityVersion = table.Column<long>(
                    type: "bigint",
                    nullable: false),
                ProcessedAt = table.Column<DateTimeOffset>(
                    type: "timestamp with time zone",
                    nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey(
                    "PK_processed_sync_operations",
                    item => new { item.OrganizationId, item.OperationId });
                table.ForeignKey(
                    name: "FK_processed_sync_operations_organizations_OrganizationId",
                    column: item => item.OrganizationId,
                    principalTable: "organizations",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "worksite_assignments",
            columns: table => new
            {
                WorksiteId = table.Column<Guid>(
                    type: "uuid",
                    nullable: false),
                UserId = table.Column<Guid>(type: "uuid", nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey(
                    "PK_worksite_assignments",
                    item => new { item.WorksiteId, item.UserId });
                table.ForeignKey(
                    name: "FK_worksite_assignments_worksites_WorksiteId",
                    column: item => item.WorksiteId,
                    principalTable: "worksites",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_daily_reports_OrganizationId_UpdatedAt",
            table: "daily_reports",
            columns: ["OrganizationId", "UpdatedAt"]);
        migrationBuilder.CreateIndex(
            name: "IX_daily_reports_WorksiteId",
            table: "daily_reports",
            column: "WorksiteId");
        migrationBuilder.CreateIndex(
            name: "IX_processed_sync_operations_ProcessedAt",
            table: "processed_sync_operations",
            column: "ProcessedAt");
        migrationBuilder.CreateIndex(
            name: "IX_worksite_assignments_UserId",
            table: "worksite_assignments",
            column: "UserId");
        migrationBuilder.CreateIndex(
            name: "IX_worksites_OrganizationId_Code",
            table: "worksites",
            columns: ["OrganizationId", "Code"],
            unique: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "daily_reports");
        migrationBuilder.DropTable(name: "processed_sync_operations");
        migrationBuilder.DropTable(name: "user_memberships");
        migrationBuilder.DropTable(name: "worksite_assignments");
        migrationBuilder.DropTable(name: "worksites");
        migrationBuilder.DropTable(name: "organizations");
    }
}
