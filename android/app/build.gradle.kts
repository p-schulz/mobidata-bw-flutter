import java.util.Properties
import java.io.FileInputStream
import java.io.File

val keystorePropertiesFile: File = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "de.schulz.mobility4bw"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "de.schulz.mobility4bw"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }
    buildTypes {
        getByName("release") {
            // Release-Signing verwenden
            signingConfig = signingConfigs.getByName("release")

            // ggf. deine bisherigen Optionen hier lassen:
            isMinifyEnabled = false
            // proguardFiles( ... ) etc., falls vorhanden
        }
    }
    buildTypes {
        getByName("release") {
            // Release-Signing verwenden
            signingConfig = signingConfigs.getByName("release")

            // ggf. deine bisherigen Optionen hier lassen:
            isMinifyEnabled = false
            isShrinkResources = false
            // proguardFiles( ... ) etc., falls vorhanden
        }
        //release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            //signingConfig = signingConfigs.getByName("debug")
            //signingConfig signingConfigs.release
        //}
    }
}

flutter {
    source = "../.."
}
