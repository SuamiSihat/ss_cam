import java.io.FileInputStream
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.suamisihat.sscam"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.suamisihat.creative"
        minSdk = 26
        targetSdk = 36
        versionCode = 4111
        versionName = "4.11.1"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // Load signing configuration from keystore.properties or environment variables
    val keystorePropertiesFile = rootProject.file("keystore.properties").takeIf { it.exists() }
        ?: project.file("keystore.properties").takeIf { it.exists() }

    val keystoreProperties = Properties().apply {
        if (keystorePropertiesFile != null && keystorePropertiesFile.isFile) {
            FileInputStream(keystorePropertiesFile).use { load(it) }
        }
    }

    val storeFilePath = keystoreProperties.getProperty("storeFile")
        ?: keystoreProperties.getProperty("KEYSTORE_FILE")
        ?: System.getenv("KEYSTORE_FILE")
        ?: System.getenv("RELEASE_STORE_FILE")

    val storePasswordVal = keystoreProperties.getProperty("storePassword")
        ?: keystoreProperties.getProperty("KEYSTORE_PASSWORD")
        ?: System.getenv("KEYSTORE_PASSWORD")
        ?: System.getenv("RELEASE_STORE_PASSWORD")

    val keyAliasVal = keystoreProperties.getProperty("keyAlias")
        ?: keystoreProperties.getProperty("KEY_ALIAS")
        ?: System.getenv("KEY_ALIAS")
        ?: System.getenv("RELEASE_KEY_ALIAS")

    val keyPasswordVal = keystoreProperties.getProperty("keyPassword")
        ?: keystoreProperties.getProperty("KEY_PASSWORD")
        ?: System.getenv("KEY_PASSWORD")
        ?: System.getenv("RELEASE_KEY_PASSWORD")

    val resolvedStoreFile = if (!storeFilePath.isNullOrBlank()) {
        val f = file(storeFilePath)
        if (f.exists()) {
            f
        } else {
            val rootF = rootProject.file(storeFilePath)
            if (rootF.exists()) rootF else null
        }
    } else null

    val hasReleaseSigning = resolvedStoreFile != null &&
            !storePasswordVal.isNullOrBlank() &&
            !keyAliasVal.isNullOrBlank() &&
            !keyPasswordVal.isNullOrBlank()

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = resolvedStoreFile
                storePassword = storePasswordVal
                keyAlias = keyAliasVal
                keyPassword = keyPasswordVal
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                logger.lifecycle("Note: Release signing config or keystore file not found. Falling back to unsigned/debug mode for release build.")
                signingConfig = signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons.extended)

    // Retrofit & Networking
    implementation(libs.retrofit)
    implementation(libs.retrofit.gson)
    implementation(libs.okhttp.logging)

    // Image loading
    implementation(libs.coil.compose)

    // Coroutines
    implementation(libs.kotlinx.coroutines.android)

    // Biometric Authentication & AppCompat
    implementation("androidx.biometric:biometric-ktx:1.2.0-alpha05")
    implementation("androidx.appcompat:appcompat:1.6.1")
}






