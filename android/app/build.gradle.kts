plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "mx.monetta.monetta_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "mx.monetta.monetta_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Customer Account API login callback (flutter_appauth /
        // data/customer_auth). Shopify requires the mobile redirect scheme
        // "shop.{shop_id}.*" — REPLACE_WITH_SHOP_ID must become the real
        // shop id from the Partner-dashboard Customer Account API
        // registration before login can work; see
        // lib/data/customer_auth/README.md § 8. Must stay lowercase (see
        // flutter_appauth's README) and in sync with
        // CustomerAccountConfig.redirectUri and ios/Runner/Info.plist.
        manifestPlaceholders += mapOf(
            "appAuthRedirectScheme" to "shop.replace_with_shop_id.oauth"
        )
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
