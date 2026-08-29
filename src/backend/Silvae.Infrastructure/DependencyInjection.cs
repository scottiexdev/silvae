using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Silvae.Application.Abstractions;
using Silvae.Infrastructure.Configuration;
using Silvae.Infrastructure.Persistence;

namespace Silvae.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        // Licenza Community di QuestPDF: gratuita sotto il milione di dollari
        // di ricavi. Va dichiarata prima di generare il primo PDF.
        QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;

        var connectionString = configuration.GetConnectionString("Silvae");

        services.AddDbContext<SilvaeDbContext>(options =>
        {
            if (string.IsNullOrWhiteSpace(connectionString))
            {
                if (!environment.IsDevelopment() &&
                    !environment.IsEnvironment("Testing"))
                {
                    throw new InvalidOperationException(
                        "ConnectionStrings:Silvae è obbligatoria fuori dallo sviluppo.");
                }

                options.UseInMemoryDatabase($"silvae-{environment.EnvironmentName}");
            }
            else
            {
                options.UseNpgsql(connectionString);
            }
        });
        services.AddScoped<ISilvaeStore, EfSilvaeStore>();
        services.AddSingleton<IBootstrapSecret, ConfigurationBootstrapSecret>();

        return services;
    }
}
