namespace Silvae.Domain.JobOrders;

/// <summary>
/// Commessa: il lavoro concordato con il committente, sotto cui ricadono uno o
/// più cantieri.
/// </summary>
public sealed class JobOrder
{
    private JobOrder()
    {
    }

    public JobOrder(
        Guid id,
        Guid organizationId,
        string code,
        string name,
        string? customer = null)
    {
        if (id == Guid.Empty || organizationId == Guid.Empty)
        {
            throw new ArgumentException("Gli identificativi sono obbligatori.");
        }

        Id = id;
        OrganizationId = organizationId;
        Code = RequireText(code, nameof(code));
        Name = RequireText(name, nameof(name));
        Customer = NormalizeCustomer(customer);
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public Guid Id { get; private set; }

    public Guid OrganizationId { get; private set; }

    public string Code { get; private set; } = string.Empty;

    public string Name { get; private set; } = string.Empty;

    public string? Customer { get; private set; }

    public bool IsActive { get; private set; } = true;

    public long Version { get; private set; } = 1;

    public DateTimeOffset UpdatedAt { get; private set; }

    public void Rename(string name)
    {
        Name = RequireText(name, nameof(name));
        Touch();
    }

    public void SetCustomer(string? customer)
    {
        Customer = NormalizeCustomer(customer);
        Touch();
    }

    public void Close()
    {
        if (!IsActive)
        {
            return;
        }

        IsActive = false;
        Touch();
    }

    private void Touch()
    {
        Version++;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    private static string? NormalizeCustomer(string? customer)
    {
        return string.IsNullOrWhiteSpace(customer) ? null : customer.Trim();
    }

    private static string RequireText(string value, string parameterName)
    {
        return string.IsNullOrWhiteSpace(value)
            ? throw new ArgumentException("Il valore è obbligatorio.", parameterName)
            : value.Trim();
    }
}
