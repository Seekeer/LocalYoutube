import com.android.build.gradle.internal.api.BaseVariantOutputImpl
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val debugBuildCounterFile = rootProject.file("debug-build-counter.properties")
val isDebugBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("Debug", ignoreCase = true)
}
val debugBuildCounter: Int by lazy {
    val properties = Properties()
    if (debugBuildCounterFile.exists()) {
        debugBuildCounterFile.inputStream().use(properties::load)
    }
    val current = properties.getProperty("counter")?.toIntOrNull() ?: 0
    val next = if (isDebugBuildRequested) current + 1 else current
    if (isDebugBuildRequested) {
        properties.setProperty("counter", next.toString())
        debugBuildCounterFile.outputStream().use { output ->
            properties.store(output, "Auto-incremented debug build counter.")
        }
    }
    next
}
val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties().apply {
    if (releaseSigningPropertiesFile.exists()) {
        releaseSigningPropertiesFile.inputStream().use(::load)
    }
}
val releaseStoreFilePath =
    releaseSigningProperties.getProperty("storeFile")?.trim().orEmpty()
val releaseStorePassword =
    releaseSigningProperties.getProperty("storePassword")?.trim().orEmpty()
val releaseKeyAlias =
    releaseSigningProperties.getProperty("keyAlias")?.trim().orEmpty()
val releaseKeyPassword =
    releaseSigningProperties.getProperty("keyPassword")?.trim().orEmpty()
val hasReleaseSigning =
    releaseStoreFilePath.isNotEmpty() &&
        releaseStorePassword.isNotEmpty() &&
        releaseKeyAlias.isNotEmpty() &&
        releaseKeyPassword.isNotEmpty()

// Along the canonical main history every descendant has more reachable commits.
// This orders sources even when timestamps collide or builds finish out of order.
fun gitOutput(vararg arguments: String): String {
    val process = ProcessBuilder(listOf("git") + arguments)
        .directory(rootProject.projectDir).start()
    val output = process.inputStream.bufferedReader().readText().trim()
    require(process.waitFor() == 0) { "Cannot resolve Android source version from Git." }
    return output
}
require(gitOutput("rev-parse", "--is-shallow-repository") == "false") {
    "Android version numbering requires complete Git history; fetch --unshallow first."
}
val sourceCommitCount = gitOutput("rev-list", "--count", "HEAD").toLong()
val sourceVersionCode = (1000000000L + sourceCommitCount).also {
    require(it in 1000000001L..2100000000L) { "Android source version exceeds the supported range." }
}.toInt()

tasks.register("writeUpdateVersionCode") {
    doLast {
        val output = rootProject.layout.buildDirectory.file("app-update-version-code.txt").get().asFile
        output.parentFile.mkdirs()
        output.writeText(sourceVersionCode.toString() + "\n")
    }
}

android {
    namespace = "org.localtube.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "org.localtube.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // CI reads this same source-derived value via writeUpdateVersionCode.
        // Debug counters remain labels and cannot make old source look newer.
        versionCode = maxOf(flutter.versionCode, sourceVersionCode)
        versionName = flutter.versionName
        manifestPlaceholders["appIcon"] = "ic_launcher"
        manifestPlaceholders["appLabel"] = "localtube"
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationId = "org.localtube.app.dev"
            manifestPlaceholders["appLabel"] = "localtube dev"
        }
        create("stage") {
            dimension = "env"
            applicationId = "org.localtube.app.stable"
            manifestPlaceholders["appLabel"] = "localtube"
            manifestPlaceholders["appIcon"] = "ic_launcher"
        }
        create("prod") {
            dimension = "env"
            applicationId = "org.localtube.app"
            manifestPlaceholders["appLabel"] = "localtube_prod"
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(releaseStoreFilePath)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        getByName("debug") {
            val debugLabel = "debug.$debugBuildCounter"
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-$debugLabel"
            manifestPlaceholders["appIcon"] = "ic_launcher_debug"
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }

        release {
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

@Suppress("DEPRECATION")
android.applicationVariants.all {
    if (buildType.name == "debug") {
        outputs.all {
            if (this is BaseVariantOutputImpl) {
                outputFileName = "localtube-debug-b$debugBuildCounter.apk"
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
