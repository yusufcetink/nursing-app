using System.Security.Claims;
using AsliApp.Api.Analytics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AsliApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/activity")]
public sealed class ActivityController(ActivityService activityService) : ControllerBase
{
    [HttpPost("events/batch")]
    public async Task<ActionResult<ActivityBatchResponse>> RecordBatch(
        ActivityBatchRequest request,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue("sub"), out var userId)) return Unauthorized();
        try
        {
            return Ok(await activityService.RecordBatchAsync(userId, request, cancellationToken));
        }
        catch (ArgumentException error)
        {
            return BadRequest(new { errors = new[] { error.Message } });
        }
        catch (ActivitySessionOwnershipException)
        {
            return Conflict(new { errors = new[] { "Session ownership is invalid." } });
        }
    }
}
