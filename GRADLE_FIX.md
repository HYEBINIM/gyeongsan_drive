# 🔧 Gradle/Java 호환성 문제 해결

## 문제 상황
```
Unsupported class file major version 65
BUG! exception in phase 'semantic analysis'
```

이는 **Java 21**을 사용 중이고, Gradle 버전이 이를 지원하지 않는 문제입니다.

---

## ✅ 해결 완료!

다음 파일들을 추가/업데이트했습니다:

1. **gradle-wrapper.properties** - Gradle 8.5 사용 (Java 21 호환)
2. **gradlew.bat** - Windows용 Gradle wrapper
3. **settings.gradle** - AGP 8.3.0으로 업데이트
4. **build.gradle** - Kotlin 1.9.22로 업데이트

---

## 📥 새 파일 다운로드 (가장 빠름!)

압축 파일을 다시 다운로드하고 실행하세요.

---

## 🔧 기존 프로젝트 수정

이미 압축을 푼 경우, 다음 파일을 생성/수정하세요:

### 1. gradle-wrapper.properties 생성

**경로**: `android/gradle/wrapper/gradle-wrapper.properties`

```properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-all.zip
```

### 2. settings.gradle 수정

**경로**: `android/settings.gradle`

**20-22번째 줄을 다음과 같이 변경:**
```gradle
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.3.0" apply false    // 8.1.0 → 8.3.0
    id "org.jetbrains.kotlin.android" version "1.9.22" apply false  // 1.9.10 → 1.9.22
}
```

### 3. build.gradle 수정

**경로**: `android/build.gradle`

**2번째 줄:**
```gradle
ext.kotlin_version = '1.9.22'  // 1.9.10 → 1.9.22
```

**7번째 줄:**
```gradle
classpath 'com.android.tools.build:gradle:8.3.0'  // 8.1.0 → 8.3.0
```

---

## 🚀 실행 방법

```powershell
# 1. Gradle 캐시 삭제
cd android
Remove-Item -Recurse -Force .gradle
cd ..

# 2. Flutter 클린
flutter clean

# 3. 패키지 설치
flutter pub get

# 4. 실행
flutter run
```

---

## 📊 버전 호환성 표

| Java 버전 | Gradle 버전 | AGP 버전 |
|-----------|-------------|----------|
| Java 17 | 7.5+ | 7.4+ |
| Java 21 | **8.5+** ✅ | **8.3+** ✅ |

현재 설정:
- ✅ Gradle 8.5 (Java 21 지원)
- ✅ AGP 8.3.0
- ✅ Kotlin 1.9.22

---

## 💡 추가 문제 해결

### "Could not find gradle-wrapper.jar" 오류 시

Gradle wrapper를 다시 생성하세요:

```powershell
cd android
.\gradlew.bat wrapper --gradle-version=8.5
cd ..
flutter clean
flutter run
```

### Java 버전 확인

```powershell
java -version
```

**출력 예시:**
```
openjdk version "21.0.1" 2023-10-17 LTS
```

### Gradle 버전 확인

```powershell
cd android
.\gradlew.bat --version
```

---

## 🎯 정리

| 항목 | 이전 | 수정 후 |
|------|------|---------|
| Gradle | 8.0 ❌ | 8.5 ✅ |
| AGP | 8.1.0 | 8.3.0 ✅ |
| Kotlin | 1.9.10 | 1.9.22 ✅ |
| Java 21 지원 | ❌ | ✅ |

---

이제 **flutter run**이 정상 작동할 것입니다! 🎉

만약 여전히 문제가 있다면:
1. 기존 프로젝트 폴더 완전 삭제
2. 새 압축 파일 다운로드
3. 압축 해제 후 실행

```powershell
cd "C:\Users\HB\Documents\1. project"
Remove-Item -Recurse -Force gyeongsan_drive
# 새 파일 압축 해제
cd gyeongsan_drive
flutter clean
flutter pub get
flutter run
```
