import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// key.properties 파일에서 키스토어 정보 로드
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        // 한국어 주석: use 블록으로 스트림을 안전하게 닫아 리소스 누수 방지
        keystoreProperties.load(stream)
    }
}

android {
    namespace = "com.eastcompany.east"

    // SDK 버전 명시 (플러그인 요구사항: Android SDK 36)
    compileSdk = 36  // Android 15 QPR2 (API 36)
    ndkVersion = flutter.ndkVersion

    // 한국어 주석: flutter_local_notifications가 요구하는 desugaring 활성화 및 Java 17 정렬
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // BuildConfig 클래스 생성 활성화 (디버그 모드 확인용)
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.eastcompany.east"

        // SDK 버전 명시
        minSdk = flutter.minSdkVersion      // Android 6.0 (Marshmallow) - 플레이 스토어 권장
        targetSdk = 36   // Android 15 QPR2 (API 36)

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 다국어 리소스 최적화 (한국어, 영어만 포함)
        resourceConfigurations += listOf("ko", "en")

        // 벡터 드로어블 지원 (Android 5.0 미만 기기용)
        vectorDrawables.useSupportLibrary = true
    }

    // 서명 설정
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 프로덕션 서명 설정 (key.properties가 있는 경우)
            // key.properties가 없으면 debug 키로 폴백 (로컬 개발용)
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // ProGuard/R8 최적화 및 난독화 활성화
            isMinifyEnabled = true
            isShrinkResources = true

            // ProGuard 규칙 파일 적용
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

dependencies {
    // 한국어 주석: Java 8+ API를 하위 버전에서도 사용 가능하게 하는 desugar 라이브러리
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Android 12+ Splash Screen API 지원
    implementation("androidx.core:core-splashscreen:1.0.1")

    implementation(platform("com.google.firebase:firebase-bom:34.5.0"))
}
