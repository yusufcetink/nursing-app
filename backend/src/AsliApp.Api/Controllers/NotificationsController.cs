using System.Security.Claims;
using AsliApp.Api.Notifications;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AsliApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/notifications")]
public sealed class NotificationsController(NotificationTrackingService service) : ControllerBase
{
    [HttpPost("{notificationId:guid}/opened")]
    public async Task<IActionResult> Opened(Guid notificationId, CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue("sub"), out var userId)) return Unauthorized();
        await service.MarkOpenedAsync(notificationId, userId, cancellationToken);
        return NoContent();
    }
}
