# Architecture and code templates

Replace `Foo` with the feature name and `app_name` with the project's package name.

## 0. Project tree

```
<project>/
├── .env                          # BASE_URL, BASE_URL_FALLBACK (not committed)
├── .env.example
├── .fvmrc                        # pinned Flutter version
├── analysis_options.yaml
├── l10n.yaml
├── pubspec.yaml
├── build.ps1                     # Windows: build + Inno Setup
├── <app>-setup.iss
├── Dockerfile.linux              # Linux: Ubuntu 22.04 build
├── build-ubuntu.sh
├── assets/
│   ├── fonts/
│   ├── images/
│   └── logos/
├── docs/
│   └── adr/
│       └── 0001-<decision>.md
├── linux/  windows/              # generated platform folders
├── test/                         # mirrors lib/
│   ├── features/
│   ├── providers/
│   └── screens/
└── lib/
    ├── main.dart                 # startup order
    ├── app.dart                  # MultiProvider + MaterialApp + FTheme
    │
    ├── core/                     # app-wide plumbing, knows nothing about features
    │   ├── di/
    │   │   └── service_locator.dart
    │   ├── network/
    │   │   ├── api_client.dart
    │   │   ├── api_response.dart
    │   │   ├── api_interceptor.dart
    │   │   ├── dio_exception.dart
    │   │   └── network.dart      # barrel
    │   ├── widgets/              # shared widgets + widgets.dart barrel
    │   └── utils/
    │
    ├── features/                 # one folder per domain feature or device
    │   ├── foo/
    │   │   ├── models/
    │   │   │   ├── foo_model.dart
    │   │   │   ├── foo_model.g.dart
    │   │   │   ├── create_foo_request.dart
    │   │   │   └── models.dart   # barrel
    │   │   └── services/
    │   │       ├── foo_repository.dart    # abstract
    │   │       └── foo_api_service.dart   # implements FooRepository
    │   ├── nfc/                  # device feature: same idea, no models/services split
    │   │   ├── nfc_service.dart           # abstract
    │   │   ├── fake_nfc_service.dart
    │   │   └── nfc_service_impl.dart      # only file that imports dart_pcsc
    │   └── scale/
    │       ├── scale_service.dart
    │       ├── fake_scale_service.dart
    │       ├── scale_service_impl.dart
    │       └── scale_worker.dart          # background Isolate
    │
    ├── providers/                # state (ChangeNotifier), one per area
    │   ├── providers.dart        # imports + `part` list + provider list
    │   ├── foo_provider.dart
    │   └── settings_provider.dart
    │
    ├── services/                 # app-level services (not tied to one feature)
    │   ├── endpoints.dart        # baseURL, timeouts, every path
    │   ├── api_discovery_service.dart
    │   ├── local_storage_service.dart
    │   └── services.dart         # barrel
    │
    ├── screens/                  # UI only
    │   ├── screens.dart          # barrel
    │   ├── splash/
    │   │   └── splash_screen.dart
    │   └── main/
    │       ├── main_screen.dart
    │       └── foo/
    │           └── foo_menu.dart
    │
    ├── theme/
    │   └── theme.dart
    │
    └── l10n/
        ├── app_en.arb            # template
        ├── app_id.arb            # extra locale
        └── generated/            # output of `fvm flutter gen-l10n`
```

Who may import whom (arrows point to what a layer is allowed to import):

| Layer | May import | Must not import |
| --- | --- | --- |
| `screens/` | `providers/`, `core/widgets/`, `theme/`, `l10n/`, `features/*/models/` (to display) | `features/*/services/`, `Dio`, `SharedPreferences`, any device package |
| `providers/` | `features/*/services/` (abstract repository or service interface), `features/*/models/`, `services/`, `core/di/` | `screens/`, `Dio`, device packages |
| `features/*/services/` (`*_api_service.dart`) | `features/*/models/`, `core/network/`, `services/endpoints.dart` | `providers/`, `screens/` |
| `features/<device>/*_impl.dart` | its device package (`dart_pcsc`, `flutter_libserialport`, SDK) | `providers/`, `screens/` |
| `features/*/models/` | `json_annotation` only | everything else |
| `core/` | other `core/` files, `services/` | `features/*`, `providers/`, `screens/` (an interceptor that imports `Navigator` or `Provider` breaks this rule) |

Conventions:
- A folder with several public files gets a barrel (`models.dart`, `services.dart`, `widgets.dart`, `screens.dart`); other code imports the barrel, not individual files.
- File names are `snake_case`; the suffix says the role (`_model`, `_repository`, `_api_service`, `_provider`, `_screen`, `_menu`, `_service_impl`).
- A new feature adds a `features/<name>/` folder, a line in `service_locator.dart`, a provider, and a screen; it should not need edits inside other features.

## 1. Model

`@JsonSerializable(createFactory: false)` generates `toJson`; `fromJson` is written by hand.

```dart
import 'package:json_annotation/json_annotation.dart';

part 'foo_model.g.dart';

@JsonSerializable(createFactory: false)
class FooModel {
  final int id;
  final String name;

  const FooModel({required this.id, required this.name});

  factory FooModel.fromJson(Map<String, dynamic> json) {
    return FooModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => _$FooModelToJson(this);
}
```

- Write the keys exactly as the API returns them (verify against a real response, not just the docs). Only accept alternate key casings (`ID`/`id`) when the backend is genuinely inconsistent, and say so in a comment.
- Every `models/` folder has a `models.dart` that exports all its models.

## 2. Repository (contract) and ApiService (implementation)

```dart
// features/foo/services/foo_repository.dart
import 'package:app_name/core/network/api_response.dart';
import 'package:app_name/features/foo/models/models.dart';

abstract class FooRepository {
  Future<ApiResponse<List<FooModel>>> getFoos({String? filters});
  Future<ApiResponse<int>> createFoo(CreateFooRequest request);
}
```

```dart
// features/foo/services/foo_api_service.dart
import 'package:dio/dio.dart';
import 'package:app_name/core/network/api_response.dart';
import 'package:app_name/core/network/dio_exception.dart';
import 'package:app_name/services/endpoints.dart';

class FooApiService implements FooRepository {
  final Dio _dio;
  FooApiService({required Dio dio}) : _dio = dio;

  @override
  Future<ApiResponse<List<FooModel>>> getFoos({String? filters}) async {
    try {
      final response = await _dio.get(
        Endpoints.foos,
        queryParameters: {if (filters != null && filters.isNotEmpty) 'filters': filters},
      );
      // adjust to the backend response shape
      final items = (response.data['items'] as List).cast<Map<String, dynamic>>();
      return ApiResponse.success(items.map(FooModel.fromJson).toList());
    } on DioException catch (e) {
      return ApiResponse.failure(DioExceptionHandler.fromDioError(e).toString());
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }
}
```

Supporting pieces in `core/network/`:

```dart
class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool isSuccess;
  const ApiResponse.success(this.data) : error = null, isSuccess = true;
  const ApiResponse.failure(this.error) : data = null, isSuccess = false;
}
```

`DioExceptionHandler.fromDioError(e)` maps `DioExceptionType` (cancel, connectionTimeout, receiveTimeout, sendTimeout, connectionError, badResponse, default) and HTTP status codes to localized messages from `AppLocalizations`.

`ApiClient` builds one `Dio` with `BaseOptions(baseUrl: Endpoints.baseURL, connectTimeout: ..., receiveTimeout: ..., responseType: ResponseType.json)`, adds `TalkerDioLogger` (plus the auth interceptor if the app needs one), and exposes `updateBaseUrl(String)` for runtime changes.

Rules:
- Both `catch` blocks are required: `DioException` through `DioExceptionHandler` (messages are localized), then a generic `catch (e)`.
- Endpoint paths live only in `services/endpoints.dart`. For paths with an id, use a function: `static String fooById(int id) => '/foos/$id';`. Keep `baseURL` and timeouts there too.
- Match trailing slashes to the API contract exactly. Some backends answer a mismatched slash with a 307 redirect instead of the response.

## 3. Service locator

All registrations live in `core/di/service_locator.dart`:

```dart
final sl = GetIt.instance;

void initServiceLocator() {
  sl.registerLazySingleton<ApiClient>(() => ApiClient());
  sl.registerLazySingleton<FooRepository>(
    () => FooApiService(dio: sl<ApiClient>().dio),
  );
}
```

Called once in `main()` after `Endpoints.baseURL` is set (`ApiClient` reads `baseURL` when it is created).

## 4. Provider

One `ChangeNotifier` per area. Provider files use `part of 'providers.dart'`, and all imports go in `providers.dart`. The repository can be injected through the constructor to make testing easy.

```dart
part of 'providers.dart';

class FooProvider extends ChangeNotifier {
  final FooRepository _repository;

  FooProvider({FooRepository? repository})
    : _repository = repository ?? sl<FooRepository>();

  List<FooModel> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<FooModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchItems() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _repository.getFoos();
    if (response.isSuccess) {
      _items = response.data ?? [];
    } else {
      _errorMessage = response.error;
    }
    _isLoading = false;
    notifyListeners();
  }
}
```

Register it in `providers.dart`:

```dart
final appProviderList = [
  ChangeNotifierProvider<FooProvider>(create: (context) => FooProvider()),
];
```

A provider that must be alive from startup (e.g. a serial port) uses `lazy: false` and starts itself: `create: (_) => SerialPortProvider()..startAutoConnect()`.

In a screen: `context.watch<FooProvider>()` to rebuild, `context.read<FooProvider>()` to call actions. Never call `fetch` inside `build()`.

High-frequency sources (serial data, sensors) should batch notifications, e.g. a 100 ms `Timer` that coalesces `notifyListeners()` calls.

## 5. Tests

Use `flutter_test` + the `checks` package: assert with `check(...)`, not `expect`. Do not add mockito or mocktail; test providers with a hand-written fake repository injected through the constructor:

```dart
class FakeFooRepository implements FooRepository { /* return ApiResponse.success(...) */ }

test('fetchItems populates items', () async {
  final provider = FooProvider(repository: FakeFooRepository());
  await provider.fetchItems();
  check(provider.items).isNotEmpty();
  check(provider.errorMessage).isNull();
});
```

For providers that use `SharedPreferences`, call `SharedPreferences.setMockInitialValues({})` in `setUp`.

Widget tests: `checks` has no `findsOneWidget`-style matchers, so assert on the finder's result:

```dart
testWidgets('shows the title', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: FooScreen()));
  check(find.text('Foo').evaluate().length).equals(1);
});
```

The official `flutter-add-widget-test` and `flutter-add-integration-test` skills show `expect(find.text('Foo'), findsOneWidget)`. Follow their steps (`pumpWidget`, tap, `pump`), but write the assertions with `check(...)`. Leave existing `expect` lines alone; new tests use `check`.

## 6. Local storage

`services/local_storage_service.dart`: a `StorageKey` enum + `LocalStorageService.getString/setString/remove` over `SharedPreferences`. Add new keys to the enum and to its key-name `switch`. Never call `SharedPreferences` directly from a screen or provider.

## 7. Decision records

Record architecture decisions in `docs/adr/NNNN-title.md`:

```markdown
# ADR NNNN: Title
* **Status:** Accepted
* **Date:** YYYY-MM-DD

## Context and Problem Statement
## Decision Drivers
## Considered Options
## Decision Outcome
```
