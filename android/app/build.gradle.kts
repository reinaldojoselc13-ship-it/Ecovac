import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ecovac"
    // Use the highest required compileSdk to satisfy plugins (36+). Updated to 36.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Use Java 17 for modern toolchain and remove obsolete-8 warnings
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring required by some dependencies
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.ecovac"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Ensure minimum and target SDKs are modern to support plugins
        // Use an explicit minSdk to avoid transitive plugin incompatibilities (24+ is common for modern plugins)
        minSdk = 24
        // Align targetSdk with compileSdk to avoid plugin compatibility warnings.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Signing configuration for release builds.
    // Explicación simple: colocar aquí la ruta a tu keystore y contraseñas
    // en `gradle.properties` o variables de entorno para no subirlas al repo.
    signingConfigs {
        create("release") {
            // Intentamos leer la ruta del keystore desde gradle.properties o desde env vars.
            val keystorePath = project.findProperty("RELEASE_KEYSTORE") as String? ?: System.getenv("RELEASE_KEYSTORE")
            if (keystorePath != null) {
                storeFile = file(keystorePath)
            } else {
                // Si existe android/key.properties (creada localmente), úsala
                // Buscar key.properties en el módulo app o en la carpeta android/ (nivel superior)
                val keyPropsFileCandidates = listOf(file("key.properties"), file("..${File.separator}key.properties"))
                val keyPropsFile = keyPropsFileCandidates.firstOrNull { it.exists() }
                if (keyPropsFile != null && keyPropsFile.exists()) {
                    val props = Properties()
                    props.load(keyPropsFile.inputStream())
                    val storeFileProp = props.getProperty("storeFile")
                    if (storeFileProp != null) storeFile = file(storeFileProp)
                    storePassword = props.getProperty("storePassword")
                    keyAlias = props.getProperty("keyAlias")
                    keyPassword = props.getProperty("keyPassword")
                } else {
                    val defaultKeystore = file("key/keystore.jks")
                    if (defaultKeystore.exists()) storeFile = defaultKeystore
                }
            }

            // Valores por env o gradle props si no fueron cargados desde key.properties
            if (storePassword == null) storePassword = project.findProperty("RELEASE_STORE_PASSWORD") as String? ?: System.getenv("RELEASE_STORE_PASSWORD")
            if (keyAlias == null) keyAlias = project.findProperty("RELEASE_KEY_ALIAS") as String? ?: System.getenv("RELEASE_KEY_ALIAS")
            if (keyPassword == null) keyPassword = project.findProperty("RELEASE_KEY_PASSWORD") as String? ?: System.getenv("RELEASE_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // If a `release` signingConfig was configured (keystore present via properties/env),
            // use it; otherwise fall back to the debug signing config for quick testing.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for core library desugaring (Java APIs on older Android devices)
    add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.4")
}
