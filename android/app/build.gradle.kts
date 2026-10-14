import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // Google Services plugin (reads app/google-services.json)
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// A release build with no signing key cannot be installed or uploaded to a store, and
// used to be produced silently. Fail early with a clear message instead.
// For a local, throwaway release build, set ORG_GRADLE_PROJECT_allowUnsignedRelease=true.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { it.name == "assembleRelease" || it.name == "bundleRelease" }
    if (!buildsRelease || project.hasProperty("allowUnsignedRelease")) return@whenReady

    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Release build needs a signing key, but android/key.properties was not found. " +
                "Create it with keyAlias, keyPassword, storeFile and storePassword " +
                "(see android/key.properties.example). " +
                "For a local test build only: ORG_GRADLE_PROJECT_allowUnsignedRelease=true"
        )
    }
    val missing = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
        .filter { keystoreProperties[it].toString().isBlank() || keystoreProperties[it] == null }
    if (missing.isNotEmpty()) {
        throw GradleException("android/key.properties is missing: ${missing.joinToString(", ")}")
    }
}

android {
    namespace = "com.bottlesup.vendor"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.bottlesup.vendor"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                // Relative paths are resolved from android/, as key.properties.example says.
                storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Only use release signing if key.properties exists
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Enable code shrinking and obfuscation for production
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Debug builds don't need signing config
            versionNameSuffix = "-DEBUG"
        }
    }
}

flutter {
    source = "../.."
}
