# Android Play Store release (AAB)

Production Android is an App Bundle built with the `production` flavor. Google
Play App Signing holds the **app signing key**. This repo configures only the
**upload key** that signs the bundle you upload. Checkout and payment code are
not part of this setup.

`.fvmrc` pins Flutter **3.44.8**. That SDK's `FlutterExtension` sets
`compileSdkVersion` and `targetSdkVersion` to **36** (and `minSdkVersion` to
24). API 36 does not require a Flutter upgrade. `android/app/build.gradle.kts`
pins `compileSdk` and `targetSdk` to 36 so a later Flutter default cannot drop
the Play requirement. `minSdk` stays 24 because `flutter_appauth` requires it.

`versionCode` / `versionName` come from `pubspec.yaml` (`version: x.y.z+build`,
currently `0.1.0+1`). The Flutter tool writes them into
`android/local.properties` as `flutter.versionCode` and `flutter.versionName`
before Gradle runs. Bump the number after `+` for every Play upload.

## 1. Generate the upload keystore

Run this once, on a machine that will not commit the result. Store the file
and both passwords in the release secret store (CI and the owner's password
manager). If the upload key is lost before the first Play enrollment, generate
a new one. After Play has registered it, losing it requires Google's upload-key
reset.

```bash
keytool -genkeypair -v \
  -keystore monetta-upload.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias monetta-upload
```

`keytool` asks for a store password, a key password, and a distinguished name.
Use the legal name of the business in the name fields. The alias must be
`monetta-upload` so it matches `android/key.properties.example`.

Move the keystore to the path the properties file expects (relative to
`android/`):

```bash
mv monetta-upload.jks android/app/monetta-upload.jks
```

`*.jks`, `*.keystore`, and `android/key.properties` are gitignored. Do not
force-add them.

## 2. `android/key.properties`

```bash
cp android/key.properties.example android/key.properties
```

Fill the four values from the secret store. `storeFile` is resolved from the
`android/` directory (`rootProject.file` in `android/app/build.gradle.kts`):

```properties
storeFile=app/monetta-upload.jks
storePassword=<store password>
keyAlias=monetta-upload
keyPassword=<key password>
```

Passwords are Java properties (ISO-8859-1). Prefer ASCII passwords, or escape
non-ASCII characters. A missing or incomplete `key.properties` fails any
release task. The build does not fall back to the debug keystore.

In Play Console, enroll the app in **Play App Signing**, then register this
keystore as the **upload key** (App integrity → App signing). Download the
upload certificate with:

```bash
keytool -export -rfc \
  -keystore android/app/monetta-upload.jks \
  -alias monetta-upload \
  -file monetta-upload-certificate.pem
```

Give Google that `.pem` if the console asks for the upload certificate. Do not
commit the `.pem` if you treat it as a release artifact; it is not a secret,
but it also does not belong in the tree.

## 3. Build the production bundle

The app has a flavor dimension, so a bare `flutter build appbundle --release`
cannot select staging vs production. The production command is:

```bash
cp config/dart_defines.production.json.example config/dart_defines.production.json
# fill public production values, then:
make validate-production
make build-production-android
```

That target runs:

```bash
flutter build appbundle --release --flavor production \
  --dart-define-from-file=config/dart_defines.production.json
```

Output:

```text
build/app/outputs/bundle/productionRelease/app-production-release.aab
```

Upload that AAB. `applicationId` is `mx.monetta.monetta_app` (no `.staging`
suffix). `versionName` is the pubspec name with no `-staging` suffix.

Release builds minify and shrink resources (R8). Rules are in
`android/app/proguard-rules.pro`. Flutter 3.44 also appends
`flutter_proguard_rules.pro`. Firebase and Checkout Sheet Kit keep their own
classes via consumer rules. `android.r8.globalOptionsInConsumerRules=allow`
lets those AAR rules through on AGP 9.

## 4. Login redirect (do not point it at staging)

Production Customer Account login returns to:

```text
shop.72391655575.oauth://callback
```

The scheme is the `production` flavor's `appAuthRedirectScheme`. It matches
`CUSTOMER_ACCOUNT_SHOP_ID` `72391655575` and
`CustomerAccountConfig.redirectUri`. Staging uses
`shop.90228850722.oauth` and `applicationId` `mx.monetta.monetta_app.staging`.
The redirect activity comes from `flutter_appauth`; it is not duplicated in
`AndroidManifest.xml` (a second filter breaks the browser hand-off).
`android:taskAffinity=""` stays unset for the same reason.

## 5. Icons still waiting on final art

| Resource | Role |
|---|---|
| `res/mipmap-anydpi-v26/ic_launcher.xml` | Adaptive icon (API 26+) |
| `res/drawable/ic_launcher_background_placeholder.xml` | Background layer |
| `res/drawable/ic_launcher_foreground_placeholder.xml` | Foreground layer |
| `res/drawable/ic_launcher_monochrome_placeholder.xml` | Themed icon (API 33+) |
| `res/drawable/ic_stat_monetta_notification_placeholder.xml` | White notification silhouette |
| `res/values/colors.xml` (`monetta_notification_accent_placeholder`) | FCM icon accent |
| `res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` | Pre-API 26 fallback; still the Flutter default |

Replace the placeholder drawables and the density PNGs in place. Keep the
file names. The notification icon must stay a single white glyph on a
transparent background. It is wired to
`com.google.firebase.messaging.default_notification_icon` and to
`AndroidInitializationSettings` for local reminders.

## 6. Manifest audit

`src/main` allows no cleartext (`android:usesCleartextTraffic="false"`).
Checkout only presents `https` URLs. Debug and profile manifests do not add
permissions or cleartext. `INTERNET` in `src/main` is required in production;
it is not a debug-only permission.
