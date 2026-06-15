# WorkTrack — Developer Setup

## Prerequisites
- Flutter stable ≥ 3.22 (`flutter upgrade`)
- Android SDK 35, NDK 27
- Java 17

## First-time setup

```bash
# 1. Get packages
flutter pub get

# 2. Generate Drift + Riverpod code (REQUIRED before first build)
dart run build_runner build --delete-conflicting-outputs

# 3. Run on device
flutter run
```

## Code generation
Every time you change a Drift table, DAO, or `@riverpod` annotated provider, re-run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Platform config you must verify

### minSdk = 26
`android/app/build.gradle` sets `minSdk 26`.  
Required by `sqlcipher_flutter_libs`. Do not lower this.

### Foreground service type (Android 14)
`AndroidManifest.xml` declares `android:foregroundServiceType="dataSync"`.  
If you later enable in-service GPS tracking, change to `"dataSync|location"` and
add `FOREGROUND_SERVICE_LOCATION` permission.

### Battery optimisation (manual user action required)
The app will request `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` at runtime 
(Step 4). The user must grant it for the foreground service to survive.  
**On some OEM ROMs** (MIUI, OneUI, ColorOS) the user must also manually allow
"background activity" in Settings → Apps → WorkTrack → Battery.

### DB encryption key
`app_database.dart` uses a hardcoded placeholder passphrase (`worktrack_dev_key_change_me`).  
Before shipping: use `flutter_secure_storage` to generate and store a per-device key,
then pass it to the SQLCipher PRAGMA at open time.

### Release signing
`android/app/build.gradle` uses `signingConfigs.debug` for the release build type.  
Replace with your production keystore before deploying.

### SCHEDULE_EXACT_ALARM (Android 12–13)
On Android 12–13, the app must request `SCHEDULE_EXACT_ALARM` permission at runtime.
Android 12 auto-grants it; Android 13 may require the user to navigate to
Settings → Apps → Special App Access → Alarms & Reminders and enable it manually.
Step 6 (notifications) handles this request.

## No internet permission
`AndroidManifest.xml` deliberately omits `INTERNET`. The app is 100% offline.
Do not add networking libraries.
