# Nexus — Build & Release Verification (§6.4 v1.3.0)

Everything below runs on a machine with the Android toolchain installed. This
sandbox has **no Android SDK and no Xcode**, so an APK/IPA cannot be produced or
verified here; the commands and the expected evidence are recorded instead.

## 1. Preconditions

```bash
flutter --version        # 3.47.9 stable or newer
dart --version
java -version            # JDK 17 for the Android Gradle Plugin
sdkmanager --list_installed   # platforms;android-35, build-tools;35.0.0
```

## 2. Verify the source tree before touching a device

```bash
cd backend-go
go vet ./...
go test ./...                                   # 9 packages
NEXUS_DATABASE_URL=... go run ./cmd/migrate up   # applies 000001..000007

cd ../app-flutter
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos --fatal-warnings   # must print "No issues found!"
flutter test                                     # unit + widget suite
```

## 3. Release keystore (one time, keep the file and passwords safe)

```bash
keytool -genkeypair -v \
  -keystore nexus-release.jks \
  -storetype JKS -keyalg RSA -keysize 4096 -validity 10000 \
  -alias nexus -dname "CN=Nexus, O=Nexus, L=Yangon, C=MM"
```

`android/key.properties` (never commit this file):

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=nexus
storeFile=/absolute/path/nexus-release.jks
```

`android/app/build.gradle.kts` signing block:

```kotlin
val keystoreProperties = java.util.Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
android {
    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}
```

`.gitignore` must contain `android/key.properties` and `*.jks`.

## 4. Build the APK / App Bundle

```bash
flutter clean
flutter pub get
flutter build apk --release --build-name=1.3.0 --build-number=3 \
  --dart-define=NEXUS_API_URL=https://api.example.com
flutter build appbundle --release --build-name=1.3.0 --build-number=3 \
  --dart-define=NEXUS_API_URL=https://api.example.com
```

`NEXUS_API_URL` must be HTTPS: `ApiClient` rejects any other scheme at
construction, so a plain-HTTP build fails fast instead of shipping.

## 5. Verify the artefact

```bash
# Signature and certificate
apksigner verify --verbose --print-certs \
  build/app/outputs/flutter-apk/app-release.apk

# Version name/code actually baked in
aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | head -3

# Record the artefact hash for the release notes
sha256sum build/app/outputs/flutter-apk/app-release.apk
```

Expected: `Verified using v2 scheme (APK Signature Scheme v2): true`,
`versionName='1.3.0'`, `versionCode='3'`.

## 6. iOS (requires macOS + Xcode)

```bash
cd ios && pod install && cd ..
flutter build ipa --release --build-name=1.3.0 --build-number=3 \
  --dart-define=NEXUS_API_URL=https://api.example.com
```

## 7. Store checklist

- [ ] `versionName`/`versionCode` bumped in one place only (`--build-name/--build-number`)
- [ ] Upload keystore backed up offline; Play App Signing enrolled
- [ ] `flutter analyze --fatal-infos --fatal-warnings` clean
- [ ] `flutter test` green; coverage recorded (see `coverage/lcov.info`)
- [ ] Data Safety form: photos/videos, approximate location, device id
- [ ] Privacy policy URL reachable; account deletion path exercised

## 8. Lightweight update (v1.4.0)

Android splits are enabled in `android/app/build.gradle.kts` (`armeabi-v7a`,
`arm64-v8a`, `x86_64`, `isUniversalApk = false`), together with
`isMinifyEnabled` + `isShrinkResources`.

```bash
# Per-ABI APKs (smallest download; upload all three to a direct-download channel)
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=build/symbols \
  --build-name=1.4.0 --build-number=4 \
  --dart-define=NEXUS_API_URL=https://api.example.com

# Play Store artefact — Play generates per-device splits itself
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols \
  --build-name=1.4.0 --build-number=4 \
  --dart-define=NEXUS_API_URL=https://api.example.com

# Optional crash reporting (omit the define to ship without telemetry)
flutter build appbundle --release --dart-define=SENTRY_DSN=https://<key>@o0.ingest.sentry.io/<id>
```

Keep `build/symbols/` with the release: without it an obfuscated stack trace cannot be
symbolicated. Verify the artefacts as in §5, and confirm the AAB contains the split
config with `bundletool dump config --bundle=app-release.aab`.

WebP is applied on the client (`WebPImageCompressor`) before `POST /media`, so image
payloads are ~60-70 % smaller than the camera original without a server-side transcode.
