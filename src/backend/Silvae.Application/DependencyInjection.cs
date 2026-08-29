using Microsoft.Extensions.DependencyInjection;
using Silvae.Application.DailyReports;
using Silvae.Application.Documents;
using Silvae.Application.Identity;
using Silvae.Application.JobOrders;
using Silvae.Application.Organizations;
using Silvae.Application.People;
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
        services.AddScoped<OrganizationBootstrapService>();
        services.AddScoped<MembershipService>();
        services.AddScoped<JobOrderService>();
        services.AddScoped<WorksiteService>();
        services.AddScoped<DailyReportService>();
        services.AddScoped<CertificationService>();
        services.AddScoped<DocumentService>();
        services.AddScoped<SyncService>();
        return services;
    }
}
