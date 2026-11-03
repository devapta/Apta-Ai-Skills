# Build and release

## Flutter version

- `.fvmrc` holds the exact version (`{"flutter": "3.47.0"}`). Everyone and every build uses it.
- Bump the Flutter version in its own commit (`fvm use <version>`), then run `analyze` and `test`.
- Make the Linux Docker build take the version from `.fvmrc` (see below) so it can never drift from local builds.

## Windows

Prerequisites: FVM, Inno Setup 6 (`C:\Program Files (x86)\Inno Setup 6\ISCC.exe`), and the `.env` file in the project root.

Templates live in this skill: `assets/windows/build.ps1` and `assets/windows/installer.iss`. Copy both to the project root (keep the names; `build.ps1` expects `installer.iss`) and fill in the placeholders.

| Where | Placeholder | Set to |
| --- | --- | --- |
| `installer.iss` | `MyAppName` | Display name shown in the installer and Start menu |
| `installer.iss` | `MyAppPublisher`, `MyAppURL` | Publisher name and URL |
| `installer.iss` | `MyAppExeName` | `<binary_name>.exe`; the name comes from `BINARY_NAME` in `windows/CMakeLists.txt` (the project name by default) |
| `installer.iss` | `MyAppSlug` | File-name prefix, e.g. `my-app` gives `my-app-v1.2.3.exe` |
| `installer.iss` | `AppId` | A new GUID per app (`[guid]::NewGuid().ToString().ToUpper()`), keep the `{{` prefix, never change it afterwards |
| `installer.iss` | `SetupIconFile` | Path to the `.ico` (default `windows\runner\resources\app_icon.ico`) |
| `installer.iss` | `[UninstallDelete]` | The `%APPDATA%` folders your app creates (see the comment in the file) |
| `build.ps1` | `$AppSlug` | The same value as `MyAppSlug` |

What `build.ps1` does:
1. Checks prerequisites: FVM, `ISCC.exe`, `installer.iss`, `.env`.
2. Reads the version from `pubspec.yaml`, or takes `-Version x.y.z` and writes it back to `pubspec.yaml` (through `cider` when installed, otherwise a regex edit).
3. Rewrites the `#define MyAppVersion` line in `installer.iss` so both files agree.
4. Optionally runs `fvm flutter clean` (`-Clean`).
5. Runs `fvm flutter build windows --release`.
6. Compiles the installer with `ISCC.exe` (up to 3 attempts, because antivirus can briefly lock files) into `build\installer_output\v<version>\<slug>-v<version>.exe`.

Usage:

```powershell
.\build.ps1                          # version from pubspec.yaml
.\build.ps1 -Clean                   # flutter clean first
.\build.ps1 -Version 0.2.0           # override the version
.\build.ps1 -OutputRoot D:\releases  # put v<version>\ somewhere else
```

Notes:
- Keep output paths relative or parameterized; do not hardcode a path from one machine.
- The templates were adapted from a working project but have not been run end to end in this repo. Do a full build and install on a clean Windows machine the first time, and check that the uninstaller removes the right folders.

## Linux (Ubuntu 22.04 x64)

Build through Docker so the result is consistent and compatible with Ubuntu 22.04's glibc. Templates live in this skill: `assets/linux/Dockerfile.linux` and `assets/linux/build-ubuntu.sh`. Copy both to the project root (keep the names; the script expects `Dockerfile.linux` next to it) and set one value:

| Where | Placeholder | Set to |
| --- | --- | --- |
| `build-ubuntu.sh` | `app_name` | Archive name prefix, e.g. `my-app` gives `my-app-linux-x64.tar.gz` |

```bash
./build-ubuntu.sh
# output: build/ubuntu/<app-slug>-linux-x64.tar.gz
```

Requirements: `docker` (with `buildx`) and `jq`. The script reads the exact Flutter version from `.fvmrc`, checks that `.env` exists, and passes `FLUTTER_VERSION` and `APP_NAME` as build args, so the Docker build can never drift from local builds. It targets `linux/amd64` on Ubuntu 22.04.

Notes:
- `libudev-dev` is needed by `flutter_libserialport`. `CFLAGS` is pinned to `-march=x86-64 -mtune=generic` so the build runs on older CPUs.
- Do not run `docker build` by hand without `--build-arg FLUTTER_VERSION=... --build-arg APP_NAME=...`; use `build-ubuntu.sh`.
- Local build without Docker: `fvm flutter build linux --release`, then archive `build/linux/x64/release/bundle` with `tar -C build/linux/x64/release -czf <app>-linux-x64.tar.gz bundle`.

## Target Linux machine setup

Things to install or configure on the destination machine, not in the build:
- **Serial devices**: the app user joins the `dialout` group (`sudo usermod -aG dialout $USER`), then logs in again.
- **NFC (ACR122U)**: packages `pcscd` and `libpcsclite1`, with the `pcscd` service running. Check whether the `pn533` module needs blacklisting (see `hardware-services.md`).
- **Camera**: permission to access `/dev/video*` (the `video` group).
- **mDNS**: the machine must be on the same LAN/subnet as the backend, and multicast must not be blocked by a firewall (UDP 5353).
- The `.env` file is bundled as an asset, so set `BASE_URL` / `BASE_URL_FALLBACK` correctly before building.

## Before a release

1. `fvm flutter analyze` is clean and `fvm flutter test` is green.
2. `FAKE_HARDWARE` is not used in the release build.
3. Bump `version` in `pubspec.yaml`.
4. Test the installer on a clean machine (not a developer machine): the app opens, discovery finds the server, devices are detected.
5. Add short release notes (what changed, how it was tested).
