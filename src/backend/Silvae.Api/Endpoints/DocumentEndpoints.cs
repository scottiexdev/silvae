using System.Globalization;
using Microsoft.AspNetCore.Mvc;
using Silvae.Application.Documents;
using Silvae.Domain.Documents;

namespace Silvae.Api.Endpoints;

public static class DocumentEndpoints
{
    public static IEndpointRouteBuilder MapDocumentEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/documents")
            .RequireAuthorization()
            .WithTags("Documents");

        group.MapGet(
                "",
                async (
                    Guid? worksiteId,
                    DocumentService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(
                        await service.GetAllAsync(worksiteId, cancellationToken)))
            .WithName("GetDocuments");

        group.MapGet(
                "/{documentId:guid}/content",
                async (
                    Guid documentId,
                    DocumentService service,
                    CancellationToken cancellationToken) =>
                {
                    var document = await service.DownloadAsync(
                        documentId,
                        cancellationToken);
                    return Results.File(
                        document.Content,
                        document.ContentType,
                        document.FileName);
                })
            .WithName("DownloadDocument");

        group.MapPost(
                "",
                async (
                    [FromForm] IFormFile file,
                    [FromForm] string title,
                    [FromForm] string category,
                    [FromForm] Guid? worksiteId,
                    [FromForm] DateOnly? issuedOn,
                    [FromForm] DateOnly? expiresOn,
                    DocumentService service,
                    CancellationToken cancellationToken) =>
                {
                    // Il tetto si verifica prima di leggere: caricare in
                    // memoria un file da mezzo giga per poi rifiutarlo
                    // regalerebbe a chiunque un modo di far cadere l'API.
                    if (file.Length > StoredDocument.MaximumSizeBytes)
                    {
                        return Results.Problem(
                            "Il file supera i 10 MB consentiti.",
                            statusCode: StatusCodes.Status413PayloadTooLarge);
                    }

                    using var buffer = new MemoryStream();
                    await file.CopyToAsync(buffer, cancellationToken);

                    var document = await service.UploadAsync(
                        new UploadDocumentRequest(
                            worksiteId,
                            title,
                            category,
                            issuedOn,
                            expiresOn,
                            file.FileName,
                            string.IsNullOrWhiteSpace(file.ContentType)
                                ? "application/octet-stream"
                                : file.ContentType,
                            buffer.ToArray()),
                        cancellationToken);

                    return Results.Created(
                        string.Create(
                            CultureInfo.InvariantCulture,
                            $"/api/documents/{document.Id}"),
                        document);
                })
            .WithName("UploadDocument")
            .DisableAntiforgery();

        group.MapDelete(
                "/{documentId:guid}",
                async (
                    Guid documentId,
                    DocumentService service,
                    CancellationToken cancellationToken) =>
                {
                    await service.DeleteAsync(documentId, cancellationToken);
                    return TypedResults.NoContent();
                })
            .WithName("DeleteDocument");

        return endpoints;
    }
}
