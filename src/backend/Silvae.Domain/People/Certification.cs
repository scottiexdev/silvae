namespace Silvae.Domain.People;

/// <summary>
/// Abilitazione di una persona: patentino motosega, abilitazione trattore,
/// corso DPI e sicurezza.
///
/// La validità è un intervallo, non uno stato corrente. Un'ispezione su lavori
/// di otto mesi fa chiede se l'operatore era abilitato in quella data: uno
/// schema che tenesse soltanto la scadenza risponderebbe alla domanda
/// sbagliata.
/// </summary>
public sealed class Certification
{
    private Certification()
    {
    }

    public Certification(
        Guid id,
        Guid organizationId,
        Guid userId,
        string kind,
        DateOnly validFrom,
        DateOnly? expiresOn,
        string? issuer,
        string? notes,
        Guid? documentId)
    {
        if (id == Guid.Empty || organizationId == Guid.Empty || userId == Guid.Empty)
        {
            throw new ArgumentException("Gli identificativi sono obbligatori.");
        }

        Id = id;
        OrganizationId = organizationId;
        UserId = userId;
        Kind = RequireText(kind, 120, nameof(kind));
        SetValidity(validFrom, expiresOn);
        Issuer = NormalizeText(issuer, 200, nameof(issuer));
        Notes = NormalizeText(notes, 1000, nameof(notes));
        DocumentId = documentId;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public Guid Id { get; private set; }

    public Guid OrganizationId { get; private set; }

    public Guid UserId { get; private set; }

    /// <summary>
    /// Il tipo di abilitazione, scritto come lo chiama la cooperativa.
    /// </summary>
    public string Kind { get; private set; } = string.Empty;

    public DateOnly ValidFrom { get; private set; }

    /// <summary>
    /// Assente per un'abilitazione che non scade.
    /// </summary>
    public DateOnly? ExpiresOn { get; private set; }

    public string? Issuer { get; private set; }

    public string? Notes { get; private set; }

    /// <summary>
    /// L'attestato allegato, se caricato.
    /// </summary>
    public Guid? DocumentId { get; private set; }

    public DateTimeOffset UpdatedAt { get; private set; }

    public bool IsValidOn(DateOnly date)
    {
        return date >= ValidFrom && (ExpiresOn is null || date <= ExpiresOn);
    }

    public void Update(
        string kind,
        DateOnly validFrom,
        DateOnly? expiresOn,
        string? issuer,
        string? notes,
        Guid? documentId)
    {
        Kind = RequireText(kind, 120, nameof(kind));
        SetValidity(validFrom, expiresOn);
        Issuer = NormalizeText(issuer, 200, nameof(issuer));
        Notes = NormalizeText(notes, 1000, nameof(notes));
        DocumentId = documentId;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    private void SetValidity(DateOnly validFrom, DateOnly? expiresOn)
    {
        if (expiresOn is not null && expiresOn < validFrom)
        {
            throw new ArgumentException(
                "La scadenza non può precedere l'inizio della validità.",
                nameof(expiresOn));
        }

        ValidFrom = validFrom;
        ExpiresOn = expiresOn;
    }

    private static string RequireText(string value, int maximumLength, string parameterName)
    {
        return NormalizeText(value, maximumLength, parameterName)
            ?? throw new ArgumentException("Il valore è obbligatorio.", parameterName);
    }

    private static string? NormalizeText(
        string? value,
        int maximumLength,
        string parameterName)
    {
        var trimmed = string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        return trimmed?.Length > maximumLength
            ? throw new ArgumentException(
                "Il valore supera la lunghezza consentita.",
                parameterName)
            : trimmed;
    }
}
