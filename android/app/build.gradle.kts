plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Play workflow opts in explicitly; direct APK builds keep their existing signing.
val googlePlayBuild = System.getenv("SONARPAD_GOOGLE_PLAY_BUILD") == "true"
fun requiredPlaySigningValue(name: String): String =
    System.getenv(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("Missing Google Play signing setting: $name")

android {
    namespace = "com.ambro86.sonarpad"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    defaultConfig {
        applicationId = "com.ambro86.sonarpad"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (googlePlayBuild) {
        signingConfigs {
            create("googlePlayUpload") {
                storeFile = file(requiredPlaySigningValue("PLAY_UPLOAD_KEYSTORE_PATH"))
                storePassword = requiredPlaySigningValue("PLAY_UPLOAD_STORE_PASSWORD")
                keyAlias = requiredPlaySigningValue("PLAY_UPLOAD_KEY_ALIAS")
                keyPassword = requiredPlaySigningValue("PLAY_UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (googlePlayBuild) "googlePlayUpload" else "debug"
            )
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.media3:media3-exoplayer:1.9.2")
    implementation("androidx.media3:media3-exoplayer-hls:1.9.2")
    implementation("androidx.media3:media3-exoplayer-dash:1.9.2")
    implementation("androidx.media3:media3-datasource-okhttp:1.9.2")
    implementation("androidx.media3:media3-ui:1.9.2")
    implementation("androidx.concurrent:concurrent-futures:1.1.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.17")
}
