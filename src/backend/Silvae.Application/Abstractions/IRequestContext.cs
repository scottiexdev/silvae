namespace Silvae.Application.Abstractions;

public interface IRequestContext
{
    Guid UserId { get; }

    Guid? SelectedOrganizationId { get; }
}
