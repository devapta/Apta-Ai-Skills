# Apta Flutter Desktop rules

Applies to Apta Flutter Desktop apps (Linux & Windows). The `apta-flutter-desktop` skill has full templates and references; without the skill, follow these rules by hand.

## Layering
- One-way dependencies: `Screen -> Provider -> Repository (abstract) -> ApiService (Dio)`. A screen never calls Dio, an ApiService, or `SharedPreferences` directly.
- Repository = abstract class, registered in `core/di/service_locator.dart` (get_it, `registerLazySingleton`). Implementation is `XApiService implements XRepository`.
- Every repository method returns `ApiResponse<T>` (`success`/`failure(String)`) and never throws to the UI. Two `catch` blocks: `DioException` through `DioExceptionHandler`, then `catch (e)`.
- Endpoint paths live only in `services/endpoints.dart`. Match trailing slashes to the API contract.
- Provider: one `ChangeNotifier` per area, `part of 'providers.dart'`, repository injectable through the constructor (`repository ?? sl<...>()`).

## Structure
`lib/{core,features/<name>/{models,services},providers,services,screens,theme,l10n}`. Models use `json_serializable` (`.g.dart` committed, `dart run build_runner build --delete-conflicting-outputs`). UI text only through l10n. Flutter is pinned in `.fvmrc`; every command is `fvm flutter ...`. `.env` holds `BASE_URL` (URL or `auto`) and `BASE_URL_FALLBACK`; no other keys without agreement.

## Startup (`main.dart`)
`ensureInitialized` -> `FlutterSingleInstance` (a second instance calls `exit(0)`) -> `dotenv.load` -> if `BASE_URL == 'auto'` run mDNS discovery with `BASE_URL_FALLBACK` as fallback, else use `BASE_URL` -> `initServiceLocator()` -> `runApp`.

## Hardware
- Devices (NFC, serial, camera/OCR) are reached only through interfaces, each with a `Fake` and a real implementation. Pick fakes with `--dart-define=FAKE_HARDWARE=true`, not `.env`. Release builds must not use fakes.
- Serial: `flutter_libserialport` in a background Isolate, single operation queue, stability = N identical readings, native cleanup on disconnect, batched UI notifications. Values that must come from the device stay read-only.
- NFC (PC/SC): UID via `FF CA 00 00 00`; direct `connect` first, `waitForCard` fallback (it can hang). Do not store secrets on MIFARE Classic.
- mDNS: Windows needs `reusePort: false` and a non-loopback IPv4 `interfacesFactory`. Resolve stored URL -> mDNS -> fallback, retry in the background.

## Tests and build
`flutter_test` + the `checks` package (`check(finder.evaluate().length).equals(n)` for widgets); hand-written fakes through the constructor, no mockito/mocktail. If official Flutter/Dart skills disagree (`http`, `expect`, mocks, `synthetic-package`, `go_router`, MVVM service layer), follow these rules. `fvm flutter analyze` and `test` must be clean. Windows: `build.ps1` + Inno Setup. Linux: Docker Ubuntu 22.04, Flutter version read from `.fvmrc`. Never ship a build with fake hardware.
