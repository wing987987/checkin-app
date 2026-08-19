import java.util.Properties
import java.io.FileInputStream
import com.android.build.api.dsl.ApplicationExtension
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取签名配置
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.zhaochen.checkin_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.zhaochen.checkin"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 应用名称由风味决定
        manifestPlaceholders["appName"] = "昭臣打卡"
    }

    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            applicationIdSuffix = ""
            manifestPlaceholders["appName"] = "昭臣打卡"
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".test"
            manifestPlaceholders["appName"] = "打卡测试"
        }
    }

    buildTypes {
        release {
            // 只允许 release 签名；缺失时保持 null，由下方 taskGraph 校验阻断打包，
            // 绝不允许回退到 Debug 签名，防止误发带调试签名的包
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// 打 release 包时若缺少 release 签名配置，配置阶段直接失败（不影响 debug 构建）
val requestingRelease = gradle.startParameter.taskNames.any { name ->
    Regex("assemble.*Release|bundle.*Release|package.*Release|^build$").containsMatchIn(name)
}
val releaseSigningAvailable = extensions.findByType(ApplicationExtension::class.java)
    ?.signingConfigs?.findByName("release") != null
if (requestingRelease && !releaseSigningAvailable) {
    throw GradleException(
        "缺少 release 签名配置，禁止用 Debug 签名打 release 包！" +
            "请在 android/key.properties 中配置 keyAlias/keyPassword/storeFile/storePassword（见 README）"
    )
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}