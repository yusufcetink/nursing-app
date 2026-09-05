# Aslı App Backend

.NET 10 ASP.NET Core backend foundation for Aslı App.

## Projects

- `src/AsliApp.Api`: HTTP host, health endpoint, and Identity/JWT authentication
- `src/AsliApp.Domain`: Core entities and roles
- `src/AsliApp.Infrastructure`: EF Core SQL Server persistence
- `tests/AsliApp.Domain.Tests`: Domain tests

Configure SQL Server outside source control, for example with the `ConnectionStrings__DefaultConnection` environment variable. No connection string is committed.

Configure the JWT signing key with the `Jwt__Key` environment variable. It must be at least 32 bytes. The issuer, audience, and token lifetime have non-secret defaults in `appsettings.json` and can also be overridden through configuration.

For local Gmail SMTP delivery, configure the sender address and a Gmail app password with user-secrets:

```powershell
dotnet user-secrets set "Gmail:Address" "your-address@gmail.com" --project src/AsliApp.Api
dotnet user-secrets set "Gmail:AppPassword" "your-app-password" --project src/AsliApp.Api
```

Do not use the regular Gmail account password and do not commit either value.

Authentication endpoints:

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/verify-email`
- `POST /api/auth/resend-verification`
- `POST /api/auth/forgot-password`
- `POST /api/auth/reset-password`

Restore the local EF tool with `dotnet tool restore` before creating future migrations.
