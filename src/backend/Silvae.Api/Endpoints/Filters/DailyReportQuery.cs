using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Domain.DailyReports;

namespace Silvae.Api.Endpoints.Filters;

/// <summary>
/// I filtri dell'elenco d'ufficio, come arrivano dalla query string. Restano
/// qui e non nell'applicazione perché sono una forma HTTP: il servizio riceve
/// un filtro già tipizzato.
/// </summary>
public sealed record DailyReportQuery(
    Guid? JobOrderId,
    Guid? WorksiteId,
    Guid? CrewUserId,
    DateOnly? From,
    DateOnly? To,
    string? Status)
{
    public DailyReportFilter ToFilter()
    {
        DailyReportStatus? status = null;
        if (!string.IsNullOrWhiteSpace(Status))
        {
            status = Enum.TryParse<DailyReportStatus>(Status, ignoreCase: true, out var parsed)
                ? parsed
                : throw new RegistryValidationException(
                    "Lo stato deve essere Draft, Submitted, Approved o Reopened.");
        }

        if (From is not null && To is not null && To < From)
        {
            throw new RegistryValidationException(
                "La data finale non può precedere quella iniziale.");
        }

        return new DailyReportFilter(
            JobOrderId,
            WorksiteId,
            CrewUserId,
            From,
            To,
            status);
    }
}
