using System.Globalization;

namespace Silvae.Application.Common;

/// <summary>
/// I codici di commesse e cantieri sono unici nell'organizzazione. Il confronto
/// avviene sul valore memorizzato, quindi la normalizzazione deve avvenire una
/// volta sola, qui: senza, `C-001` e `c-001` diventerebbero due codici diversi.
/// </summary>
public static class RegistryCode
{
    public static string Normalize(string? code, string subject)
    {
        var value = code?.Trim();
        if (string.IsNullOrEmpty(value))
        {
            throw new RegistryValidationException(
                string.Create(
                    CultureInfo.InvariantCulture,
                    $"Il codice {subject} è obbligatorio."));
        }

        if (value.Length > 64)
        {
            throw new RegistryValidationException(
                string.Create(
                    CultureInfo.InvariantCulture,
                    $"Il codice {subject} non può superare 64 caratteri."));
        }

        return value.ToUpperInvariant();
    }
}
