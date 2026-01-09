# 경산 버스 투어 (Gyeongsan Drive)

노선버스 연계 지역 명소·문화유산 안내 서비스

## 📱 프로젝트 개요

경산 버스 투어는 버스 탑승자를 위한 지역 명소 안내 서비스입니다. 실시간 위치 기반으로 주변 정류장과 관광지 정보를 제공하며, 버스 도착 정보와 연계하여 맞춤형 여행 경로를 추천합니다.

## ✨ 주요 기능

### 1단계 (현재 구현)
- ✅ 실시간 현재 위치 추적
- ✅ 주변 버스 정류장 마커 표시 (네이버 지도)
- ✅ 정류장별 버스 도착 정보 표시
- ✅ 주변 관광지/맛집/카페 추천
- ✅ 장소별 상세 정보 제공

### 2단계 (추후 개발)
- ⏳ 버스 노선별 경로 표시
- ⏳ 버스 탑승 시 자동 추천 서비스
- ⏳ 맞춤형 관광 코스 추천
- ⏳ 실시간 문화행사 정보
- ⏳ SNS 연동 핫플레이스 랭킹

## 🛠 기술 스택

- **Framework**: Flutter 3.35.5
- **Language**: Dart 3.5.0
- **Map SDK**: 네이버 지도 (flutter_naver_map)
- **State Management**: Riverpod
- **HTTP Client**: Dio
- **Database**: SharedPreferences (로컬 저장)

## 📦 주요 패키지

```yaml
dependencies:
  flutter_naver_map: ^1.3.3      # 네이버 지도
  geolocator: ^13.0.2            # GPS 위치
  permission_handler: ^11.3.1    # 권한 관리
  dio: ^5.7.0                    # HTTP 통신
  flutter_riverpod: ^2.6.1       # 상태 관리
  google_fonts: ^6.2.1           # 폰트
  url_launcher: ^6.3.1           # URL 실행
```

## 🚀 설치 및 실행

### 사전 준비

1. **Flutter SDK 설치**
   ```bash
   # Flutter 3.35.5 설치
   git clone https://github.com/flutter/flutter.git -b stable
   export PATH="$PATH:`pwd`/flutter/bin"
   flutter doctor
   ```

2. **네이버 지도 API 키 발급**
   - [네이버 클라우드 플랫폼](https://www.ncloud.com/)에서 Maps API 키 발급
   - Client ID 획득

3. **공공 API 키 발급**
   - [공공데이터포털](https://www.data.go.kr/)에서 버스 정보 API 키 발급
   - [한국관광공사](https://www.visitkorea.or.kr/)에서 관광 정보 API 키 발급

### 프로젝트 설정

1. **패키지 설치**
   ```bash
   cd gyeongsan_drive
   flutter pub get
   ```

2. **API 키 설정**

   파일 경로: `lib/main.dart`, `lib/services/bus_api_service.dart`, `lib/services/tourist_spot_service.dart`, `android/app/src/main/AndroidManifest.xml`
   
   ```dart
   // main.dart에서 네이버 지도 Client ID 설정
   await NaverMapSdk.instance.initialize(
     clientId: 'YOUR_NAVER_MAP_CLIENT_ID', // 여기에 발급받은 키 입력
   );
   
   // bus_api_service.dart에서 API 키 설정
   static const String _daeguApiKey = 'YOUR_DAEGU_API_KEY_HERE';
   static const String _gyeongsanApiKey = 'YOUR_GYEONGSAN_API_KEY_HERE';
   
   // tourist_spot_service.dart에서 API 키 설정
   static const String _tourApiKey = 'YOUR_TOUR_API_KEY_HERE';
   ```

3. **안드로이드 설정**
   ```xml
   <!-- android/app/src/main/AndroidManifest.xml -->
   <meta-data
       android:name="com.naver.maps.map.CLIENT_ID"
       android:value="YOUR_NAVER_MAP_CLIENT_ID" />
   ```

4. **iOS 설정** (iOS 개발 시)
   ```xml
   <!-- ios/Runner/Info.plist -->
   <key>NMFClientId</key>
   <string>YOUR_NAVER_MAP_CLIENT_ID</string>
   ```

### 실행

```bash
# Android 에뮬레이터 또는 실제 기기에서 실행
flutter run

# 릴리즈 빌드
flutter build apk --release
flutter build ios --release
```

## 📁 프로젝트 구조

```
gyeongsan_drive/
├── lib/
│   ├── main.dart                 # 앱 진입점
│   ├── models/                   # 데이터 모델
│   │   ├── bus_stop.dart        # 버스 정류장 모델
│   │   ├── bus.dart             # 버스 및 도착 정보 모델
│   │   └── tourist_spot.dart    # 관광지 모델
│   ├── services/                 # API 서비스
│   │   ├── location_service.dart      # 위치 서비스
│   │   ├── bus_api_service.dart       # 버스 API
│   │   └── tourist_spot_service.dart  # 관광지 API
│   ├── screens/                  # 화면
│   │   ├── splash_screen.dart   # 스플래시 화면
│   │   └── home_screen.dart     # 메인 지도 화면
│   ├── widgets/                  # 위젯
│   │   ├── bus_stop_bottom_sheet.dart    # 정류장 정보 바텀시트
│   │   └── spot_list_bottom_sheet.dart   # 명소 리스트 바텀시트
│   └── utils/                    # 유틸리티
├── android/                      # Android 설정
├── ios/                          # iOS 설정
└── test/                         # 테스트
```

## 🎯 사용 시나리오

### 시나리오 1: 주변 정류장 찾기
1. 앱 실행 → 자동으로 현재 위치 표시
2. 지도에서 주변 정류장 마커 확인
3. 정류장 마커 클릭 → 버스 도착 정보 확인

### 시나리오 2: 관광지 탐색
1. "주변 명소 보기" 버튼 클릭
2. 카테고리별 필터링 (관광지/맛집/카페 등)
3. 원하는 장소 선택 → 상세 정보 확인
4. 길찾기 또는 전화 연결

### 시나리오 3: 버스 탑승 중 (추후 개발)
1. 버스 번호 선택
2. 현재 버스 노선 및 다음 정류장 확인
3. 정류장별 주변 추천 장소 자동 표시
4. "여기서 내릴까요?" 알림

## 🔧 개발 가이드

### 더미 데이터 → 실제 API 연동

현재 프로젝트는 개발 편의를 위해 더미 데이터를 사용합니다. 실제 API를 연동하려면 다음 파일을 수정하세요:

1. **버스 API 연동** (`lib/services/bus_api_service.dart`)
   ```dart
   // _getDummyBusStops() → 실제 API 호출로 교체
   Future<List<BusStop>> getNearbyBusStops({...}) async {
     final response = await _dio.get(
       '$_daeguBaseUrl/getNearbyBusStops',
       queryParameters: {
         'serviceKey': _daeguApiKey,
         'lat': latitude,
         'lon': longitude,
         'radius': radius,
       },
     );
     // API 응답 파싱
   }
   ```

2. **관광지 API 연동** (`lib/services/tourist_spot_service.dart`)
   ```dart
   // _getDummyTouristSpots() → 실제 API 호출로 교체
   ```

### 새로운 기능 추가

1. **버스 노선 표시**
   - `lib/screens/bus_route_screen.dart` 생성
   - Polyline을 사용하여 지도에 노선 그리기

2. **북마크 기능**
   - SharedPreferences 또는 로컬 DB (sqflite) 사용
   - 즐겨찾기 정류장/장소 저장

3. **알림 기능**
   - `flutter_local_notifications` 패키지 사용
   - 버스 도착 알림, 주변 명소 알림

## 📄 API 문서

### 사용 가능한 공공 API

1. **대구 버스 정보**
   - URL: http://apis.data.go.kr/6270000/dgBusService
   - 제공: 정류장 정보, 버스 도착 정보, 노선 정보

2. **경북 버스 정보**
   - URL: http://apis.data.go.kr/6470000/gyeongbukBusSttnInfoInqireService
   - 제공: 경산 지역 버스 정보

3. **한국관광공사 Tour API**
   - URL: http://apis.data.go.kr/B551011/KorService1
   - 제공: 관광지, 맛집, 문화시설 정보

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 라이선스

This project is licensed under the MIT License.

## 👥 팀

**담당 파트**: 노선버스 연계 지역 명소·문화유산 안내 서비스

## 📞 문의

프로젝트 관련 문의사항이 있으시면 이슈를 등록해주세요.

---

**경산 버스 투어**로 더 편리하고 즐거운 여행을 경험하세요! 🚌✨
