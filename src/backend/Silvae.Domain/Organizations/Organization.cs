namespace Silvae.Domain.Organizations;

public sealed class Organization
{
    private Organization()
    {
    }

    public Organization(Guid id, string name)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("L'identificativo è obbligatorio.", nameof(id));
        }

        Id = id;
        Name = RequireText(name, nameof(name));
    }

    public Guid Id { get; private set; }

    public string Name { get; private set; } = string.Empty;

    private static string RequireText(string value, string parameterName)
    {
        return string.IsNullOrWhiteSpace(value)
            ? throw new ArgumentException("Il valore è obbligatorio.", parameterName)
            : value.Trim();
    }
}
