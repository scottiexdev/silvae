using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Application.Identity;
using Silvae.Domain.Documents;

namespace Silvae.Application.Documents;

/// <summary>
/// Archivio dei documenti: autorizzazioni di cantiere e attestati delle
/// persone. Chi appartiene all'organizzazione può consultarlo, perché la
/// squadra deve poter mostrare l'autorizzazione a chi la chiede in cantiere;
/// caricare e cancellare resta dell'ufficio.
/// </summary>
public sealed class DocumentService(
    IRequestContext requestContext,
    ISilvaeStore store,
    CurrentUserService currentUser,
    TimeProvider timeProvider)
{
    public async Task<IReadOnlyList<DocumentDto>> GetAllAsync(
        Guid? worksiteId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        var documents = await store.GetDocumentSummariesAsync(
            membership.OrganizationId,
            worksiteId,
            cancellationToken);
        var today = DateOnly.FromDateTime(timeProvider.GetUtcNow().UtcDateTime);

        return documents
            .Select(item => new DocumentDto(
                item.Id,
                item.WorksiteId,
                item.Title,
                item.Category,
                item.IssuedOn,
                item.ExpiresOn,
                item.FileName,
                item.ContentType,
                item.SizeBytes,
                item.ExpiresOn is { } expiresOn && expiresOn < today,
                item.UploadedBy,
                item.UploadedAt))
            .ToArray();
    }

    public async Task<StoredDocument> DownloadAsync(
        Guid documentId,
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);

        return await store.GetDocumentAsync(
                membership.OrganizationId,
                documentId,
                cancellationToken)
            ?? throw new ResourceNotFoundException("Il documento non esiste.");
    }

    public async Task<DocumentDto> UploadAsync(
        UploadDocumentRequest request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        if (request.WorksiteId is { } worksiteId)
        {
            _ = await store.GetWorksiteAsync(
                    membership.OrganizationId,
                    worksiteId,
                    cancellationToken)
                ?? throw new RegistryValidationException("Il cantiere non esiste.");
        }

        var now = timeProvider.GetUtcNow();
        var document = new StoredDocument(
            Guid.CreateVersion7(),
            membership.OrganizationId,
            request.WorksiteId,
            request.Title,
            request.Category,
            request.IssuedOn,
            request.ExpiresOn,
            request.FileName,
            request.ContentType,
            request.Content,
            requestContext.UserId,
            now);

        store.AddDocument(document);
        await store.SaveChangesAsync(cancellationToken);

        return new DocumentDto(
            document.Id,
            document.WorksiteId,
            document.Title,
            document.Category,
            document.IssuedOn,
            document.ExpiresOn,
            document.FileName,
            document.ContentType,
            document.SizeBytes,
            IsExpired: false,
            document.UploadedBy,
            document.UploadedAt);
    }

    public async Task DeleteAsync(Guid documentId, CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        RoleAuthorization.RequireRegistryManager(membership);

        var document = await store.GetDocumentAsync(
                membership.OrganizationId,
                documentId,
                cancellationToken)
            ?? throw new ResourceNotFoundException("Il documento non esiste.");

        store.RemoveDocument(document);
        await store.SaveChangesAsync(cancellationToken);
    }
}

public sealed record DocumentDto(
    Guid Id,
    Guid? WorksiteId,
    string Title,
    string Category,
    DateOnly? IssuedOn,
    DateOnly? ExpiresOn,
    string FileName,
    string ContentType,
    int SizeBytes,
    bool IsExpired,
    Guid UploadedBy,
    DateTimeOffset UploadedAt);

public sealed record UploadDocumentRequest(
    Guid? WorksiteId,
    string Title,
    string Category,
    DateOnly? IssuedOn,
    DateOnly? ExpiresOn,
    string FileName,
    string ContentType,
    byte[] Content);
