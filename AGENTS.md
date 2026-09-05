# AGENTS.md

## Project overview

Aslı App is a monorepo for a mobile education product focused on lessons, quizzes, progress, authentication, and profiles.

The repository contains:

```text
mobile/   Flutter application for Android and iOS
backend/  .NET 10 ASP.NET Core backend
docs/     Cross-project documentation
```

The product has no general AI Tutor/chat feature. A separate `clinical_simulation` feature may be introduced later for patient-nurse dialogue simulations, but it is not implemented now.

## Scope and architecture

- Read this file and the nearest nested `AGENTS.md` before changing code.
- Keep changes focused on the requested scope and preserve existing behavior unless explicitly changed.
- Prefer clear, pragmatic, testable code over speculative abstractions.
- Respect project boundaries; mobile and backend communicate through explicit API contracts when integration is introduced.
- Do not add features, packages, services, or architectural layers without a concrete need.
- Do not manually edit generated files; use the owning tool and review its output.

## Data, privacy, and security

- Collect only data necessary for the intended learning or research purpose.
- Avoid unnecessary personal data and use participant identifiers where practical.
- Keep quiz, progress, session, and future simulation interaction data structured and auditable.
- Never commit or log passwords, connection strings, API keys, tokens, credentials, or other secrets.
- Keep logging outside UI code and do not expose internal errors or stack traces to users.
- Do not treat generated content as medical diagnosis or treatment advice.
- Do not add analytics or tracking unless explicitly requested.

## Working rules

- Inspect the relevant implementation before editing and reuse established patterns.
- Make the smallest coherent change and avoid unrelated refactors or renames.
- Keep models typed; avoid loosely typed data outside serialization boundaries.
- Handle errors intentionally and do not swallow exceptions.
- Add meaningful tests for business rules, state transitions, and regressions.
- Do not commit build output, IDE state, local configuration, secrets, or operating-system files.

## Completion

Run the checks required by each changed project and fix issues introduced by the task. Summaries should state what changed, key decisions, files/areas affected, checks performed, and remaining setup or follow-up.
