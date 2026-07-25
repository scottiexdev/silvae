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

        return worksites
            .Select(item => new WorksiteDto(
                item.Id,
                item.Code,
                item.Name,
                item.Address,
                item.Version,
                item.UpdatedAt))
            .ToArray();
    }
}

public sealed record WorksiteDto(
    Guid Id,
    string Code,
    string Name,
    string? Address,
    long Version,
    DateTimeOffset UpdatedAt);
