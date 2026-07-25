namespace Silvae.Application.Common;

public abstract class SilvaeApplicationException(string message) : Exception(message);

public sealed class AuthenticationRequiredException()
    : SilvaeApplicationException("Autenticazione richiesta.");

public sealed class OrganizationAccessDeniedException()
    : SilvaeApplicationException("L'utente non appartiene all'organizzazione selezionata.");

public sealed class ResourceAccessDeniedException(string message)
    : SilvaeApplicationException(message);

public sealed class SyncValidationException(string message)
    : SilvaeApplicationException(message);

public sealed class SyncConflictException(long currentVersion)
    : SilvaeApplicationException("La versione locale non coincide con quella sul server.")
{
    public long CurrentVersion { get; } = currentVersion;
}
