using FluentAssertions;
using Silvae.Domain.JobOrders;
using Silvae.Domain.Worksites;

namespace Silvae.Domain.Tests;

public sealed class JobOrderTests
{
    private static readonly Guid OrganizationId = Guid.NewGuid();

    [Fact]
    public void A_job_order_normalizes_text_and_starts_active()
    {
        var jobOrder = new JobOrder(
            Guid.NewGuid(),
            OrganizationId,
            "  C-2026-014  ",
            "  Manutenzione argini  ",
            "  Consorzio di bonifica  ");

        jobOrder.Code.Should().Be("C-2026-014");
        jobOrder.Name.Should().Be("Manutenzione argini");
        jobOrder.Customer.Should().Be("Consorzio di bonifica");
        jobOrder.IsActive.Should().BeTrue();
        jobOrder.Version.Should().Be(1);
    }

    [Fact]
    public void A_blank_customer_becomes_null()
    {
        var jobOrder = new JobOrder(
            Guid.NewGuid(),
            OrganizationId,
            "C-2026-015",
            "Sfalcio scarpate",
            "   ");

        jobOrder.Customer.Should().BeNull();
    }

    [Fact]
    public void Closing_a_job_order_twice_bumps_the_version_once()
    {
        var jobOrder = new JobOrder(
            Guid.NewGuid(),
            OrganizationId,
            "C-2026-016",
            "Abbattimenti");

        jobOrder.Close();
        jobOrder.Close();

        jobOrder.IsActive.Should().BeFalse();
        jobOrder.Version.Should().Be(2);
    }

    [Fact]
    public void A_worksite_starts_without_a_job_order_and_can_be_attached()
    {
        var worksite = new Worksite(
            Guid.NewGuid(),
            OrganizationId,
            "CN-01",
            "Argine nord");
        var jobOrderId = Guid.NewGuid();

        worksite.JobOrderId.Should().BeNull();

        worksite.AssignToJobOrder(jobOrderId);

        worksite.JobOrderId.Should().Be(jobOrderId);
    }

    [Fact]
    public void An_empty_job_order_id_is_rejected()
    {
        var worksite = new Worksite(
            Guid.NewGuid(),
            OrganizationId,
            "CN-02",
            "Argine sud");

        var attach = () => worksite.AssignToJobOrder(Guid.Empty);

        attach.Should().Throw<ArgumentException>();
    }
}
