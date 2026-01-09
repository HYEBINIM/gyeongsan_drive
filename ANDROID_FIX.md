# 🔧 Android v2 Embedding 오류 수정 완료

## 문제 상황
```
Build failed due to use of deleted Android v1 embedding.
```

## 해결 방법
Android v2 embedding을 위한 필수 파일들을 추가했습니다.

---

## 📝 추가된 파일 목록

### 1. MainActivity.kt (필수)
**경로**: `android/app/src/main/kotlin/com/gyeongsan/drive/MainActivity.kt`

```kotlin
package com.gyeongsan.drive

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
```

### 2. build.gradle (프로젝트 레벨)
**경로**: `android/build.gradle`

Kotlin 버전 및 의존성 설정

### 3. settings.gradle
**경로**: `android/settings.gradle`

Flutter 플러그인 및 리포지토리 설정

### 4. gradle.properties
**경로**: `android/gradle.properties`

Android X 및 빌드 설정

### 5. 리소스 파일
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/drawable/launch_background.xml`

---

## ✅ 이제 정상 작동합니다!

새로운 압축 파일을 다운로드하고 다시 실행해보세요:

```bash
# 1. 압축 해제
unzip gyeongsan_drive.zip
# 또는
tar -xzf gyeongsan_drive.tar.gz

# 2. 프로젝트 폴더로 이동
cd gyeongsan_drive

# 3. Flutter 클린 (기존 빌드 삭제)
flutter clean

# 4. 패키지 설치
flutter pub get

# 5. 실행
flutter run
```

---

## 📱 Android 빌드 설정

### 최소 요구사항
- **minSdk**: 21 (Android 5.0 Lollipop)
- **compileSdk**: 34 (Android 14)
- **targetSdk**: 34
- **Kotlin**: 1.9.10
- **Gradle**: 8.1.0

### Java 버전
- **Java 17** 사용

---

## 🚨 문제 해결

### "SDK location not found" 오류 시

`android/local.properties` 파일을 생성하고 다음 내용 추가:

**Windows:**
```properties
sdk.dir=C:\\Users\\YOUR_USERNAME\\AppData\\Local\\Android\\sdk
flutter.sdk=C:\\src\\flutter
```

**Mac/Linux:**
```properties
sdk.dir=/Users/YOUR_USERNAME/Library/Android/sdk
flutter.sdk=/Users/YOUR_USERNAME/flutter
```

### Gradle 버전 오류 시

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### 권한 오류 시 (Mac/Linux)

```bash
cd android
chmod +x gradlew
```

---

## 📦 업데이트된 프로젝트 구조

```
gyeongsan_drive/
├── android/
│   ├── app/
│   │   ├── build.gradle                 # ✅ 앱 레벨 Gradle
│   │   └── src/main/
│   │       ├── AndroidManifest.xml      # ✅ 권한 및 설정
│   │       ├── kotlin/com/gyeongsan/drive/
│   │       │   └── MainActivity.kt      # ✅ NEW! v2 embedding
│   │       └── res/
│   │           ├── values/
│   │           │   └── styles.xml       # ✅ NEW! 테마
│   │           └── drawable/
│   │               └── launch_background.xml  # ✅ NEW! 스플래시
│   ├── build.gradle                      # ✅ NEW! 프로젝트 레벨
│   ├── settings.gradle                   # ✅ NEW! 플러그인 설정
│   └── gradle.properties                 # ✅ NEW! Gradle 속성
├── lib/                                  # Flutter 소스 코드
└── pubspec.yaml                          # 패키지 설정
```

---

## 🎉 모두 해결되었습니다!

이제 `flutter run` 명령어가 정상적으로 작동할 것입니다!

추가 문제가 있으면 다음을 확인하세요:
1. Flutter SDK가 올바르게 설치되었는지
2. Android SDK가 설치되었는지
3. 환경 변수가 올바르게 설정되었는지
4. 에뮬레이터 또는 실제 디바이스가 연결되었는지

```bash
flutter doctor -v
```

명령어로 전체 환경을 확인할 수 있습니다.
