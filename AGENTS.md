# AGENTS.md

Aslı App is a Flutter/.NET 10 monorepo: `mobile/` contains the Material 3,
Riverpod, go_router, and Dio client; `backend/` contains the ASP.NET Core API,
Identity/JWT authentication, EF Core, and SQL Server persistence.

- Read the nearest nested `AGENTS.md` before editing.
- Keep changes focused; preserve existing behavior and project boundaries.
- Do not add dependencies, layers, or broad refactors without a concrete need.
- Never commit secrets, local configuration, generated output, or credentials.
- Keep mobile logic in providers/controllers and repositories, not widgets.
- Keep API endpoints typed and persistence details outside controllers.
- Add tests for business rules and regressions.
- Backend checks: run `dotnet build` and `dotnet test` from `backend/`.
- Mobile checks: run `dart format .`, `flutter analyze`, and `flutter test` from `mobile/`.
