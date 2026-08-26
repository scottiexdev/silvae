using Silvae.Application.Abstractions;
using Silvae.Application.Identity;
using Silvae.Domain.Organizations;

namespace Silvae.Application.Worksites;

public sealed class WorksiteService(
    IRequestContext requestContext,
    ISilvaeStore store,
    CurrentUserService currentUser)
{
    public async Task<IReadOnlyList<WorksiteDto>> GetAssignedAsync(
        CancellationToken cancellationToken)
    {
        var membership = await currentUser.GetSelectedMembershipAsync(cancellationToken);
        var includeAll = membership.Role is
            OrganizationRole.Administrator or OrganizationRole.Coordinator;
        var worksites = await store.GetAssignedWorksitesAsync(
            membership.OrganizationId,
            requestContext.UserId,
            includeAll,
            cancellationToken);
        var jobOrders = (await store.GetJobOrdersAsync(
                membership.OrganizationId,
                cancellationToken))
            .ToDictionary(item => item.Id);

        return worksites
            .Select(item =>
            {
                var jobOrder = item.JobOrderId is null
                    ? null
                    : jobOrders.GetValueOrDefault(item.JobOrderId.Value);
                return new WorksiteDto(
                    item.Id,
                    item.Code,
                    item.Name,
                    item.Address,
                    item.JobOrderId,
                    jobOrder?.Code,
                    jobOrder?.Name,
                    item.Version,
                    item.UpdatedAt);
            })
            .ToArray();
    }
}

public sealed record WorksiteDto(
    Guid Id,
    string Code,
    string Name,
    string? Address,
    Guid? JobOrderId,
    string? JobOrderCode,
    string? JobOrderName,
    long Version,
    DateTimeOffset UpdatedAt);
