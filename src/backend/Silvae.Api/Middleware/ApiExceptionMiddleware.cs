using Microsoft.AspNetCore.Mvc;
using Silvae.Application.Common;

namespace Silvae.Api.Middleware;

public sealed class ApiExceptionMiddleware(
    RequestDelegate next,
    ILogger<ApiExceptionMiddleware> logger)
{
    private static readonly Action<ILogger, string, Exception> LogUnhandledError =
        LoggerMessage.Define<string>(
            LogLevel.Error,
            new EventId(1000, "UnhandledApiError"),
            "Errore non gestito nella richiesta {TraceIdentifier}");

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (SilvaeApplicationException exception)
        {
            await WriteApplicationErrorAsync(context, exception);
        }
        catch (ArgumentException exception)
        {
            await WriteProblemAsync(
                context,
                StatusCodes.Status400BadRequest,
                "Dati non validi",
                exception.Message);
        }
        catch (InvalidOperationException exception)
        {
            await WriteProblemAsync(
                context,
                StatusCodes.Status409Conflict,
                "Operazione non consentita",
                exception.Message);
        }
        catch (Exception exception)
        {
            LogUnhandledError(logger, context.TraceIdentifier, exception);
            await WriteProblemAsync(
                context,
                StatusCodes.Status500InternalServerError,
                "Errore interno",
                "La richiesta non può essere completata.");
        }
    }

    private static Task WriteApplicationErrorAsync(
        HttpContext context,
        SilvaeApplicationException exception)
    {
        var (status, title) = exception switch
        {
            AuthenticationRequiredException =>
                (StatusCodes.Status401Unauthorized, "Autenticazione richiesta"),
            OrganizationAccessDeniedException or ResourceAccessDeniedException =>
                (StatusCodes.Status403Forbidden, "Accesso negato"),
            SyncConflictException =>
                (StatusCodes.Status409Conflict, "Conflitto di sincronizzazione"),
            SyncValidationException =>
                (StatusCodes.Status400BadRequest, "Operazione non valida"),
            _ => (StatusCodes.Status400BadRequest, "Richiesta non valida"),
        };

        var extensions = exception is SyncConflictException conflict
            ? new Dictionary<string, object?>
            {
                ["currentVersion"] = conflict.CurrentVersion,
            }
            : null;

        return WriteProblemAsync(
            context,
            status,
            title,
            exception.Message,
            extensions);
    }

    private static Task WriteProblemAsync(
        HttpContext context,
        int status,
        string title,
        string detail,
        IDictionary<string, object?>? extensions = null)
    {
        context.Response.StatusCode = status;
        context.Response.ContentType = "application/problem+json";
        return context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = status,
            Title = title,
            Detail = detail,
            Instance = context.Request.Path,
            Extensions =
            {
                ["correlationId"] = context.TraceIdentifier,
                ["context"] = extensions,
            },
        });
    }
}
