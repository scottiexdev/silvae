using FluentAssertions;
using Silvae.Application.Common;
using Silvae.Application.Identity;
using Silvae.Application.People;
using Silvae.Domain.DailyReports;
using Silvae.Domain.Organizations;
using Silvae.Domain.Worksites;

namespace Silvae.Application.Tests;

public sealed class CertificationServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 29, 9, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task AnExpiredCertificationIsStillValidOnTheDayItCovered()
    {
        var fixture = new Fixture(OrganizationRole.Coordinator);
        await fixture.AddCertificationAsync(
            validFrom: new DateOnly(2023, 1, 10),
            expiresOn: new DateOnly(2026, 1, 9));
        fixture.AddReport(new DateOnly(2025, 12, 15));

        var inspection = await fixture.Service.GetInspectionAsync(
            worksiteId: null,
            new DateOnly(2025, 12, 1),
            new DateOnly(2025, 12, 31),
            CancellationToken.None);

        inspection.Should().ContainSingle();
        inspection[0].Crew.Should().ContainSingle()
            .Which.Certifications.Should().ContainSingle()
            .Which.Kind.Should().Be("Patentino motosega");
    }

    [Fact]
    public async Task ACertificationNotYetIssuedDoesNotCoverAnEarlierDay()
    {
        var fixture = new Fixture(OrganizationRole.Coordinator);
        await fixture.AddCertificationAsync(
            validFrom: new DateOnly(2026, 3, 1),
            expiresOn: null);
        fixture.AddReport(new DateOnly(2026, 2, 20));

        var inspection = await fixture.Service.GetInspectionAsync(
            worksiteId: null,
            new DateOnly(2026, 2, 1),
            new DateOnly(2026, 2, 28),
            CancellationToken.None);

        inspection.Should().ContainSingle();
        inspection[0].Crew.Single().Certifications.Should().BeEmpty();
    }

    [Fact]
    public async Task TheExpiryWindowIncludesWhatHasAlreadyExpired()
    {
        var fixture = new Fixture(OrganizationRole.Coordinator);
        await fixture.AddCertificationAsync(
            validFrom: new DateOnly(2020, 1, 1),
            expiresOn: new DateOnly(2026, 6, 30));
        await fixture.AddCertificationAsync(
            validFrom: new DateOnly(2026, 1, 1),
            expiresOn: new DateOnly(2027, 12, 31),
            kind: "Abilitazione trattore");

        var expiring = await fixture.Service.GetExpiringAsync(
            withinDays: 60,
            CancellationToken.None);

        expiring.Should().ContainSingle();
        expiring[0].IsValidToday.Should().BeFalse();
        expiring[0].DaysToExpiry.Should().BeNegative();
    }

    [Fact]
    public async Task AnOperatorCannotReadTheCertificationsOfTheOrganization()
    {
        var fixture = new Fixture(OrganizationRole.Worker);

        var action = () => fixture.Service.GetAllAsync(
            userId: null,
            validOn: null,
            CancellationToken.None);

        await action.Should().ThrowAsync<ResourceAccessDeniedException>();
    }

    [Fact]
    public async Task ACertificationExpiringBeforeItStartsIsRejected()
    {
        var fixture = new Fixture(OrganizationRole.Coordinator);

        var action = () => fixture.Service.CreateAsync(
            new UpsertCertificationRequest(
                Fixture.WorkerId,
                "Corso DPI",
                new DateOnly(2026, 5, 1),
                new DateOnly(2026, 4, 1),
                "Ente formatore",
                null,
                null),
            CancellationToken.None);

        await action.Should().ThrowAsync<ArgumentException>();
    }

    private sealed class Fixture
    {
        public Fixture(OrganizationRole callerRole)
        {
            Store = new InMemorySilvaeStore();
            Store.Organizations.Add(
                new Organization(OrganizationId, "Cooperativa Verde"));
            Store.Memberships.Add(new UserMembership(
                OrganizationId,
                CallerId,
                callerRole,
                "Chi chiama"));
            Store.Memberships.Add(new UserMembership(
                OrganizationId,
                WorkerId,
                OrganizationRole.Worker,
                "Mario Rossi"));

            var worksite = new Worksite(
                WorksiteId,
                OrganizationId,
                "W-001",
                "Bosco alto");
            worksite.Assign(WorkerId);
            Store.Worksites.Add(worksite);

            var requestContext = new TestRequestContext
            {
                UserId = CallerId,
                SelectedOrganizationId = OrganizationId,
            };
            Service = new CertificationService(
                Store,
                new CurrentUserService(requestContext, Store),
                new FixedTimeProvider(Now));
        }

        public static Guid OrganizationId { get; } = Guid.NewGuid();

        public static Guid CallerId { get; } = Guid.NewGuid();

        public static Guid WorkerId { get; } = Guid.NewGuid();

        public static Guid WorksiteId { get; } = Guid.NewGuid();

        public InMemorySilvaeStore Store { get; }

        public CertificationService Service { get; }

        public Task<CertificationDto> AddCertificationAsync(
            DateOnly validFrom,
            DateOnly? expiresOn,
            string kind = "Patentino motosega")
        {
            return Service.CreateAsync(
                new UpsertCertificationRequest(
                    WorkerId,
                    kind,
                    validFrom,
                    expiresOn,
                    "Ente formatore",
                    null,
                    null),
                CancellationToken.None);
        }

        public void AddReport(DateOnly reportDate)
        {
            Store.Reports.Add(DailyReport.Create(
                Guid.NewGuid(),
                OrganizationId,
                WorkerId,
                new DailyReportContent(
                    WorksiteId,
                    reportDate,
                    null,
                    [new CrewEntry(WorkerId, 8m, null)],
                    [],
                    [],
                    []),
                Now));
        }
    }

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
