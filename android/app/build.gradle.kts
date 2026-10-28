import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningFile = rootProject.file("key.properties")
if (releaseSigningFile.exists()) {
    FileInputStream(releaseSigningFile).use(releaseSigningProperties::load)
}
val hasReleaseSigning = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
).all { !releaseSigningProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "mx.monetta.monetta_app"
    buildFeatures {
        resValues = true
    }
    // .fvmrc pins Flutter 3.44.8. That SDK's FlutterExtension sets
    // compileSdkVersion and targetSdkVersion to 36 (minSdkVersion 24), so
    // API 36 does not require a Flutter upgrade. Checkout Sheet Kit 3.6.1
    // still requires compileSdk 35+ and minSdk 23.
    // Pin both SDK levels: Google Play requires targetSdk 36 for new apps,
    // and a later Flutter default must not lower them.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "mx.monetta.monetta_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_appauth already requires API 24; this still exceeds Checkout
        // Sheet Kit's API 23 minimum.
        minSdk = 24
        targetSdk = 36
        // pubspec.yaml `version: x.y.z+build` — the Flutter tool writes
        // flutter.versionCode / flutter.versionName into local.properties
        // before Gradle runs. Do not hard-code a Play version here.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    flavorDimensions += "environment"
    productFlavors {
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            manifestPlaceholders["appAuthRedirectScheme"] = "shop.90228850722.oauth"
            resValue("string", "app_name", "Monetta Staging")
        }
        create("production") {
            dimension = "environment"
            // Customer Account API callback scheme. Must stay lowercase and
            // match CustomerAccountConfig.redirectUri
            // (shop.{CUSTOMER_ACCOUNT_SHOP_ID}.oauth://callback) plus the
            // Partner dashboard mobile client. Production shop id is
            // 72391655575. Single-key assignment so Flutter's other
            // manifest placeholders are not replaced.
            manifestPlaceholders["appAuthRedirectScheme"] = "shop.72391655575.oauth"
            resValue("string", "app_name", "Monetta")
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(releaseSigningProperties.getProperty("storeFile"))
                storePassword = releaseSigningProperties.getProperty("storePassword")
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
            }
        }
    }

    val releaseProguardDefaults =
        getDefaultProguardFile("proguard-android-optimize.txt")

    buildTypes {
        release {
            // Never fall back to the debug keystore. Null until key.properties
            // is present; the task-graph check below fails the release build.
            signingConfig = signingConfigs.findByName("release")
            // Flutter 3.44 also enables these for release unless -Pshrink=false.
            // Set them here so the Play bundle does not depend on that default.
            // Keep rules live in proguard-rules.pro. The Flutter Gradle plugin
            // also appends its own flutter_proguard_rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(releaseProguardDefaults, "proguard-rules.pro")
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any {
        it.project == project && it.name.contains("Release", ignoreCase = true)
    }
    if (releaseRequested && !hasReleaseSigning) {
        throw GradleException(
            "Release signing is not configured. Create android/key.properties from " +
                "android/key.properties.example; debug signing is intentionally forbidden.",
        )
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
