# Production deployment

Production configuration contains no credentials. Inject secrets through the host's
secret manager/environment, not tracked JSON, `.env`, build arguments or mobile code.
`appsettings.Production.json` leaves AllowedHosts empty, so startup fails until
deployment supplies it. Its storage root defaults to `App_Data\asliapp-storage`
for Turhost/Plesk Windows shared hosting. Environment variables override JSON.

## Backend environment

| Variable | Value or placeholder | Requirement |
| --- | --- | --- |
| `ASPNETCORE_ENVIRONMENT` | `Production` | Required; do not deploy with Development |
| `AllowedHosts` | `api.example.com` | Required; semicolon-separated host names, no scheme, port or wildcard |
| `ConnectionStrings__DefaultConnection` | `<production-sql-server-connection-string>` | Required secret; encrypted SQL Server connection with certificate validation |
| `Jwt__Key` | `<random-signing-key-at-least-32-bytes>` | Required secret; same key on every replica |
| `Jwt__Issuer` | `AsliApp.Api` | Production template default; identifies this token issuer |
| `Jwt__Audience` | `AsliApp.Mobile` | Production template default; identifies the intended client |
| `Jwt__ExpirationMinutes` | `15` | Access token lifetime; positive minutes |
| `Jwt__RefreshTokenExpirationDays` | `30` | Refresh token lifetime; positive days |
| `FileStorage__RootPath` | `App_Data\asliapp-storage` | Production default for Turhost/Plesk; override only when the host provides a writable persistent absolute path |
| `FileStorage__MaxFileSizeBytes` | `26214400` | Maximum file size: 25 MiB per file |
| `ASPNETCORE_URLS` | `http://127.0.0.1:5218` | Private Kestrel listener behind a same-host proxy; adjust to deployment network |
| `ReverseProxy__KnownProxies__0` | `<trusted-proxy-IP-address>` | Required for a non-loopback proxy; add indexes 1, 2, etc. for alternative upstreams |
| `Gmail__Address` | `<smtp-sender-address>` | Required for verification/password-reset email |
| `Gmail__AppPassword` | `<smtp-app-password>` | Required secret; existing SMTP integration uses Gmail with STARTTLS |
| `PushNotifications__Enabled` | `false` | Set true only after Firebase credentials are provisioned |
| `PushNotifications__FirebaseCredentialPath` | `<absolute-secret-file-path>` | When push enabled, mount a protected service-account file outside the repository |
| `PushNotifications__FirebaseCredentialJson` | `<service-account-json-secret>` | Alternative to the credential file; use one credential source |
| `AdminBootstrap__Email` | `<initial-admin-email>` | Optional first-admin provisioning |
| `AdminBootstrap__Password` | `<strong-initial-admin-password>` | Optional secret paired with Email; remove bootstrap settings after provisioning |
| `AdminBootstrap__FirstName`, `AdminBootstrap__LastName` | `<display-name>` | Optional bootstrap display names |

Do not reuse development signing keys or database credentials. Changing issuer,
audience or signing key invalidates existing access tokens. Use an established
issuer/audience consistently across deployments. Remember-me controls client-side
refresh token persistence; both remembered and current-session device logins can refresh.

## HTTPS and reverse proxy

Terminate TLS with a valid certificate at Nginx, IIS or the load balancer; redirect
public HTTP to HTTPS there. Restrict Kestrel access to the proxy/private probe network.
Preserve the original `Host`, overwrite `X-Forwarded-Proto` with the external scheme,
and forward `X-Forwarded-For`. The API processes these headers before authentication
and HTTPS redirection, trusts loopback and explicitly configured proxy IPs, and
accepts one proxy hop. A chain of proxies must be reviewed/configured separately.
Do not enable `ASPNETCORE_FORWARDEDHEADERS_ENABLED` or
`DOTNET_FORWARDEDHEADERS_ENABLED`; those switches bypass this restricted trust setup.
See [Microsoft reverse proxy guidance](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/proxy-load-balancer?view=aspnetcore-10.0).

Production requests use HTTPS redirection and HSTS. `/health` remains accessible
over the private HTTP listener for liveness checks and returns `{"status":"Healthy"}`;
it does not check SQL Server readiness. The host allow-list also applies to probes:
send an allowed Host header. Never expose the private HTTP listener publicly.

Grant IIS read/write access to `App_Data\asliapp-storage`; persist and back up
media with the database. Kestrel/multipart body limits allow the configured
file size plus 64 KiB overhead; configure proxy/IIS request limits to at least this
size (26279936 bytes with the default). File validation still enforces 25 MiB per file.
Persist/protect ASP.NET Core Data Protection keys using the hosting platform's shared
key-store facilities for replicated/replaced instances.

## Build and deploy

```powershell
cd backend
dotnet build AsliApp.sln -c Release
dotnet test AsliApp.sln -c Release
dotnet publish src/AsliApp.Api -c Release -o <deployment-artifact-directory>
```

Apply reviewed EF migrations as a separate deployment step against the explicitly
selected production database (back up first). The API never migrates/creates a
production database at startup. Development education seeding runs only when
`IsDevelopment()` is true. Admin bootstrap is a separate, explicitly configured workflow.
After a lesson has multiple quizzes, rolling back
`SupportMultipleQuizzesPerLesson` cannot restore the former one-quiz uniqueness
constraint without first resolving those extra rows.
Launch the published API with the environment above; do not use development launch
profiles. Verify HTTPS `/health`, login/refresh, and authenticated media upload/download.

## Flutter release

The API URL is public configuration, not a secret. Release defaults to
`https://api.nursing-app.com`. An override fails before service initialization
if it is not HTTPS, includes credentials/query/fragment, or targets
localhost/emulator/loopback. Debug retains local defaults.

```powershell
cd mobile
flutter analyze
flutter test
flutter build appbundle --release
# On macOS for iOS:
flutter build ipa --release
```

Static analysis does not run release startup; URL tests explicitly exercise release
validation. Smoke-test the actual artifact.
Provision signing credentials outside source control (Android uses ignored
`android/key.properties`). Configure platform Firebase files separately; never embed
server service-account credentials in Flutter. No deployment is performed by these steps.
