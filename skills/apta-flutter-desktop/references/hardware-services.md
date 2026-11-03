# Hardware, serial port, mDNS

## 1. One interface per device

The UI and providers depend only on an interface. Each interface has a `Fake...Service` (dummy data, drivable from debug buttons or tests) and a `...ServiceImpl` (real hardware). Example contracts for an NFC reader, a serial scale, and an OCR engine (a starting point; agree changes with the reviewer before coding):

```dart
abstract class NfcService {
  /// Card UID as uppercase hex, e.g. "1B816950". Emits once per tap.
  Stream<String> get cardUids;
  Stream<NfcReaderStatus> get status; // connected, disconnected
  Future<void> start();
  Future<void> stop();
}

class ScaleReading {
  final int weight;      // kg, as reported by the device
  final bool isStable;
  const ScaleReading({required this.weight, required this.isStable});
}

abstract class ScaleService {
  Stream<ScaleReading> get readings;
  Stream<ScaleConnectionStatus> get status;
  Future<void> start();
  Future<void> stop();
}

class PlateResult {
  final String plate;
  final double confidence; // 0..1
  const PlateResult({required this.plate, required this.confidence});
}

abstract class OcrService {
  Future<PlateResult?> readPlate(); // null = unreadable, UI offers manual entry
}
```

Rules:
- Only the `...Impl` file imports the device package (`dart_pcsc`, `flutter_libserialport`, a camera/OCR SDK).
- Expose status streams (connected/disconnected) so the UI can show a clear error instead of hanging.

## 2. Choosing Fake or Real

Use `--dart-define`, not `.env`:

```bash
fvm flutter run -d linux --dart-define=FAKE_HARDWARE=true
```

```dart
const useFake = bool.fromEnvironment('FAKE_HARDWARE');

void initServiceLocator() {
  // ...
  sl.registerLazySingleton<NfcService>(() => useFake ? FakeNfcService() : NfcServiceImpl());
  sl.registerLazySingleton<ScaleService>(() => useFake ? FakeScaleService() : ScaleServiceImpl());
}
```

- Release builds must not use `FAKE_HARDWARE=true`. Add a check to the build script.
- A debug panel (visible only when `useFake` is true) drives the fakes: tap a card with a chosen UID, move a weight slider and press "stabilize", simulate a disconnect or an OCR failure. Fakes should emit through the same streams as real devices; they must not shortcut the app's normal flow.
- Fakes do not prove the real device works. Anything that depends on hardware is still tested on the device before release.

## 3. Serial devices (e.g. a weighing scale)

Package: `flutter_libserialport`. Patterns to keep:

- **Background Isolate.** Run serial reading in a worker (`Isolate.spawn(serialPortWorkerMain, receivePort.sendPort)`); the UI isolate only receives events over a `SendPort`. Typical events: `ready`, `ports`, `selectedPort`, `status`, `data`, `log`, `connectResult`.
- **Single operation queue** in the worker (chain each command onto a `Future` tail), so connect, disconnect, and poll never race.
- **Monitor and settle**: poll `SerialPort.availablePorts` every 500 ms, wait ~750 ms after the configured port first appears before connecting, and auto-reconnect when a port disappears and returns. If no port is configured and exactly one USB port exists, select it.
- **Parsing**: accumulate a string buffer, split on `\n`, `\r`, or ETX (`\u0003`), strip STX (`\u0002`). Parse a signed fixed-width number first, with a `-?\d+` regex fallback.
- **Stability window**: a reading is stable only when N consecutive readings are identical.
  ```dart
  const stabilityWindow = 5;
  final history = <int>[];

  bool onReading(int value) {
    history.add(value);
    if (history.length > stabilityWindow) history.removeAt(0);
    return history.length == stabilityWindow && history.every((v) => v == history.first);
  }
  ```
- **Native cleanup**: call `SerialPortConfig.dispose()` and close the reader and port on disconnect and dispose. Without this, native memory leaks on Windows.
- **Batch UI notifications** (~100 ms) because devices emit data very frequently.
- Persist the configuration (port, baud, parity, data bits, stop bits) in `SharedPreferences`, and keep default values (9600, None, 8, 1).
- Never let the user type a value that must come from the device. Keep such fields read-only and block submit until the device reports stable.

## 4. NFC readers (ACR122U over PC/SC)

Package: `dart_pcsc` (FFI to `libpcsclite.so.1` on Linux, `winscard.dll` on Windows).

Facts from hands-on testing with an ACR122U and a MIFARE Classic 1K card:
- The UID is read with the pseudo-APDU `FF CA 00 00 00`. Response: UID + `90 00`.
- **`waitForCard` can hang (30 second timeout) even when a card is already on the reader.** The pattern that worked: try `connect` straight to the reader first, then fall back to `waitForCard`. Keep this order.
- MIFARE Classic's Crypto1 is broken, so cards can be cloned. If the card is only an identifier, read the UID, keep all data on the server, and do not store secrets in sectors.

Linux, to be verified on the target machine:
- Packages `pcscd` and `libpcsclite1` must be installed and the `pcscd` service running.
- The `pn533`/`pn533_usb` kernel modules can grab the reader and block PC/SC. If the reader is not detected, check `lsmod` and blacklist those modules.
- The app user needs permission to talk to `pcscd` (polkit). Put this in the install docs.

## 5. Server discovery (mDNS)

Package: `multicast_dns`. Use it when the backend's IP changes (DHCP) and nobody should type it in.

Resolution order: stored URL (check the socket is live) -> mDNS scan -> `BASE_URL_FALLBACK`. If the server is not found, retry periodically (5 s) in the background and expose a `serverNotFound` notifier for the UI.

- The service type is defined by the backend, e.g. `_myservice._tcp.local`. The backend registers it (in Go, with `zeroconf.Register(...)`).
- Look up in three stages, each with a ~3 s timeout: PTR (`ResourceRecordQuery.serverPointer(serviceType)`) -> SRV (`ResourceRecordQuery.service(ptr.domainName)`) -> IPv4 (`ResourceRecordQuery.addressIPv4(srv.target)`). Build the base URL from the IP, the SRV port, and your API prefix.
- **Windows needs special handling**, or discovery fails there:
  ```dart
  final client = MDnsClient(
    rawDatagramSocketFactory: (dynamic host, int port, {bool? reuseAddress, bool? reusePort, int? ttl}) {
      final bindHost = (Platform.isWindows && host is! InternetAddress) ? InternetAddress.anyIPv4 : host;
      return RawDatagramSocket.bind(
        bindHost,
        port,
        reuseAddress: true,
        reusePort: Platform.isWindows ? false : (reusePort ?? true),
        ttl: ttl ?? 255,
      );
    },
  );

  await client.start(
    interfacesFactory: Platform.isWindows
        ? (InternetAddressType type) => NetworkInterface.list(
              includeLoopback: false,
              includeLinkLocal: false,
              type: InternetAddressType.IPv4,
            )
        : null,
  );
  ```
  Always `client.stop()` in a `finally`.
- Cache the resolved URL in local storage, and verify it with a short `Socket.connect` (~1.5 s) before reuse. Clear it if the check fails.
- After discovery, set `Endpoints.baseURL` before `initServiceLocator()`. If the URL changes at runtime, call `ApiClient.updateBaseUrl`.

## 6. Hardware tests

- Test providers with fake services (streams driven by a `StreamController` in the test).
- Unit-test the stability window (identical readings = stable, one different = not stable).
- Test real hardware manually with these scenarios and record the results in the PR: device not recognized or unregistered, device removed mid-operation, cable unplugged, server down during submit.
