import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// `key.properties` y el keystore no estan versionados (ver android/.gitignore).
// Cuando faltan -- CI sin secretos, clon recien hecho, contribuidor externo --
// la compilacion debe seguir produciendo un APK instalable para pruebas en vez
// de romperse; en ese caso se cae con aviso a la firma de debug.
val signingPropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = signingPropertiesFile.exists()
val signingProperties = Properties().apply {
    if (hasReleaseSigning) {
        signingPropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.bdjstudio.samplepadpro"
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
        applicationId = "com.bdjstudio.samplepadpro"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
                storeFile = file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "key.properties no encontrado: el build de release se firmara " +
                        "con la clave de debug. NO distribuir este artefacto."
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

// ── Entrega del APK a <repo>/distribution/ ────────────────────────────────────
// `distribution/` es la carpeta desde la que se publica. Copiar el APK a mano
// tras cada build es un paso que se olvida y que produce entregas con una
// version antigua, asi que se encadena a `assembleRelease`: cualquier
// `flutter build apk [--split-per-abi]` deja alli el artefacto ya renombrado.
// Los .apk estan en .gitignore, de modo que esto no ensucia el repositorio.
val distributionDir = rootProject.file("../../distribution")
val distributionAppName = "BDJ_Studio_Sample_Pad"

val copyReleaseApkToDistribution = tasks.register<Copy>("copyReleaseApkToDistribution") {
    group = "distribution"
    description = "Copia los APK de release a distribution/ con nombre versionado."

    // `flutter.versionName` se resuelve en configuracion y se captura como
    // valor local: dentro de la accion de la tarea el objeto `flutter` ya no
    // esta disponible (y romperia la configuration cache).
    val versionName = flutter.versionName ?: "0.0.0"

    from(layout.buildDirectory.dir("outputs/apk/release")) {
        include("*.apk")
    }
    into(distributionDir)

    // app-release.apk            -> BDJ_Studio_Sample_Pad_1.0.3.apk
    // app-arm64-v8a-release.apk  -> BDJ_Studio_Sample_Pad_1.0.3_arm64-v8a.apk
    rename { original ->
        val abi = original
            .removeSuffix(".apk")
            .removePrefix("app-")
            .removeSuffix("release")
            .trim('-')
        if (abi.isEmpty()) {
            "${distributionAppName}_$versionName.apk"
        } else {
            "${distributionAppName}_${versionName}_$abi.apk"
        }
    }

    doFirst {
        distributionDir.mkdirs()
    }
    doLast {
        logger.lifecycle("APK de release copiado a ${distributionDir.absolutePath}")
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy(copyReleaseApkToDistribution)
}
