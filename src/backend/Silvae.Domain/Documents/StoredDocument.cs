namespace Silvae.Domain.Documents;

/// <summary>
/// Un documento archiviato: autorizzazione di cantiere, attestato di un corso,
/// perizia. Il legame con il cantiere è facoltativo perché un attestato
/// appartiene alla persona, non al cantiere.
/// </summary>
// ponytail: i byte stanno in Postgres con un tetto di 10 MB. Sono poche
// decine di PDF per organizzazione e così non serve né Supabase Storage né la
// firma degli URL. Se l'archivio cresce o entrano le foto, il contenuto passa
// allo storage a oggetti e qui resta la chiave.
public sealed class StoredDocument
{
    public const int MaximumSizeBytes = 10 * 1024 * 1024;

    private StoredDocument()
    {
    }

    public StoredDocument(
        Guid id,
        Guid organizationId,
        Guid? worksiteId,
        string title,
        string category,
        DateOnly? issuedOn,
        DateOnly? expiresOn,
        string fileName,
        string contentType,
        byte[] content,
        Guid uploadedBy,
        DateTimeOffset uploadedAt)
    {
        ArgumentNullException.ThrowIfNull(content);

        if (id == Guid.Empty || organizationId == Guid.Empty)
        {
            throw new ArgumentException("Gli identificativi sono obbligatori.");
        }

        if (content.Length == 0)
        {
            throw new ArgumentException("Il file è vuoto.", nameof(content));
        }

        if (content.Length > MaximumSizeBytes)
        {
            throw new ArgumentOutOfRangeException(
                nameof(content),
                "Il file supera i 10 MB consentiti.");
        }

        if (expiresOn is not null && issuedOn is not null && expiresOn < issuedOn)
        {
            throw new ArgumentException(
                "La scadenza non può precedere il rilascio.",
                nameof(expiresOn));
        }

        Id = id;
        OrganizationId = organizationId;
        WorksiteId = worksiteId;
        Title = RequireText(title, 200, nameof(title));
        Category = RequireText(category, 64, nameof(category));
        IssuedOn = issuedOn;
        ExpiresOn = expiresOn;
        FileName = RequireText(fileName, 260, nameof(fileName));
        ContentType = RequireText(contentType, 128, nameof(contentType));
        Content = content;
        UploadedBy = uploadedBy;
        UploadedAt = uploadedAt;
    }

    public Guid Id { get; private set; }

    public Guid OrganizationId { get; private set; }

    public Guid? WorksiteId { get; private set; }

    public string Title { get; private set; } = string.Empty;

    /// <summary>
    /// Come la cooperativa lo chiama: autorizzazione, attestato, perizia.
    /// </summary>
    public string Category { get; private set; } = string.Empty;

    public DateOnly? IssuedOn { get; private set; }

    public DateOnly? ExpiresOn { get; private set; }

    public string FileName { get; private set; } = string.Empty;

    public string ContentType { get; private set; } = string.Empty;

    public byte[] Content { get; private set; } = [];

    public int SizeBytes => Content.Length;

    public Guid UploadedBy { get; private set; }

    public DateTimeOffset UploadedAt { get; private set; }

    private static string RequireText(string value, int maximumLength, string parameterName)
    {
        var trimmed = string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        if (trimmed is null)
        {
            throw new ArgumentException("Il valore è obbligatorio.", parameterName);
        }

        return trimmed.Length > maximumLength
            ? throw new ArgumentException(
                "Il valore supera la lunghezza consentita.",
                parameterName)
            : trimmed;
    }
}
