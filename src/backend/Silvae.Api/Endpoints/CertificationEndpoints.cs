using System.Globalization;
using Silvae.Application.People;

namespace Silvae.Api.Endpoints;

public static class CertificationEndpoints
{
    public static IEndpointRouteBuilder MapCertificationEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/certifications")
            .RequireAuthorization()
            .WithTags("Certifications");

        group.MapGet(
                "",
                async (
                    Guid? userId,
                    DateOnly? validOn,
                    CertificationService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.GetAllAsync(
                        userId,
                        validOn,
                        cancellationToken)))
            .WithName("GetCertifications");

        group.MapGet(
                "/expiring",
                async (
                    int? withinDays,
                    CertificationService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.GetExpiringAsync(
                        withinDays ?? 60,
                        cancellationToken)))
            .WithName("GetExpiringCertifications");

        // L'estrazione che si mostra a un RSPP: chi era in cantiere in quelle
        // giornate e con quali abilitazioni valide allora.
        group.MapGet(
                "/inspection",
                async (
                    Guid? worksiteId,
                    DateOnly from,
                    DateOnly to,
                    CertificationService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.GetInspectionAsync(
                        worksiteId,
                        from,
                        to,
                        cancellationToken)))
            .WithName("GetCertificationInspection");

        group.MapPost(
                "",
                async (
                    UpsertCertificationRequest request,
                    CertificationService service,
                    CancellationToken cancellationToken) =>
                {
                    var certification = await service.CreateAsync(
                        request,
                        cancellationToken);
                    return TypedResults.Created(
                        string.Create(
                            CultureInfo.InvariantCulture,
                            $"/api/certifications/{certification.Id}"),
                        certification);
                })
            .WithName("CreateCertification");

        group.MapPut(
                "/{certificationId:guid}",
                async (
                    Guid certificationId,
                    UpsertCertificationRequest request,
                    CertificationService service,
                    CancellationToken cancellationToken) =>
                    TypedResults.Ok(await service.UpdateAsync(
                        certificationId,
                        request,
                        cancellationToken)))
            .WithName("UpdateCertification");

        group.MapDelete(
                "/{certificationId:guid}",
                async (
                    Guid certificationId,
                    CertificationService service,
                    CancellationToken cancellationToken) =>
                {
                    await service.DeleteAsync(certificationId, cancellationToken);
                    return TypedResults.NoContent();
                })
            .WithName("DeleteCertification");

        return endpoints;
    }
}
