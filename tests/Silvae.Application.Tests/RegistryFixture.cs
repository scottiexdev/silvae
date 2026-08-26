using Silvae.Application.Identity;
using Silvae.Application.JobOrders;
using Silvae.Application.Organizations;
using Silvae.Application.Worksites;
using Silvae.Domain.Organizations;

namespace Silvae.Application.Tests;

/// <summary>
/// Organizzazione già esistente con chi chiama e un operatore. Il ruolo di chi
/// chiama è il parametro che conta: l'anagrafica è scrivibile solo da alcuni.
/// </summary>
internal sealed class RegistryFixture
{
    public RegistryFixture(OrganizationRole callerRole)
    {
        Store = new InMemorySilvaeStore();
        Store.Organizations.Add(new Organization(OrganizationId, "Cooperativa Verde"));
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

        var requestContext = ContextFor(CallerId);
        var currentUser = new CurrentUserService(requestContext, Store);
        JobOrders = new JobOrderService(Store, currentUser);
        Worksites = new WorksiteService(requestContext, Store, currentUser);
        Members = new MembershipService(Store, currentUser);
    }

    public static Guid OrganizationId { get; } = Guid.NewGuid();

    public static Guid CallerId { get; } = Guid.NewGuid();

    public static Guid WorkerId { get; } = Guid.NewGuid();

    public InMemorySilvaeStore Store { get; }

    public JobOrderService JobOrders { get; }

    public WorksiteService Worksites { get; }

    public MembershipService Members { get; }

    /// <summary>
    /// Gli stessi dati visti da un'altra persona: serve a controllare che
    /// l'operatore veda solo i cantieri che gli sono stati assegnati.
    /// </summary>
    public WorksiteService WorksitesSeenBy(Guid userId)
    {
        var requestContext = ContextFor(userId);
        return new WorksiteService(
            requestContext,
            Store,
            new CurrentUserService(requestContext, Store));
    }

    private static TestRequestContext ContextFor(Guid userId)
    {
        return new TestRequestContext
        {
            UserId = userId,
            SelectedOrganizationId = OrganizationId,
        };
    }
}
