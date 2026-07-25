using Microsoft.Extensions.Primitives;

namespace Silvae.Api.Middleware;

public sealed class CorrelationIdMiddleware(
    RequestDelegate next,
    ILogger<CorrelationIdMiddleware> logger)
{
    private const string HeaderName = "X-Correlation-Id";

    public async Task InvokeAsync(HttpContext context)
    {
        var incoming = context.Request.Headers[HeaderName].FirstOrDefault();
        var correlationId = IsValid(incoming)
            ? incoming!
            : Guid.NewGuid().ToString("N");

        context.TraceIdentifier = correlationId;
        context.Response.OnStarting(() =>
        {
            context.Response.Headers[HeaderName] =
                new StringValues(correlationId);
            return Task.CompletedTask;
        });

        using (logger.BeginScope(new Dictionary<string, object>
        {
            ["CorrelationId"] = correlationId,
        }))
        {
            await next(context);
        }
    }

    private static bool IsValid(string? value)
    {
        return !string.IsNullOrWhiteSpace(value) &&
            value.Length <= 100 &&
            value.All(character =>
                char.IsLetterOrDigit(character) ||
                character is '-' or '_' or '.');
    }
}
