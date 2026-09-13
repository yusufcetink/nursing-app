using System.Security.Claims;
using AsliApp.Api.Notifications;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AsliApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/devices")]
public sealed class DevicesController(DeviceRegistrationService service) : ControllerBase
{
    [HttpPut("current")]
    public async Task<ActionResult<DeviceRegistrationResponse>> Register(
        RegisterDeviceRequest request,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue("sub"), out var userId)) return Unauthorized();
        return Ok(await service.RegisterAsync(userId, request, cancellationToken));
    }

    [HttpPost("current/deactivate")]
    public async Task<IActionResult> Deactivate(
        DeactivateDeviceRequest request,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue("sub"), out var userId)) return Unauthorized();
        await service.DeactivateAsync(userId, request.InstallationId, cancellationToken);
        return NoContent();
    }
}
