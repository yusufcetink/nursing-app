# Aslı App

Aslı App is a mobile education product for structured lessons, quizzes, learning
progress, secure authentication, profiles, content management, and user-role
administration.

## Structure

- `mobile/` — Flutter application for Android and iOS
- `backend/` — .NET 10 ASP.NET Core API with Identity, EF Core, and SQL Server
- `docs/` — cross-project documentation

## Run locally

Install Flutter, the .NET 10 SDK, and SQL Server or SQL Server LocalDB. Configure
backend secrets outside source control:

```powershell
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "<connection-string>" --project backend/src/AsliApp.Api
dotnet user-secrets set "Jwt:Key" "<at-least-32-byte-signing-key>" --project backend/src/AsliApp.Api
```

Start the API and mobile client in separate terminals:

```powershell
cd backend
dotnet run --project src/AsliApp.Api

cd ../mobile
flutter pub get
flutter run
```

Android emulators use `http://10.0.2.2:5218` by default; other debug targets use
`http://127.0.0.1:5218`. Override with
`--dart-define=API_BASE_URL=<url>` when needed.
