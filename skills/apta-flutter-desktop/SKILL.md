---
name: apta-flutter-desktop
description: Standard for building Apta Flutter Desktop apps (Linux & Windows). Use when starting a new Flutter desktop project, adding a feature/screen/service, wiring a REST API (Dio + get_it + Provider + forui), integrating hardware (serial port, NFC reader, camera) behind fake/real interfaces, discovering a LAN server over mDNS, or preparing Windows/Linux release builds and PR reviews.
---

# Flutter Desktop App standard

Opinionated layout for Flutter Desktop apps that talk to a REST backend, optionally drive local hardware, and ship as a Windows installer and a Linux bundle. Follow it as written; if a rule does not fit, raise it with the reviewer instead of working around it.

## Core rules

1. **One-way dependencies**: `Screen -> Provider -> Repository (abstract) -> ApiService (Dio)`. A screen never calls Dio or an ApiService directly.
2. **Repositories are always abstract classes**, resolved through `get_it` (`sl<XRepository>()`). The implementation is `XApiService implements XRepository`.
3. **Repositories never throw to the UI.** Every method returns `ApiResponse<T>` (`success` or `failure(String)`).
4. **Hardware sits behind interfaces** (e.g. `NfcService`, `ScaleService`, `OcrService`), each with a `Fake` and a `Real` implementation. The UI only knows the interface. Details in `references/hardware-services.md`.
5. **Models use `json_serializable`**, and the `.g.dart` files are committed. Run `dart run build_runner build --delete-conflicting-outputs`.
6. **No hardcoded UI strings.** All text goes through l10n (`app_en.arb` plus one arb per extra locale).
7. **Flutter version is pinned with FVM** (`.fvmrc` with an exact version, e.g. `3.47.0`). Every command uses `fvm flutter ...`.

## Creating a new project

```bash
fvm install 3.47.0 && fvm use 3.47.0
fvm flutter create --platforms=linux,windows --org id.apta <project_name>
```

Then:

1. Replace `analysis_options.yaml`:
   ```yaml
   include: package:flutter_lints/flutter.yaml

   analyzer:
     exclude: [build/**, android/**, ios/**, web/**, windows/**, macos/**, linux/**]

   formatter:
     page_width: 200
     trailing_commas: automate
   ```
2. Add dependencies (re-check versions with `fvm flutter pub outdated`):
   ```yaml
   dependencies:
     material_ui: ^1.4.0
     forui: ^0.27.0
     forui_lucide: ^0.27.0
     provider: ^6.1.5+1
     get_it: ^9.2.1
     dio: ^5.9.2
     talker_dio_logger: ^5.1.19
     json_annotation: ^4.12.0
     flutter_dotenv: ^6.0.1
     shared_preferences: ^2.2.1
     intl: ^0.20.2
     flutter_localizations: { sdk: flutter }
     flutter_svg: ^2.0.17
     path_provider: ^2.1.2
     flutter_single_instance: ^1.7.0
     bitsdojo_window: ^0.1.6          # custom window/title bar, optional
     multicast_dns: ^0.3.3+1          # only if discovering the server over mDNS
     flutter_libserialport: ^0.6.0    # only for serial devices
     dart_pcsc: ^2.0.2                # only for PC/SC NFC readers
   dev_dependencies:
     flutter_lints: ^6.0.0
     json_serializable: ^6.14.0
     build_runner: ^2.15.1
     checks: ^0.3.1
   ```
3. In `pubspec.yaml` register the `.env` asset, the `assets/` folders, the app font, and `flutter: generate: true`.
4. Create `l10n.yaml` (arb-dir `lib/l10n`, template `app_en.arb`, output `lib/l10n/generated`).
5. Create `.env` and `.env.example`; `.env` is not committed. Convention: `BASE_URL` (a URL, or `auto` for mDNS discovery) and `BASE_URL_FALLBACK`. Do not add keys casually.
6. Create the folder structure (below) and `main.dart` following the startup order.

## Folder structure

```
lib/
  main.dart                  # startup order (see below)
  app.dart                   # MultiProvider + MaterialApp + FTheme
  core/
    di/service_locator.dart  # get_it, all registrations live here
    network/                 # api_client, api_response, dio_exception, interceptor
    widgets/                 # shared widgets
    utils/
  features/<feature_name>/
    models/                  # *.dart + *.g.dart, plus a models.dart barrel
    services/                # x_repository.dart (abstract) + x_api_service.dart
  providers/                 # one ChangeNotifier per area, providers.dart (list)
  services/                  # endpoints, api_discovery, local_storage, formatters
  screens/                   # per screen/menu, screens.dart (barrel)
  theme/theme.dart
  l10n/
docs/adr/                    # architecture decision records
test/                        # mirrors the lib/ structure
```

Hardware features follow the same pattern: `features/<device>/` with an abstract `*_service.dart`, a `fake_*_service.dart`, and a `*_service_impl.dart`.

## `main.dart` startup order

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!await FlutterSingleInstance().isFirstInstance()) {
    await FlutterSingleInstance().focus();
    exit(0);
  }

  await dotenv.load(fileName: '.env');

  if (dotenv.env['BASE_URL'] == 'auto') {
    final fallbackUrl = dotenv.env['BASE_URL_FALLBACK'] ?? '';
    Endpoints.baseURL = await ApiDiscoveryService.getApiBaseUrl(fallbackUrl: fallbackUrl);
    if (ApiDiscoveryService.serverNotFound) ApiDiscoveryService.startBackgroundRetry(fallbackUrl);
  } else {
    Endpoints.baseURL = dotenv.env['BASE_URL'] ?? '';
  }

  initServiceLocator(); // after baseURL is known: ApiClient reads it on creation

  runApp(const MainApp());

  doWhenWindowReady(() {          // bitsdojo_window; skip if not used
    appWindow
      ..minSize = const Size(1024, 640)
      ..size = const Size(1280, 720)
      ..alignment = Alignment.center
      ..title = 'App name'
      ..show();
  });
}
```

- The single-instance check keeps the app from opening twice. It matters most for kiosk-style apps.
- Skip the mDNS branch if the app uses a fixed URL. Discovery details are in `references/hardware-services.md`.
- Window sizes are defaults; set them from the design (a portrait kiosk needs different values).

## Adding a feature (working order)

1. Write the model + `.g.dart` and the `models.dart` barrel.
2. Write `x_repository.dart` (abstract), then `x_api_service.dart`. Add endpoints in `services/endpoints.dart` (never hardcode paths in a service).
3. Register in `service_locator.dart`: `sl.registerLazySingleton<XRepository>(() => XApiService(dio: sl<ApiClient>().dio))`.
4. Create the provider in `providers/` and register it in `providers.dart`.
5. Create the screen in `screens/` and export it from `screens.dart`.
6. Add the strings to the arb files and run `fvm flutter gen-l10n`.
7. Write tests (at least provider + model). Run `fvm flutter analyze` and `fvm flutter test`.

Code templates are in `references/architecture.md`.

## UI and theme

- Components come from `forui` (`FButton`, `FToaster`, `FTheme`, ...), wrapped in a `MaterialApp` from `material_ui`. Use one app font registered in `pubspec.yaml`, and an off-white background (e.g. `#FFFFFA`) instead of pure white.
- Build the theme from `FTheme.neutral.light.desktop` / `.dark.desktop` in `theme/theme.dart`, with a small enum of primary colors if the app offers a choice.
- Desktop defaults to mouse input (`touch: false` in the forui theme data and button styles). For a touchscreen app use the touch variant with larger targets.
- Follow the design file (Pencil/Figma) for sizes and layout; do not guess.

## Auth (only if the app has a login)

- Token injection and 401 handling belong in a Dio interceptor, but the interceptor must not depend on UI (`Navigator`, `BuildContext`, `Provider`). Give it a small token-store and a callback (e.g. `onUnauthorized`) that the app wires up at startup.
- Apps without login (e.g. kiosks, apps behind a trusted local service) need no interceptor beyond logging.

## Build and release

Details in `references/build-release.md`. In short: Windows through `build.ps1` + Inno Setup (templates in `assets/windows/`: `build.ps1`, `installer.iss`), Linux through Docker (Ubuntu 22.04, templates in `assets/linux/`: `Dockerfile.linux`, `build-ubuntu.sh`) using the Flutter version from `.fvmrc`.

## References

- `references/architecture.md`: Model, Repository, ApiService, Provider, DI, and test templates.
- `references/hardware-services.md`: device interfaces and fakes, serial worker, NFC over PC/SC, mDNS discovery.
- `references/review-checklist.md`: PR review checklist (for the reviewer).
- `references/build-release.md`: Windows and Linux builds, native dependencies, target machine setup.
