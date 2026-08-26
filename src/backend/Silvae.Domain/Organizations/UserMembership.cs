namespace Silvae.Domain.Organizations;

public enum OrganizationRole
{
    Administrator,
    Coordinator,
    CrewLeader,
    Worker,
}

public sealed class UserMembership
{
    private UserMembership()
    {
    }

    public UserMembership(
        Guid organizationId,
        Guid userId,
        OrganizationRole role,
        string displayName)
    {
        if (organizationId == Guid.Empty || userId == Guid.Empty)
        {
            throw new ArgumentException("Organizzazione e utente sono obbligatori.");
        }

        OrganizationId = organizationId;
        UserId = userId;
        Role = role;
        DisplayName = RequireDisplayName(displayName);
    }

    public Guid OrganizationId { get; private set; }

    public Guid UserId { get; private set; }

    public OrganizationRole Role { get; private set; }

    public string DisplayName { get; private set; } = string.Empty;

    public void ChangeRole(OrganizationRole role)
    {
        Role = role;
    }

    public void Rename(string displayName)
    {
        DisplayName = RequireDisplayName(displayName);
    }

    private static string RequireDisplayName(string displayName)
    {
        return string.IsNullOrWhiteSpace(displayName)
            ? throw new ArgumentException("Il nome è obbligatorio.", nameof(displayName))
            : displayName.Trim();
    }
}
