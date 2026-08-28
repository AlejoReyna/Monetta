plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "mx.monetta.monetta_app"
    // Checkout Sheet Kit 3.6.1 requires compileSdk 35+ and minSdk 23.
    // Existing AndroidX/plugins in this app require compileSdk 36+.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "mx.monetta.monetta_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_appauth already requires API 24; this still exceeds Checkout
        // Sheet Kit's API 23 minimum.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Customer Account API login callback (flutter_appauth).
        // Staging shop id for monetta-staging.myshopify.com. Production
        // needs a separate flavor (different shop id). Lowercase, in sync
        // with CUSTOMER_ACCOUNT_SHOP_ID / ios/Runner/Info.plist.
        manifestPlaceholders += mapOf(
            "appAuthRedirectScheme" to "shop.90228850722.oauth"
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.shopify:checkout-sheet-kit:3.6.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
