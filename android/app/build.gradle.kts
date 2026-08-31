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
        applicationId = "mx.monetta.monetta_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_appauth already requires API 24; this still exceeds Checkout
        // Sheet Kit's API 23 minimum.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
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

    buildTypes {
        release {
            // Never fall back to the debug keystore.
            signingConfig = signingConfigs.findByName("release")
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
