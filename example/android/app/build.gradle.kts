plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.xmax.xlab.flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.xmax.xlab.flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // VolcEngineRTC bundles optional AI/video extension libraries that link
    // against the shared NDK C++ runtime, but its AAR does not include that
    // runtime. Generate the jniLibs input from the pinned Flutter NDK so the
    // APK works on hosts that do not already package libc++_shared.so.
    sourceSets.getByName("main").jniLibs.srcDir(
        layout.buildDirectory.dir("generated/rtcCppRuntime").get().asFile,
    )
}

val prepareRtcCppRuntime by tasks.registering(Sync::class) {
    val hostOS = System.getProperty("os.name").lowercase()
    val ndkHostTag = when {
        hostOS.contains("mac") -> "darwin-x86_64"
        hostOS.contains("win") -> "windows-x86_64"
        else -> "linux-x86_64"
    }
    val llvmLibRoot = android.ndkDirectory.resolve(
        "toolchains/llvm/prebuilt/$ndkHostTag/sysroot/usr/lib",
    )
    val outputRoot = layout.buildDirectory.dir("generated/rtcCppRuntime")
    val architectures = mapOf(
        "arm64-v8a" to "aarch64-linux-android",
        "armeabi-v7a" to "arm-linux-androideabi",
        "x86" to "i686-linux-android",
        "x86_64" to "x86_64-linux-android",
    )

    architectures.forEach { (androidABI, ndkABI) ->
        from(llvmLibRoot.resolve("$ndkABI/libc++_shared.so")) {
            into(androidABI)
        }
    }
    into(outputRoot)
}

tasks.named("preBuild").configure {
    dependsOn(prepareRtcCppRuntime)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // VolcEngineRTC 3.60.105.1900 still declares Support Library 28.
    // Jetifier maps its vector artifacts to AndroidX 1.0.0, whose manifests
    // collide under AGP 9. Force the first releases with distinct namespaces.
    implementation("androidx.vectordrawable:vectordrawable:1.1.0")
    implementation("androidx.vectordrawable:vectordrawable-animated:1.1.0")
}
