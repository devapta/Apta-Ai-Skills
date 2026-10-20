# PR review checklist

For the reviewer. Go top to bottom. A PR should pass every relevant section. If something fails, put its number in the review comment.

## A. Automated gates (check before reading the code)

1. `fvm flutter analyze` shows no new warnings.
2. `fvm flutter test` is green, and the PR adds tests for new logic.
3. `*.g.dart` files are committed when a model changed (`dart run build_runner build --delete-conflicting-outputs`).
4. `.env`, keys, and out-of-scope files are not committed.
5. The PR is small and has one purpose. If it is more than ~400 lines of real change, ask for it to be split.

## B. Architecture

6. Dependency flow is `Screen -> Provider -> Repository -> ApiService`. No `Dio`/ApiService/`SharedPreferences` is called directly from a screen.
7. Repositories are abstract classes registered in `service_locator.dart`. Methods return `ApiResponse<T>` and do not throw to the UI.
8. Endpoint paths are in `services/endpoints.dart`, not hardcoded in a service.
9. Hardware is accessed through interfaces. Nothing imports a device package (`dart_pcsc`, `flutter_libserialport`, a camera/OCR SDK) outside its implementation.
10. Hardware interfaces are unchanged. If they changed, there is explicit approval from the reviewer.
11. Folder structure follows `features/<name>/{models,services}`. No new file is in the wrong place.
12. No new library in `pubspec.yaml` without a reason. Exceptions are explained in the PR.

## C. Code quality

13. `build()` does not call an API or start heavy work. `watch` is used to rebuild, `read` for actions.
14. `StreamSubscription`, `Timer`, `StreamController`, and `ChangeNotifier` are disposed/cancelled.
15. `BuildContext` use after an `await` is guarded with `context.mounted`.
16. No hardcoded UI text. Strings are in the arb files.
17. No comments that explain what the code already says. No dead code or leftover debug `print`.
18. Loading, empty, and error states are all handled on the screen (per the design).

## D. Hardware and networking

19. Values that must come from a device are read-only in the UI, and submit is blocked until the device reports a valid (e.g. stable) reading.
20. When the server is unreachable, the app shows a clear error and blocks the action; no silent failure or hang.
21. A submit that times out does not create a duplicate record. Check the record's state before resending.
22. The serial Isolate worker and native cleanup (`SerialPortConfig.dispose()`, closing the port) are not changed without strong reason.
23. For NFC, the order of direct `connect` first, then `waitForCard` fallback, is kept.
24. `.env` has no new keys without agreement. Fake hardware is selected with `--dart-define`, never `.env`.
25. A PR that touches hardware includes manual test notes: device not recognized, device removed mid-operation, cable unplugged, server down during submit.

## E. Project-specific rules

Add the project's own rules here (domain rules from its PRD, backend contract details, layout/orientation constraints). Keep them in the project repo rather than in this skill.

## F. Review comment template

Use this format so contributors know what to fix and how much it matters:

- **[must]** must be fixed before merge (cite the checklist number).
- **[suggest]** may be fixed, does not block the merge.
- **[ask]** the reviewer does not understand the intent, asks for an explanation.
