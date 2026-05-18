# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PetPogo — Flutter app for pet hardware (tracker/phone), pet management, IM messaging, community, mall, and AI voice/image emotion analysis.

- Android package: `com.junxin.petpogo_and`
- iOS bundle id: `com.junxin.petpogo`
- Flutter SDK: `>= 3.0.0`; Dart `>= 3.0.0`

## Common commands

Dependencies and codegen:
```bash
flutter pub get
cd ios && pod install && cd ..
# Riverpod / Hive use build_runner (see dev_dependencies)
dart run build_runner build --delete-conflicting-outputs
```

Run / build:
```bash
./run.sh                 # Android: auto-boot AVD "Pixel9_API35", build debug APK, install, launch
./run.sh --release       # Same flow with release APK
./run_ios.sh             # iOS device "茶里王" (DEVICE_ID hardcoded), debug with hot reload
./run_ios.sh --release
./buildrelease.sh        # APK + IPA → release_output/petpogo_v<version>_<timestamp>.{apk,ipa}
./buildrelease.sh --apk  # APK only
./buildrelease.sh --ipa  # IPA only (pod install --repo-update first)
./log.sh                 # Tail Flutter logs from the running emulator with color tags
bash ios_fix.sh          # Fix common iOS build problems (DerivedData / Pods / module map)
```

Static analysis and tests:
```bash
flutter analyze
flutter test                                  # All tests (test/widget_test.dart only by default)
flutter test test/widget_test.dart            # Single file
flutter test --plain-name "<test name>"       # Filter by name
```

## Architecture

### Layering (strict)
```
View (page/widget)
  └─→ Controller (StateNotifier, Riverpod)
        └─→ Repository  (HTTP + parsing, returns Result<T>)
              └─→ ApiClient | PeerApiClient  (Dio + interceptors)
```

- **Repository**: no state, no `BuildContext`. Wraps calls with `guardResult(...)` from `lib/core/api/result.dart` so all errors come back as `Failure<ApiException>`.
- **Controller**: holds state, never touches Dio. Exposes `Result<T>` to the view; the view uses `result.when(success:, failure:)`.
- **View**: no try/catch, no direct Dio. Watches Riverpod providers; navigates via `context.go(AppRoutes...)`.

### Two HTTP clients (do not mix)
- `lib/core/api/api_client.dart` — `ApiClient` (singleton via `apiClientProvider`). Talks to the PetPogo business backend (`AppConfig.apiBaseUrl`). Uses `Authorization: Bearer <jwt>`. `/sdkapi/*` paths are auto-signed with `x-timestamp` + `x-signature` (MD5 of `timestamp + appApiSecret`) by `_AuthInterceptor`. All `DioException`s are converted to `ApiException` by `_ErrorInterceptor`; 401 fires `onUnauthorized` so `AuthController` can force-logout without circular deps.
- `lib/core/api/peer_api_client.dart` — `PeerApiClient` for the iPet hardware gateway. Different conventions: base URL comes from login response (`peerGatewayUrl`), header is `token: <token>` (not Bearer), body is `application/x-www-form-urlencoded`, all requests are POST, response shape is `{code, info, tip, list}`. See `PeerApi.md` and `HARDWARE_API_REFERENCE.md`.

When adding a backend call, decide which client first — business endpoints (`/sdkapi/...`) use `ApiClient`; iPet hardware endpoints (`/uclgwapp/...`) use `PeerApiClient`.

### Routing
All routes live in `lib/core/router/app_router.dart`; paths are constants in `lib/core/router/app_routes.dart`. `appRouter` is a top-level `GoRouter` instance — `main.dart` injects a `ProviderContainer` via `initAppRouter(container)` so the redirect guard can read `authControllerProvider` without a `BuildContext`.

Guard behavior in `redirect`:
1. `auth.isRestoring` → pin to `/splash` (prevents low-end-device flicker; SplashPage does its own min-display + jump).
2. `guest` and not on `/login` → `/login`.
3. `loggedIn` and on `/login` → `/`.

`MainShell` (under `ShellRoute`) wraps the 5 tabs (`/`, `/message`, `/community`, `/mall`, `/profile`). Tabs fade-transition; sub-pages slide; success pages fade-scale — use the `_fade` / `_slide` / `_fadeScalePage` helpers when adding routes. Add parameterized routes to `AppRoutes` as both a builder method (`scanQr(id)`) and a `*Template` constant (`/scan-qr/:deviceType`).

### State management
- Riverpod (`flutter_riverpod` + `riverpod_annotation`). `main.dart` creates a single top-level `ProviderContainer`, mounts it via `UncontrolledProviderScope`, and `listen`s `authControllerProvider` to call `appRouter.refresh()` on status changes.
- `AuthController` (`lib/features/auth/controller/auth_controller.dart`) is the source of truth for auth state (`restoring/guest/loading/loggedIn/error`). On login it triggers IM login, pet load, device load, and user stats; on logout it tears them down.
- Storage: `flutter_secure_storage` for tokens/UserSig/profile keys (`_kToken`, `_kImUserSig`, `_kPeerGatewayUrl`, ...). Hive is wired for general local cache.

### Tencent IM
Initialized in `main.dart` before `runApp`. SDK app ID and (dev-only) secret live in `AppConfig`. JWT (30d) and IM UserSig (6d) are persisted; on `onUserSigExpired` the `ImController` calls `/sdkapi/im/sign` to refresh — no re-login. **Before shipping, clear `AppConfig.timSecretKey`** (it must not appear in production builds).

### Feature module shape
Under `lib/features/<feature>/`:
- `*_page.dart` / `*_sheet.dart` — views
- `controller/` — Riverpod controllers
- `data/repository/` — repositories
- `data/models/` — JSON-serializable models

Shared UI lives in `lib/shared/widgets/`, theme in `lib/shared/theme/`, helpers in `lib/shared/utils/`.

### Localization
`flutter_localizations` + ARB files in `lib/l10n/` (`app_zh.arb`, `app_en.arb`). The `BuildContext` extension `context.l10n` (in `lib/app.dart`) is the standard accessor. Locale is driven by `localeProvider`. Default is `zh`.

## Important files

| File | Purpose |
|---|---|
| `lib/core/config/app_config.dart` | API base URLs, OAuth credentials (`partnerCode`/`clientId`/`clientSecret`/`enterpriseCode`), Tencent IM `sdkAppId`/`timSecretKey`, AMap keys, version, page size |
| `lib/core/api/api_endpoints.dart` | All `/sdkapi/*` paths (business backend + AI + OSS upload sign) |
| `lib/core/api/result.dart` | `Result<T>` sealed class + `guardResult()` — the unified error boundary |
| `lib/core/router/app_router.dart` | Single GoRouter, guard logic, transition helpers |
| `android/app/build.gradle.kts` | Android package + version |
| `ios/Runner/Info.plist` | iOS bundle id + permission strings |
| `pubspec.yaml` | Version (`1.0.8+8`), dependencies |
| `AUTH_LOGIN_REFERENCE.md` | uCloudlink OAuth2 + `/uclgwapp/` gateway flow |
| `HARDWARE_API_REFERENCE.md` | iPet hardware API conventions |
| `PeerApi.md` | iPet gateway endpoint catalog |

## Conventions to follow

- Don't hardcode URLs in business code — add a constant in `ApiEndpoints` (business) and route via `ApiClient`, or call through `PeerApiClient` for hardware endpoints.
- Don't hardcode route strings — add to `AppRoutes` and use the builder + `*Template` pair.
- Repositories return `Result<T>`; only the view layer pattern-matches with `result.when(...)`.
- Riverpod state changes that affect navigation must flow through `AuthController` so the existing `container.listen` → `appRouter.refresh()` wiring picks them up.
- `AppConfig.isDebug` gates the Dio log interceptor; use `debugPrint` (not `print`) so `./log.sh` color-codes lines via its `[API ...]` / `[路由]` / `[状态]` tags.
