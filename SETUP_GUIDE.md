# 경산 버스 투어 - 설치 및 설정 가이드

## 목차
1. [개발 환경 설정](#개발-환경-설정)
2. [API 키 발급](#api-키-발급)
3. [프로젝트 설정](#프로젝트-설정)
4. [실행 및 테스트](#실행-및-테스트)
5. [문제 해결](#문제-해결)

---

## 개발 환경 설정

### 1. Flutter SDK 설치

**Windows:**
```bash
# Flutter SDK 다운로드
git clone https://github.com/flutter/flutter.git -b stable
cd flutter
bin\flutter doctor
```

**macOS/Linux:**
```bash
# Flutter SDK 다운로드
git clone https://github.com/flutter/flutter.git -b stable
cd flutter
export PATH="$PATH:`pwd`/bin"
flutter doctor
```

### 2. 필수 도구 설치

- **Android Studio**: Android 개발용 IDE
  - Android SDK 설치
  - Android Emulator 설정
  
- **Xcode** (macOS만): iOS 개발용
  - CocoaPods 설치: `sudo gem install cocoapods`

- **VS Code** (권장): 가볍고 빠른 에디터
  - Flutter 확장 설치
  - Dart 확장 설치

---

## API 키 발급

### 1. 네이버 지도 API (필수)

1. [네이버 클라우드 플랫폼](https://www.ncloud.com/) 회원가입
2. Console → Services → AI·Application Service → Maps
3. "Application 등록" 클릭
4. 애플리케이션 이름 입력: `경산 버스 투어`
5. 서비스 환경:
   - ✅ Web Dynamic Map
   - ✅ Android
   - ✅ iOS
6. Bundle ID 입력:
   - Android: `com.gyeongsan.drive`
   - iOS: `com.gyeongsan.drive`
7. **Client ID** 복사 (예: `abcdefghijk123`)

### 2. 대구 버스 정보 API (필수)

1. [공공데이터포털](https://www.data.go.kr/) 회원가입
2. 검색: "대구광역시 버스정보시스템 운행정보 조회 서비스"
3. "활용신청" 클릭
4. 상세 기능 명세:
   - 노선 기본정보 조회
   - 정류소 정보 조회
   - 노선별 정류소 정보 조회
   - 정류소별 도착예정 정보 조회
5. **인증키(Decoding)** 복사

### 3. 경북 버스 정보 API (선택)

1. [공공데이터포털](https://www.data.go.kr/)
2. 검색: "경상북도_버스정류소정보조회서비스"
3. "활용신청" 클릭
4. **인증키(Decoding)** 복사

### 4. 한국관광공사 Tour API (선택)

1. [공공데이터포털](https://www.data.go.kr/)
2. 검색: "한국관광공사_국문 관광정보 서비스"
3. "활용신청" 클릭
4. **인증키(Decoding)** 복사

---

## 프로젝트 설정

### 1. 프로젝트 클론 및 패키지 설치

```bash
# 프로젝트 디렉토리로 이동
cd gyeongsan_drive

# 패키지 설치
flutter pub get

# JSON 직렬화 코드 생성
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. API 키 설정

#### 방법 1: 직접 파일 수정 (개발용)

**lib/screens/home_screen.dart**
```dart
await NaverMapSdk.instance.initialize(
  clientId: 'YOUR_NAVER_MAP_CLIENT_ID', // 여기에 네이버 지도 Client ID 입력
);
```

**lib/services/bus_api_service.dart**
```dart
static const String _daeguApiKey = 'YOUR_DAEGU_API_KEY_HERE';
static const String _gyeongsanApiKey = 'YOUR_GYEONGSAN_API_KEY_HERE';
```

**lib/services/tourist_spot_service.dart**
```dart
static const String _tourApiKey = 'YOUR_TOUR_API_KEY_HERE';
```

**android/app/src/main/AndroidManifest.xml**
```xml
<meta-data
    android:name="com.naver.maps.map.CLIENT_ID"
    android:value="YOUR_NAVER_MAP_CLIENT_ID" />
```

#### 방법 2: 환경 변수 사용 (권장, 프로덕션)

1. `lib/config/api_keys.dart` 파일 생성:
```dart
class ApiKeys {
  static const String naverMapClientId = String.fromEnvironment(
    'NAVER_MAP_CLIENT_ID',
    defaultValue: 'YOUR_NAVER_MAP_CLIENT_ID',
  );
  
  static const String daeguBusApiKey = String.fromEnvironment(
    'DAEGU_BUS_API_KEY',
    defaultValue: 'YOUR_DAEGU_API_KEY',
  );
  
  static const String gyeongsanBusApiKey = String.fromEnvironment(
    'GYEONGSAN_BUS_API_KEY',
    defaultValue: 'YOUR_GYEONGSAN_API_KEY',
  );
  
  static const String tourApiKey = String.fromEnvironment(
    'TOUR_API_KEY',
    defaultValue: 'YOUR_TOUR_API_KEY',
  );
}
```

2. 실행 시 환경 변수 전달:
```bash
flutter run --dart-define=NAVER_MAP_CLIENT_ID=your_actual_key
```

### 3. Android 설정

**android/app/build.gradle** (이미 설정됨)
```gradle
android {
    compileSdk = 34
    defaultConfig {
        minSdk = 21
        targetSdk = 34
    }
}
```

### 4. iOS 설정 (macOS에서만)

**ios/Runner/Info.plist**
```xml
<key>NMFClientId</key>
<string>YOUR_NAVER_MAP_CLIENT_ID</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>현재 위치를 확인하여 주변 버스 정류장과 관광지를 표시합니다.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>백그라운드에서도 위치를 추적하여 버스 탑승 중 추천 서비스를 제공합니다.</string>
```

---

## 실행 및 테스트

### 1. 에뮬레이터/시뮬레이터 실행

**Android Emulator:**
```bash
# 사용 가능한 에뮬레이터 확인
flutter emulators

# 에뮬레이터 실행
flutter emulators --launch <emulator_id>
```

**iOS Simulator (macOS만):**
```bash
open -a Simulator
```

### 2. 앱 실행

**개발 모드:**
```bash
# 기본 실행
flutter run

# 특정 디바이스에서 실행
flutter run -d <device_id>

# 디바이스 목록 확인
flutter devices
```

**릴리즈 모드:**
```bash
# Android APK 빌드
flutter build apk --release

# iOS IPA 빌드 (macOS만)
flutter build ios --release
```

### 3. Hot Reload 사용

앱 실행 중에 코드를 수정하면:
- **r** 키 입력: Hot Reload (상태 유지하며 UI 업데이트)
- **R** 키 입력: Hot Restart (앱 재시작)
- **q** 키 입력: 종료

---

## 문제 해결

### 자주 발생하는 오류

#### 1. "SDK location not found"

**해결:**
```bash
# Android SDK 경로 설정
# Windows: C:\Users\<username>\AppData\Local\Android\sdk
# macOS/Linux: ~/Library/Android/sdk

# local.properties 파일 생성 (android/ 폴더 안)
echo "sdk.dir=/path/to/android/sdk" > android/local.properties
```

#### 2. 네이버 지도가 표시되지 않음

**체크리스트:**
- [ ] Client ID가 올바르게 설정되었는지 확인
- [ ] AndroidManifest.xml에 meta-data가 있는지 확인
- [ ] 인터넷 권한이 있는지 확인
- [ ] 위치 권한이 승인되었는지 확인

**해결:**
```bash
# 앱 완전히 제거 후 재설치
flutter clean
flutter pub get
flutter run
```

#### 3. "Gradle build failed"

**해결:**
```bash
# Gradle 캐시 삭제
cd android
./gradlew clean

# 프로젝트 클린
cd ..
flutter clean
flutter pub get
```

#### 4. "PlatformException: location_service_disabled"

**해결:**
- 디바이스의 위치 서비스 활성화
- 설정 → 위치 → 켜기

#### 5. iOS 빌드 오류

**해결:**
```bash
# CocoaPods 재설치
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter run
```

### 로그 확인

**자세한 로그 보기:**
```bash
flutter run -v
```

**특정 로그 필터링:**
```bash
# Android
adb logcat | grep -i flutter

# iOS
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "Runner"'
```

---

## 추가 리소스

- [Flutter 공식 문서](https://docs.flutter.dev/)
- [네이버 지도 Android SDK](https://navermaps.github.io/android-map-sdk/guide-ko/)
- [공공데이터포털 API 가이드](https://www.data.go.kr/tcs/dss/selectApiDataDetailView.do)
- [Flutter 패키지](https://pub.dev/)

---

## 다음 단계

프로젝트가 성공적으로 실행되면:

1. **더미 데이터 → 실제 API 연동**
   - `lib/services/` 폴더의 서비스 파일들 수정
   
2. **새로운 기능 추가**
   - 버스 노선 표시
   - 북마크 기능
   - 알림 기능

3. **UI/UX 개선**
   - 커스텀 마커 디자인
   - 애니메이션 추가
   - 다크 모드 지원

문의사항이 있으시면 이슈를 등록해주세요! 🚀
