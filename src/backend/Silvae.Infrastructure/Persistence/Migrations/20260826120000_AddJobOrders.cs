using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Silvae.Infrastructure.Persistence.Migrations;

[DbContext(typeof(SilvaeDbContext))]
[Migration("20260826120000_AddJobOrders")]
public sealed class AddJobOrders : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "job_orders",
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
                Customer = table.Column<string>(
                    type: "character varying(200)",
                    maxLength: 200,
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
                table.PrimaryKey("PK_job_orders", item => item.Id);
                table.ForeignKey(
                    name: "FK_job_orders_organizations_OrganizationId",
                    column: item => item.OrganizationId,
                    principalTable: "organizations",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.AddColumn<Guid>(
            name: "JobOrderId",
            table: "worksites",
            type: "uuid",
            nullable: true);

        migrationBuilder.CreateIndex(
            name: "IX_job_orders_OrganizationId_Code",
            table: "job_orders",
            columns: ["OrganizationId", "Code"],
            unique: true);
        migrationBuilder.CreateIndex(
            name: "IX_worksites_JobOrderId",
            table: "worksites",
            column: "JobOrderId");

        migrationBuilder.AddForeignKey(
            name: "FK_worksites_job_orders_JobOrderId",
            table: "worksites",
            column: "JobOrderId",
            principalTable: "job_orders",
            principalColumn: "Id",
            onDelete: ReferentialAction.SetNull);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropForeignKey(
            name: "FK_worksites_job_orders_JobOrderId",
            table: "worksites");
        migrationBuilder.DropIndex(
            name: "IX_worksites_JobOrderId",
            table: "worksites");
        migrationBuilder.DropColumn(name: "JobOrderId", table: "worksites");
        migrationBuilder.DropTable(name: "job_orders");
    }
}
