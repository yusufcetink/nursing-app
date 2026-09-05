# Mobile Development Rules

These rules apply to the Flutter application under `mobile/` in addition to the repository root rules.

## Technology and structure

- Use Flutter, Dart, Material 3, Riverpod, go_router, and Dio.
- Keep the existing feature-first structure under `lib/app`, `lib/core`, `lib/features`, and `lib/shared`.
- Create only layers that provide a real boundary. Repository, data source, use case, service, and interface layers are optional.
- Keep the dependency flow as UI → Provider/Controller → Repository (when needed) → Data Source/API Client (when needed).
- Do not place business rules or HTTP implementation details in widgets.

## State and navigation

- Use Riverpod providers/controllers for shared or business state; keep trivial local UI state local.
- Do not use global mutable state or introduce a second state-management solution.
- Keep routes centralized in the existing go_router configuration.
- Preserve Android and iOS behavior and avoid native changes unless Flutter cannot solve the requirement.

## Networking and configuration

- Use the shared Dio API client; do not create Dio instances in features or widgets.
- Keep base URLs and environment values in centralized configuration.
- Never embed API keys, tokens, passwords, or provider credentials in the application.
- Any future AI-backed clinical simulation must call the backend. The product has no general AI Tutor/chat feature.

## UI

- Use the centralized light/dark design system and `Theme.of(context)`.
- Keep layouts responsive, accessible, and suitable for Android and iOS.
- Reuse shared widgets only after genuine cross-feature reuse exists.
- Prefer focused widgets and const constructors.

## Quality

- Keep models typed and immutable when practical.
- Add unit/provider/widget tests for meaningful behavior.
- Before completion, run `dart format .`, `flutter analyze`, and `flutter test` from `mobile/`.
