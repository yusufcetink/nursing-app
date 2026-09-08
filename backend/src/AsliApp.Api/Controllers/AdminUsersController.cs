using AsliApp.Api.Administration;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AsliApp.Api.Controllers;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("api/admin/users")]
public sealed class AdminUsersController(AdminUserService adminUserService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<AdminUserResponse>>> GetUsers(
        [FromQuery] string? search,
        CancellationToken cancellationToken) =>
        Ok(await adminUserService.GetUsersAsync(search, cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<AdminUserResponse>> GetUser(Guid id)
    {
        var user = await adminUserService.GetUserAsync(id);
        return user is null ? NotFound() : Ok(user);
    }

    [HttpPut("{id:guid}/role")]
    public async Task<ActionResult<AdminUserResponse>> ChangeRole(
        Guid id,
        ChangeUserRoleRequest request,
        CancellationToken cancellationToken)
    {
        var result = await adminUserService.ChangeRoleAsync(id, request.Role, cancellationToken);
        return result.Status switch
        {
            ChangeUserRoleStatus.Success => Ok(result.User),
            ChangeUserRoleStatus.NotFound => NotFound(),
            ChangeUserRoleStatus.LastAdmin => Conflict(new AdminErrorResponse(
                ["The last admin cannot be assigned another role."])),
            _ => BadRequest(new AdminErrorResponse(
                result.Errors ?? ["The role could not be changed."])),
        };
    }
}
