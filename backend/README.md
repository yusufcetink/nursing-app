# Aslı App Backend

.NET 10 ASP.NET Core backend foundation for Aslı App.

## Projects

- `src/AsliApp.Api`: HTTP host, health endpoint, and Identity/JWT authentication
- `src/AsliApp.Domain`: Core entities and roles
- `src/AsliApp.Infrastructure`: EF Core SQL Server persistence
- `tests/AsliApp.Domain.Tests`: Domain tests

Configure SQL Server outside source control, for example with the `ConnectionStrings__DefaultConnection` environment variable. No connection string is committed.

Configure the JWT signing key with the `Jwt__Key` environment variable. It must be at least 32 bytes. The issuer, audience, and token lifetime have non-secret defaults in `appsettings.json` and can also be overridden through configuration.

Lesson media files are stored outside the application and source directories. Development uses `C:\AsliAppStorage`; production defaults to `D:\AsliAppStorage`. Override the location and upload limit when needed:

```powershell
$env:FileStorage__RootPath = "D:\AsliAppStorage"
$env:FileStorage__MaxFileSizeBytes = "26214400"
```

Grant the application pool or service account read/write access to the configured directory. The database stores only relative keys such as `images/<guid>.png` and `videos/<guid>.mp4`.

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

Email confirmation and password reset use separate hashed, six-digit, single-use
codes. Codes expire after 10 minutes, lock after five failed attempts, and enforce
a resend cooldown; Identity reset tokens remain internal to the API.

Bootstrap the first administrator only through user-secrets or environment variables. The
bootstrap is skipped after an Admin exists, and no public admin registration endpoint exists.
If the configured email already belongs to a roleless account, that account is claimed only
when the configured password matches its existing password:

```powershell
dotnet user-secrets set "AdminBootstrap:Email" "admin@example.com" --project src/AsliApp.Api
dotnet user-secrets set "AdminBootstrap:Password" "use-a-strong-unique-password" --project src/AsliApp.Api
```

Environment variable equivalents are `AdminBootstrap__Email` and
`AdminBootstrap__Password`. Optional display names use `AdminBootstrap__FirstName` and
`AdminBootstrap__LastName`.

Restore the local EF tool with `dotnet tool restore` before creating future migrations.
