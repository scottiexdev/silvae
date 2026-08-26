using Microsoft.EntityFrameworkCore;
using Silvae.Domain.JobOrders;
using Silvae.Domain.Organizations;
using Silvae.Domain.Worksites;

namespace Silvae.Infrastructure.Persistence;

/// <summary>
/// Popola un database vuoto con il minimo necessario a provare l'app dal vivo.
/// Serve perché l'API non espone ancora endpoint di scrittura per organizzazioni,
/// commesse e cantieri: senza questi dati la schermata dei rapportini resta
/// inutilizzabile.
/// </summary>
public static class DevelopmentSeed
{
    /// <summary>
    /// Identificativo fisso, così può essere scritto una volta nella
    /// configurazione del client come `SILVAE_ORGANIZATION_ID`.
    /// </summary>
    public static readonly Guid OrganizationId =
        Guid.Parse("5117ae00-0000-4000-8000-000000000001");

    private static readonly Guid JobOrderId =
        Guid.Parse("5117ae00-0000-4000-8000-000000000002");

    private static readonly Guid FirstWorksiteId =
        Guid.Parse("5117ae00-0000-4000-8000-000000000003");

    private static readonly Guid SecondWorksiteId =
        Guid.Parse("5117ae00-0000-4000-8000-000000000004");

    /// <summary>
    /// Inserisce i dati solo se l'organizzazione di prova non esiste già, così
    /// riavviare l'API non duplica nulla e non sovrascrive le modifiche fatte
    /// durante la prova precedente.
    /// </summary>
    /// <returns>true se i dati sono stati inseriti adesso.</returns>
    public static async Task<bool> ApplyAsync(
        SilvaeDbContext dbContext,
        Guid userId,
        string displayName,
        CancellationToken cancellationToken)
    {
        if (userId == Guid.Empty)
        {
            throw new ArgumentException("L'utente è obbligatorio.", nameof(userId));
        }

        var alreadySeeded = await dbContext.Organizations.AnyAsync(
            item => item.Id == OrganizationId,
            cancellationToken);
        if (alreadySeeded)
        {
            return false;
        }

        dbContext.Organizations.Add(
            new Organization(OrganizationId, "Cooperativa di prova"));
        dbContext.UserMemberships.Add(
            new UserMembership(
                OrganizationId,
                userId,
                OrganizationRole.Administrator,
                displayName));
        dbContext.JobOrders.Add(
            new JobOrder(
                JobOrderId,
                OrganizationId,
                "C-2026-001",
                "Manutenzione verde comunale",
                "Comune di prova"));

        foreach (var (id, code, name) in new[]
        {
            (FirstWorksiteId, "CN-01", "Parco nord"),
            (SecondWorksiteId, "CN-02", "Argine del torrente"),
        })
        {
            var worksite = new Worksite(id, OrganizationId, code, name);
            worksite.AssignToJobOrder(JobOrderId);
            worksite.Assign(userId);
            dbContext.Worksites.Add(worksite);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }
}
