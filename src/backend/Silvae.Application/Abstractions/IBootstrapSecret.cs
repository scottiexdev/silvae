namespace Silvae.Application.Abstractions;

/// <summary>
/// Segreto di deploy che autorizza la creazione della prima organizzazione.
/// Serve perché un utente appena registrato non appartiene ad alcuna
/// organizzazione e non può quindi essere amministratore di nulla: senza una
/// chiave fuori dal modello dei ruoli, il primo amministratore non esiste.
/// </summary>
public interface IBootstrapSecret
{
    bool IsConfigured { get; }

    bool Matches(string? candidate);
}
