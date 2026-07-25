using Microsoft.Extensions.DependencyInjection;
using Silvae.Application.Identity;
using Silvae.Application.Sync;
using Silvae.Application.Worksites;

namespace Silvae.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(
        this IServiceCollection services)
    {
        services.AddSingleton(TimeProvider.System);
        services.AddScoped<CurrentUserService>();
        services.AddScoped<WorksiteService>();
        services.AddScoped<SyncService>();
        return services;
    }
}
