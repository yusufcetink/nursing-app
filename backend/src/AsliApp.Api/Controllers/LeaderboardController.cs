using System.Security.Claims;
using AsliApp.Api.Education;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AsliApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/leaderboard")]
public sealed class LeaderboardController(LeaderboardService leaderboard) : ControllerBase
{
    [HttpGet("courses")]
    public async Task<ActionResult<IReadOnlyList<LeaderboardCourseResponse>>> GetCourses(
        CancellationToken cancellationToken) =>
        Ok(await leaderboard.GetCoursesAsync(cancellationToken));

    [HttpGet]
    public async Task<ActionResult<LeaderboardResponse>> Get(
        [FromQuery] string period = "weekly", [FromQuery] Guid? courseId = null,
        [FromQuery] int offset = 0, [FromQuery] int limit = 20,
        CancellationToken cancellationToken = default)
    {
        if (!Guid.TryParse(User.FindFirstValue("sub"), out var userId)) return Unauthorized();
        if (period is not ("weekly" or "monthly" or "allTime") || offset < 0 || limit is < 1 or > 100)
            return BadRequest();
        var result = await leaderboard.GetAsync(userId, period, courseId, offset, limit, cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }
}
