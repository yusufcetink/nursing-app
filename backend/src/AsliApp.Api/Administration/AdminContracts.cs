using System.ComponentModel.DataAnnotations;
using AsliApp.Domain.Users;

namespace AsliApp.Api.Administration;

public sealed record AdminUserResponse(
    Guid Id,
    string FirstName,
    string LastName,
    string Email,
    UserRole Role);

public sealed record ChangeUserRoleRequest([Required] UserRole Role);

public sealed record AdminErrorResponse(IReadOnlyList<string> Errors);

public enum ChangeUserRoleStatus
{
    Success,
    NotFound,
    LastAdmin,
    Failed,
}

public sealed record ChangeUserRoleResult(
    ChangeUserRoleStatus Status,
    AdminUserResponse? User = null,
    IReadOnlyList<string>? Errors = null);
