plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}
android {
    namespace = "com.puzzlequest50sols.com"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "com.puzzlequest50sols.com"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        getByName("release") {
            // Opt-in, installable release-mode builds for physical-device QA.
            // Production builds still require the publisher's signing setup.
            if (providers.gradleProperty("localTestRelease").orNull == "true") {
                signingConfig = signingConfigs.getByName("debug")
            }
            // Signing credentials are provisioned by the publisher/CI only.
            // No debug signing for production release.
            isMinifyEnabled = false
            // Resource shrinking requires code minification (R8).
            // Keep both disabled until a tested, signed release configuration exists.
            isShrinkResources = false
        }
    }
}
// Kotlin Gradle Plugin 2.3: configure the JVM target with compilerOptions.
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter { source = "../.." }
