import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = project.rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val mapSdkKey = localProperties.getProperty("mappls.mapSdkKey") ?: "c59951af1ef53a9e6cc8fb8a7080d5d8"
val restApiKey = localProperties.getProperty("mappls.restApiKey") ?: "c59951af1ef53a9e6cc8fb8a7080d5d8"
val clientId = localProperties.getProperty("mappls.clientId") ?: "96dHZVzsAutf7JmkOzGCFwHsVMopiBc3omOm6Nz9I61Oj27HCVNsH44gi4vQBl9ZxAk3l9rrauxdqOYwUmUkOlCz7RrIFlKN"
val clientSecret = localProperties.getProperty("mappls.clientSecret") ?: "lrFxI-iSEg8FAEuoX9z0UYKFbEDDr2gtxSFnMaxGyAmNBp8A__5GQ8yGbmpIL3g5qYPFCzw-0wb_u9xpbjl1i8lZ49AasxwH3PCiRF2PpuY="

android {
    namespace = "com.kride.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kride.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion // Minimum for Mappls GL SDK
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["MAPPLS_MAP_SDK_KEY"] = mapSdkKey
        manifestPlaceholders["MAPPLS_REST_API_KEY"] = restApiKey
        manifestPlaceholders["MAPPLS_ATLAS_CLIENT_ID"] = clientId
        manifestPlaceholders["MAPPLS_ATLAS_CLIENT_SECRET"] = clientSecret
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
