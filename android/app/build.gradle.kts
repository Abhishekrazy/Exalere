import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
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
