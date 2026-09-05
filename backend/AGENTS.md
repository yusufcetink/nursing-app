# Backend Development Rules

These rules apply to the .NET backend under `backend/` in addition to the repository root rules.

## Technology and boundaries

- Target .NET 10 and ASP.NET Core Web API.
- Use EF Core with the SQL Server provider.
- `AsliApp.Domain` contains domain entities and enums and must not depend on API or infrastructure.
- `AsliApp.Infrastructure` contains EF Core persistence and depends on Domain.
- `AsliApp.Api` is the composition/HTTP boundary and may depend on Domain and Infrastructure.
- Add abstractions only when a concrete use case requires them.

## API and persistence

- Keep endpoints explicit, small, and free of persistence implementation details.
- Use typed request/response models when endpoints are introduced.
- Keep EF configuration in `AppDbContext` or focused configuration classes when complexity justifies extraction.
- Treat migrations as source code; generate them with the repository-local `dotnet-ef` tool and review them.
- Use UTC timestamps and typed enums. Add indexes and constraints intentionally.
- Do not add auth, JWT, email verification, or CRUD endpoints unless explicitly requested.

## Security and data

- Never commit connection strings, credentials, tokens, or secrets.
- Read the SQL Server connection from environment variables or an external configuration provider.
- Do not log sensitive, personal, authentication, or educational interaction data.
- Collect and retain only data required by the product and research purpose.

## Quality

- Enable nullable reference types and keep warnings actionable.
- Add tests for domain rules and endpoint/persistence behavior when those behaviors are introduced.
- Before completion, run `dotnet build` and `dotnet test` from `backend/`.
