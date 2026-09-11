# Aslı App Mobile

Flutter client for Aslı App. It provides lessons, quizzes, progress tracking,
authentication, profiles, content management, and Admin-only user management.

Run locally with `flutter pub get` followed by `flutter run`. Use
`--dart-define=API_BASE_URL=<url>` to override the debug API URL.

## Learning interface

The login, home, module roadmap, lesson, quiz, result, and profile screens share
the warm ivory / plum / lavender design system in `lib/app/theme/`.
Manrope is bundled locally under the SIL Open Font License in
`assets/fonts/OFL.txt`. Decorative illustrations are local transparent assets;
all text, controls, progress, and navigation are native Flutter widgets.

The home recommendation uses unfinished module progress. Profile activity and
badges derive from completed lessons and submitted quizzes; sample values from
the design references are not used in production. Existing role-based content
and user management remain available.

Run `dart format .`, `flutter analyze`, and `flutter test` before shipping.
To regenerate actual Flutter screen previews for visual review, run:

```powershell
flutter test test/design_layout_test.dart --dart-define=CAPTURE_DESIGN=true
```

The previews are written to the ignored `build/design-preview/` directory.
The layout test covers seven screens in light and dark themes at 390 px and
at 320 px with text scaled to 160%. It uses test repositories, never real users.
