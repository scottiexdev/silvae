using Silvae.Application.Abstractions;
using Silvae.Application.Common;
using Silvae.Domain.Organizations;

namespace Silvae.Application.Identity;

public sealed class CurrentUserService(
    IRequestContext requestContext,
    ISilvaeStore store)
{
    public async Task<CurrentUserDto> GetAsync(CancellationToken cancellationToken)
    {
        EnsureAuthenticated();

        var memberships = await store.GetMembershipsAsync(
            requestContext.UserId,
            cancellationToken);

        if (memberships.Count == 0)
        {
            throw new OrganizationAccessDeniedException();
        }

        Guid? selectedOrganizationId = requestContext.SelectedOrganizationId;
        if (selectedOrganizationId is not null &&
            memberships.All(item => item.OrganizationId != selectedOrganizationId))
        {
            throw new OrganizationAccessDeniedException();
        }

        selectedOrganizationId ??= memberships.Count == 1
            ? memberships[0].OrganizationId
            : null;

        return new CurrentUserDto(
            requestContext.UserId,
            selectedOrganizationId,
            memberships
                .Select(item => new MembershipDto(
                    item.OrganizationId,
                    item.DisplayName,
                    item.Role.ToString()))
                .ToArray());
    }

    public async Task<UserMembership> GetSelectedMembershipAsync(
        CancellationToken cancellationToken)
    {
        EnsureAuthenticated();

        if (requestContext.SelectedOrganizationId is not { } organizationId)
        {
            var memberships = await store.GetMembershipsAsync(
                requestContext.UserId,
                cancellationToken);

            if (memberships.Count != 1)
            {
                throw new OrganizationAccessDeniedException();
            }

            return memberships[0];
        }

        return await store.GetMembershipAsync(
                organizationId,
                requestContext.UserId,
                cancellationToken)
            ?? throw new OrganizationAccessDeniedException();
    }

    private void EnsureAuthenticated()
    {
        if (requestContext.UserId == Guid.Empty)
        {
            throw new AuthenticationRequiredException();
        }
    }
}

public sealed record CurrentUserDto(
    Guid UserId,
    Guid? SelectedOrganizationId,
    IReadOnlyList<MembershipDto> Memberships);

public sealed record MembershipDto(
    Guid OrganizationId,
    string DisplayName,
    string Role);
