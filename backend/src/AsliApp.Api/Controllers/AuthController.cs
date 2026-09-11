using AsliApp.Api.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AsliApp.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(AuthService authService) : ControllerBase
{
    [HttpPost("register")]
    [ProducesResponseType<UserResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<AuthErrorResponse>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<UserResponse>> Register(
        RegisterRequest request,
        CancellationToken cancellationToken)
    {
        var result = await authService.RegisterAsync(request, cancellationToken);
        if (!result.Succeeded)
        {
            return BadRequest(new AuthErrorResponse(result.Errors));
        }

        return StatusCode(StatusCodes.Status201Created, result.Value);
    }

    [HttpPost("login")]
    [ProducesResponseType<LoginResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<AuthErrorResponse>(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<LoginResponse>> Login(
        LoginRequest request,
        CancellationToken cancellationToken)
    {
        var result = await authService.LoginAsync(request, cancellationToken);
        if (!result.Succeeded)
        {
            return Unauthorized(new AuthErrorResponse(result.Errors));
        }

        return Ok(result.Value);
    }

    [HttpPost("verify-email")]
    [ProducesResponseType<AuthOperationResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<AuthErrorResponse>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<AuthOperationResponse>> VerifyEmail(
        VerifyEmailRequest request,
        CancellationToken cancellationToken)
    {
        var result = await authService.VerifyEmailAsync(request, cancellationToken);
        if (!result.Succeeded)
        {
            return BadRequest(new AuthErrorResponse(result.Errors));
        }

        return Ok(result.Value);
    }

    [HttpPost("resend-verification")]
    [ProducesResponseType<AuthOperationResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<AuthOperationResponse>> ResendVerification(
        EmailRequest request,
        CancellationToken cancellationToken)
    {
        var result = await authService.ResendVerificationAsync(request, cancellationToken);
        return Ok(result.Value);
    }

    [HttpPost("forgot-password")]
    [ProducesResponseType<AuthOperationResponse>(StatusCodes.Status202Accepted)]
    public async Task<ActionResult<AuthOperationResponse>> ForgotPassword(
        EmailRequest request,
        CancellationToken cancellationToken)
    {
        var result = await authService.ForgotPasswordAsync(request, cancellationToken);
        return Accepted(result.Value);
    }

    [HttpPost("reset-password")]
    [ProducesResponseType<AuthOperationResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<AuthErrorResponse>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<AuthOperationResponse>> ResetPassword(
        ResetPasswordRequest request,
        CancellationToken cancellationToken)
    {
        var result = await authService.ResetPasswordAsync(request, cancellationToken);
        if (!result.Succeeded)
        {
            return BadRequest(new AuthErrorResponse(result.Errors));
        }

        return Ok(result.Value);
    }

    [Authorize]
    [HttpGet("me")]
    [ProducesResponseType<UserResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<UserResponse>> Me()
    {
        var userIdClaim = User.FindFirst("sub")?.Value;
        if (!Guid.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized();
        }

        var result = await authService.GetUserAsync(userId);
        if (!result.Succeeded)
        {
            return Unauthorized();
        }

        return Ok(result.Value);
    }
}
