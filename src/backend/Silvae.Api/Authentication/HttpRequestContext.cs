using System.Security.Claims;
using Silvae.Application.Abstractions;

namespace Silvae.Api.Authentication;

public sealed class HttpRequestContext(IHttpContextAccessor httpContextAccessor)
    : IRequestContext
{
    public Guid UserId => ReadGuidClaim("sub") ??
        ReadGuidClaim(ClaimTypes.NameIdentifier) ??
        Guid.Empty;

    public Guid? SelectedOrganizationId
    {
        get
        {
            var context = httpContextAccessor.HttpContext;
            var claimValue = context?.User.FindFirstValue("organization_id");
            if (Guid.TryParse(claimValue, out var claimOrganizationId))
            {
                return claimOrganizationId;
            }

            var headerValue = context?.Request.Headers["X-Organization-Id"]
                .FirstOrDefault();
            return Guid.TryParse(headerValue, out var headerOrganizationId)
                ? headerOrganizationId
                : null;
        }
    }

    private Guid? ReadGuidClaim(string claimType)
    {
        var value = httpContextAccessor.HttpContext?.User.FindFirstValue(claimType);
        return Guid.TryParse(value, out var result) ? result : null;
    }
}
