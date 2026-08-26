using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using Silvae.Api.Authentication;
using Silvae.Api.Endpoints;
using Silvae.Api.Middleware;
using Silvae.Application;
using Silvae.Application.Abstractions;
using Silvae.Infrastructure;
using Silvae.Infrastructure.Persistence;

const string WebClientCorsPolicy = "silvae-web";

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddHealthChecks();

var allowedOrigins = (builder.Configuration["SILVAE_ALLOWED_ORIGINS"] ?? string.Empty)
    .Split([',', ';'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
builder.Services.AddCors(options =>
{
    options.AddPolicy(WebClientCorsPolicy, policy =>
    {
        if (allowedOrigins.Length > 0)
        {
            policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod();
        }
        else if (builder.Environment.IsDevelopment())
        {
            policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
        }
        else
        {
            policy.SetIsOriginAllowed(_ => false);
        }
    });
});

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Authentication:Authority"];
        options.Audience =
            builder.Configuration["Authentication:Audience"] ?? "authenticated";
        options.MapInboundClaims = false;
    });
builder.Services.AddAuthorization();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IRequestContext, HttpRequestContext>();
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration, builder.Environment);

var app = builder.Build();

await using (var scope = app.Services.CreateAsyncScope())
{
    var database = scope.ServiceProvider.GetRequiredService<SilvaeDbContext>();
    if (database.Database.IsRelational())
    {
        await database.Database.MigrateAsync();
    }
    else
    {
        await database.Database.EnsureCreatedAsync();
    }

    // Dati minimi per provare l'app dal vivo. Solo in sviluppo: in qualsiasi
    // altro ambiente creare da sé un'organizzazione e una membership da
    // amministratore significherebbe fabbricare un accesso.
    if (app.Environment.IsDevelopment())
    {
        var seedUserId = app.Configuration["SILVAE_SEED_USER_ID"];
        if (Guid.TryParse(seedUserId, out var userId))
        {
            var seeded = await DevelopmentSeed.ApplyAsync(
                database,
                userId,
                app.Configuration["SILVAE_SEED_DISPLAY_NAME"] ?? "Operatore di prova",
                CancellationToken.None);
            if (seeded)
            {
                app.Logger.LogInformation(
                    "Dati di sviluppo inseriti. Organizzazione {OrganizationId}.",
                    DevelopmentSeed.OrganizationId);
            }
        }
        else if (!string.IsNullOrWhiteSpace(seedUserId))
        {
            app.Logger.LogWarning(
                "SILVAE_SEED_USER_ID non è un UUID valido: dati di sviluppo non inseriti.");
        }
    }
}

app.UseForwardedHeaders();
app.UseMiddleware<CorrelationIdMiddleware>();
app.UseMiddleware<ApiExceptionMiddleware>();
app.UseCors(WebClientCorsPolicy);
app.UseAuthentication();
app.UseAuthorization();

app.MapOpenApi();
app.MapHealthEndpoints();
app.MapIdentityEndpoints();
app.MapWorksiteEndpoints();
app.MapSyncEndpoints();

app.Run();

public partial class Program;
