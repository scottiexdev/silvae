using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;
using Silvae.Application.Abstractions;

namespace Silvae.Infrastructure.Configuration;

/// <summary>
/// Legge il segreto di bootstrap da SILVAE_BOOTSTRAP_SECRET. Non configurarlo
/// disattiva l'endpoint: è la condizione normale di un ambiente già
/// inizializzato.
/// </summary>
public sealed class ConfigurationBootstrapSecret : IBootstrapSecret
{
    private readonly byte[]? _secret;

    public ConfigurationBootstrapSecret(IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        var value = configuration["SILVAE_BOOTSTRAP_SECRET"];
        _secret = string.IsNullOrWhiteSpace(value)
            ? null
            : Encoding.UTF8.GetBytes(value);
    }

    public bool IsConfigured => _secret is not null;

    public bool Matches(string? candidate)
    {
        if (_secret is null || string.IsNullOrEmpty(candidate))
        {
            return false;
        }

        // Il confronto a tempo costante evita che i tentativi raccontino da soli
        // quanti caratteri iniziali sono corretti.
        return CryptographicOperations.FixedTimeEquals(
            _secret,
            Encoding.UTF8.GetBytes(candidate));
    }
}
