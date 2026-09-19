# AI Rules for Flutter

## Persona & Tools
* **Role:** Expert Flutter Developer. Focus: Beautiful, performant, maintainable code.
* **Explanation:** Explain Dart features (null safety, streams, futures) for new users.
* **Tools:** ALWAYS run `dart_format`. Use `dart_fix` for cleanups. Use `analyze_files` with `flutter_lints` to catch errors early.
* **Dependencies:** Add with `flutter pub add`. Use `pub_dev_search` for discovery. Explain why a package is needed.

## Architecture & Structure
* **Entry:** Standard `lib/main.dart`.
* **Layers:** Presentation (Widgets), Domain (Logic), Data (Repo/API).
* **Features:** Group by feature (e.g., `lib/features/login/`) for scalable apps.
* **SOLID:** Strictly enforced.
* **State Management:**
  * **Pattern:** Separate UI state (ephemeral) from App state.
  * **Native First:** Use `ValueNotifier`, `ChangeNotifier`.
  * **Prohibited:** NO Riverpod, Bloc, GetX unless explicitly requested.
  * **DI:** Manual constructor injection or `provider` package if requested.

## Code Style & Quality
* **Naming:** `PascalCase` (Types), `camelCase` (Members), `snake_case` (Files).
* **Conciseness:** Functions <20 lines. Avoid verbosity.
* **Null Safety:** NO `!` operator. Use `?` and flow analysis (e.g. `if (x != null)`).
* **Async:** Use `async/await` for Futures. Catch all errors with `try-catch`.
* **Logging:** Use `dart:developer` `log()` locally. NEVER use `print`.

## Flutter Best Practices
* **Build Methods:** Keep pure and fast. No side effects. No network calls.
* **Isolates:** Use `compute()` for heavy tasks like JSON parsing.
* **Lists:** `ListView.builder` or `SliverList` for performance.
* **Immutability:** `const` constructors everywhere validation. `StatelessWidget` preference.
* **Composition:** Break complex builds into private `class MyWidget extends StatelessWidget`.

## Routing (GoRouter)
Use `go_router` exclusively for deep linking and web support.

```dart
final _router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => Home()),
  GoRoute(path: 'details/:id', builder: (_, s) => Detail(id: s.pathParameters['id']!)),
]);
MaterialApp.router(routerConfig: _router);
```

## Data (JSON)
Use `json_serializable` with `fieldRename: FieldRename.snake`.

```dart
@JsonSerializable(fieldRename: FieldRename.snake)
class User {
  final String name;
  User({required this.name});
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

## Visual Design (Material 3)
* **Aesthetics:** Premium, custom look. "Wow" the user. Avoid default blue.
* **Theme:** Use `ThemeData` with `ColorScheme.fromSeed`.
* **Modes:** Support Light & Dark modes (`ThemeMode.system`).
* **Typography:** `google_fonts`. Define a consistent Type Scale.
* **Layout:** `LayoutBuilder` for responsiveness. `OverlayPortal` for popups.
* **Components:** Use `ThemeExtension` for custom tokens (colors/sizes).

## Testing
* **Tools:** `flutter test` (Unit), `flutter_test` (Widget), `integration_test` (E2E).
* **Mocks:** Prefer Fakes. Use `mockito` sparingly.
* **Pattern:** Arrange-Act-Assert.
* **Assertions:** Use `package:checks`.

## Accessibility (A11Y)
* **Contrast:** 4.5:1 minimum for text.
* **Semantics:** Label all interactive elements specifically.
* **Scale:** Test dynamic font sizes (up to 200%).
* **Screen Readers:** Verify with TalkBack/VoiceOver.

## Commands Reference
* **Build Runner:** `dart run build_runner build --delete-conflicting-outputs`
* **Test:** `flutter test .`
* **Analyze:** `flutter analyze .`



Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## Release Process

For **every release**, updating release metadata is mandatory and must be part of the same release change:
- Bump the application version/build in `pubspec.yaml` and `lib/version.dart`.
- Add the new release section to `CHANGELOG.md`.
- Update the public website release information and changelog in `docs/index.html`, `docs/index.md`, `docs/index.ru.md`, and `docs/index.uk.md`.
- Update `docs/llms.txt` so its current stable version and release summary match the new release.
- Keep historical release entries intact; add a new latest entry instead of rewriting old release history.
- Before publishing, verify that the GitHub Release notes, `CHANGELOG.md`, and website describe the same version and changes.

