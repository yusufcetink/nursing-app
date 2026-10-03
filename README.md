# Aslı App

Production configuration and deployment: [deployment guide](docs/deployment.md).

## Local development and CI

The backend needs a local SQL Server connection string and JWT signing key in
environment variables or .NET user-secrets. From `backend/`, run
`dotnet run --project src/AsliApp.Api --launch-profile http`; the API listens on
`http://localhost:5218`. Run the Flutter app from `mobile/` with `flutter run`.
On the Android emulator, its debug API URL is `http://10.0.2.2:5218`.
See the project READMEs for database and Firebase setup.

Every push to `main` and every pull request runs backend build/tests and Flutter
analysis/tests through [GitHub Actions](.github/workflows/ci.yml). These checks
need no production credentials and do not deploy. Keep release signing, Firebase
configuration, database credentials, and deployment secrets outside Git.

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
