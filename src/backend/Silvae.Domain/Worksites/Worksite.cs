namespace Silvae.Domain.Worksites;

public sealed class Worksite
{
    private readonly List<WorksiteAssignment> _assignments = [];

    private Worksite()
    {
    }

    public Worksite(Guid id, Guid organizationId, string code, string name)
    {
        if (id == Guid.Empty || organizationId == Guid.Empty)
        {
            throw new ArgumentException("Gli identificativi sono obbligatori.");
        }

        Id = id;
        OrganizationId = organizationId;
        Code = RequireText(code, nameof(code));
        Name = RequireText(name, nameof(name));
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public Guid Id { get; private set; }

    public Guid OrganizationId { get; private set; }

    public string Code { get; private set; } = string.Empty;

    public string Name { get; private set; } = string.Empty;

    public string? Address { get; private set; }

    public bool IsActive { get; private set; } = true;

    public long Version { get; private set; } = 1;

    public DateTimeOffset UpdatedAt { get; private set; }

    public IReadOnlyCollection<WorksiteAssignment> Assignments => _assignments;

    public void Assign(Guid userId)
    {
        if (userId == Guid.Empty)
        {
            throw new ArgumentException("L'utente è obbligatorio.", nameof(userId));
        }

        if (_assignments.All(item => item.UserId != userId))
        {
            _assignments.Add(new WorksiteAssignment(Id, userId));
        }
    }

    public void SetAddress(string? address)
    {
        Address = string.IsNullOrWhiteSpace(address) ? null : address.Trim();
        Touch();
    }

    private void Touch()
    {
        Version++;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    private static string RequireText(string value, string parameterName)
    {
        return string.IsNullOrWhiteSpace(value)
            ? throw new ArgumentException("Il valore è obbligatorio.", parameterName)
            : value.Trim();
    }
}

public sealed class WorksiteAssignment
{
    private WorksiteAssignment()
    {
    }

    public WorksiteAssignment(Guid worksiteId, Guid userId)
    {
        WorksiteId = worksiteId;
        UserId = userId;
    }

    public Guid WorksiteId { get; private set; }

    public Guid UserId { get; private set; }
}
