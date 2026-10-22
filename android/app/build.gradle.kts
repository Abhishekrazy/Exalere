import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // Required: this project compiles Kotlin (MainActivity and the torrent
    // engine). Without it the `kotlin { }` block further down cannot resolve and
    // no Kotlin compilation task is created, so every Android build fails.
    // Flutter's own app template includes this line.
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    val altKeystoreProperties = file("../key.properties")
    if (altKeystoreProperties.exists()) {
        keystoreProperties.load(FileInputStream(altKeystoreProperties))
    }
}

val envKeyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: keystoreProperties.getProperty("keyAlias")
val envKeyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: keystoreProperties.getProperty("keyPassword")
val envStoreFilePath = System.getenv("ANDROID_KEYSTORE_PATH") ?: keystoreProperties.getProperty("storeFile")
val envStorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: keystoreProperties.getProperty("storePassword")

val resolvedStoreFile = if (!envStoreFilePath.isNullOrBlank()) {
    val fDirect = file(envStoreFilePath)
    if (fDirect.exists()) {
        fDirect
    } else {
        val fApp = file("upload-keystore.jks")
        if (fApp.exists()) {
            fApp
        } else {
            val fRoot = rootProject.file(envStoreFilePath)
            if (fRoot.exists()) fRoot else null
        }
    }
} else null

val hasReleaseSigning = !envKeyAlias.isNullOrBlank() &&
                        !envKeyPassword.isNullOrBlank() &&
                        !envStorePassword.isNullOrBlank() &&
                        resolvedStoreFile != null

android {
    namespace = "com.abhishekrazy.exalere"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.abhishekrazy.exalere"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "distribution"

    productFlavors {
        create("play") {
            dimension = "distribution"
        }
        create("github") {
            dimension = "distribution"
        }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
                storeFile = resolvedStoreFile
                storePassword = envStorePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // libtorrent4j is reached entirely through JNI, so its SWIG bridge
            // must survive minification if it is ever enabled.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // Bundled P2P streaming is github-only. The Play artefact must not contain a
    // BitTorrent engine at all (Google Play Device and Network Abuse policy), so
    // both the native libraries and the Kotlin that drives them live in the
    // `github` source set / configuration. The `play` flavour resolves magnets
    // through an external engine over loopback HTTP instead.
    //
    // libtorrent4j is MIT and libtorrent is BSD-3; both are compatible with this
    // project's PolyForm Noncommercial licence. One native artifact per shipped
    // ABI: arm64-v8a, armeabi-v7a and x86_64 are exactly the ABIs release.yml
    // builds.
    "githubImplementation"("org.libtorrent4j:libtorrent4j:2.1.0-35")
    "githubImplementation"("org.libtorrent4j:libtorrent4j-android-arm64:2.1.0-35")
    "githubImplementation"("org.libtorrent4j:libtorrent4j-android-arm:2.1.0-35")
    "githubImplementation"("org.libtorrent4j:libtorrent4j-android-x86_64:2.1.0-35")

    // Cloudflare WARP runs over WireGuard. Unlike the torrent engine this ships in
    // BOTH flavours: a VPN client is a permitted, declarable Play feature, so there
    // is no policy reason to strip it from the store build.
    //
    // Apache-2.0, which is compatible with this project's PolyForm Noncommercial
    // licence. The alternative (the MASQUE client the reference app bundles) is
    // GPL-3.0 and could not be redistributed here.
    implementation("com.wireguard.android:tunnel:1.0.20260102")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
