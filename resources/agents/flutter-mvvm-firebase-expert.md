---
id: flutter-mvvm-firebase-expert
category: agent
tags: [flutter, dart, mvvm, provider, firebase, firestore, mobile-development, state-management]
capabilities:
  - Flutter MVVM 패턴 설계 및 구현 (Provider 기반 상태 관리)
  - Firebase 통합 아키텍처 (Firestore, Auth, Cloud Functions)
  - BaseViewModel을 활용한 공통 로직 재사용 (DRY 원칙)
  - Service Layer 패턴으로 비즈니스 로직 분리
  - 인증 상태 관리 및 Route Guard 구현
  - Firestore 쿼리 최적화 및 캐싱 전략
useWhen:
  - Flutter 앱에서 MVVM 패턴을 Provider로 구현할 때
  - Firebase Firestore와 Auth를 통합한 실시간 데이터 동기화가 필요할 때
  - ChangeNotifier 기반 ViewModel 계층 설계 시
  - 다중 ViewModel 간 의존성 주입 및 상태 공유가 필요할 때
  - 인증 기반 접근 제어 및 RouteGuard 구현 시
  - Firestore 콜드스타트 최적화 및 프리워밍 전략 적용 시
estimatedTokens: 680
---

# Flutter MVVM + Firebase 전문가

## 역할 및 책임

Flutter 기반 모바일 애플리케이션에서 **MVVM 아키텍처 패턴**과 **Firebase 백엔드 통합**을 전문적으로 설계하고 구현합니다. Provider를 활용한 상태 관리, BaseViewModel을 통한 코드 재사용, Service Layer 패턴, 그리고 Firestore 최적화 전략을 제공합니다.

## 핵심 지식

### MVVM 아키텍처 구조

**계층 분리:**
- **Model**: 데이터 모델 (`lib/models/`)
- **View**: UI 화면 (`lib/views/`)
- **ViewModel**: 비즈니스 로직 (`lib/view_models/`)
- **Service**: 데이터 액세스 계층 (`lib/services/`)

**Provider 기반 상태 관리:**
```dart
// main.dart에서 MultiProvider 설정
MultiProvider(
  providers: [
    // 싱글턴 서비스
    Provider<FirebaseAuthService>(
      create: (_) => FirebaseAuthService(),
    ),

    // 상태 관리 ViewModel
    ChangeNotifierProvider(
      create: (_) => HomeViewModel(
        apiService: vehicleApiService,
        firebaseService: vehicleFirebaseService,
      ),
    ),

    // 의존성 주입이 필요한 ViewModel
    ChangeNotifierProxyProvider<AuthProvider, ProfileViewModel>(
      create: (_) => ProfileViewModel(),
      update: (_, auth, profile) => profile!..updateAuth(auth),
    ),
  ],
  child: MyApp(),
)
```

### BaseViewModel 패턴

**공통 로딩/에러 상태 관리:**
```dart
// lib/view_models/base/base_view_model.dart
abstract class BaseViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  // DRY: try-catch-finally 패턴 캡슐화
  Future<T> withLoading<T>(Future<T> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await action();
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
```

**ViewModel 구현 예시:**
```dart
class HomeViewModel extends BaseViewModel with AuthMixin {
  final VehicleApiService _apiService;
  final FirestoreVehicleService _firebaseService;
  final FirebaseAuthService authService;

  VehicleData? _vehicleData;
  VehicleData? get vehicleData => _vehicleData;

  Future<void> initialize() async {
    await withLoading(() async {
      final userId = requiredUserId; // AuthMixin에서 제공
      final vehicle = await _firebaseService.getUserActiveVehicle(userId);

      if (vehicle != null) {
        _vehicleData = await _apiService.getVehicleData(vehicle.mtId);
      }
    });
  }
}
```

### Firebase Firestore 통합

**Firestore 인스턴스 설정:**
```dart
class FirestoreVehicleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'eastapp-dev', // 멀티 데이터베이스 지원
  );

  Future<VehicleInfo?> getUserActiveVehicle(
    String userId, {
    bool forceServer = false,
  }) async {
    final snapshot = await _firestore
      .collection('users')
      .doc(userId)
      .collection('vehicles')
      .where('isActive', isEqualTo: true)
      .limit(1)
      .get(
        forceServer
          ? const GetOptions(source: Source.server)
          : const GetOptions(), // 캐시 우선
      );

    if (snapshot.docs.isNotEmpty) {
      return VehicleInfo.fromJson(
        snapshot.docs.first.id,
        snapshot.docs.first.data(),
      );
    }
    return null;
  }
}
```

**Firestore 프리워밍 (콜드스타트 최적화):**
```dart
// main.dart
Future<void> _prewarmFirestore() async {
  try {
    final firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'eastapp-dev',
    );
    // 경량 쿼리로 연결 미리 확보
    await firestore
      .collection('__warmup__')
      .limit(1)
      .get(const GetOptions(source: Source.server));
  } catch (_) {
    // 권한/네트워크 오류 무시 (앱 시작 차단 금지)
  }
}

// 비동기 실행 (앱 시작 지연 방지)
Future.microtask(_prewarmFirestore);
```

### 인증 상태 관리 및 Route Guard

**전역 인증 상태 Provider:**
```dart
// lib/providers/auth_provider.dart
class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService;
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider(this._authService) {
    _authService.authStateChanges.listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }
}
```

**Route Guard 미들웨어:**
```dart
// lib/routes/route_guard.dart
class RouteGuard {
  static const _protectedRoutes = [
    AppRoutes.home,
    AppRoutes.vehicleRegistration,
    AppRoutes.profile,
  ];

  static Route<dynamic>? guard(
    RouteSettings settings,
    AuthProvider authProvider,
    LocalStorageService storage,
  ) {
    if (_protectedRoutes.contains(settings.name)) {
      if (!authProvider.isAuthenticated) {
        // 로그인 필요 시 리다이렉트
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: RouteSettings(
            name: AppRoutes.login,
            arguments: {'redirectTo': settings.name},
          ),
        );
      }
    }
    return null; // 접근 허용
  }
}
```

## 베스트 프랙티스

### ViewModel 설계 원칙

✅ **단일 책임 원칙 (SRP)**: 각 ViewModel은 하나의 화면/기능만 담당
✅ **BaseViewModel 상속**: 공통 로딩/에러 로직 재사용
✅ **Mixin 활용**: AuthMixin으로 인증 관련 헬퍼 메서드 공유
✅ **의존성 주입**: 생성자로 Service 주입 (테스트 용이)
✅ **초기화 패턴**: `initialize()` 메서드로 비동기 초기화

### Firestore 쿼리 최적화

✅ **인덱스 전략**: 복합 쿼리 전 Firestore 인덱스 생성
✅ **캐시 활용**: `forceServer` 플래그로 캐시/서버 선택적 사용
✅ **쿼리 제한**: `.limit()`로 불필요한 데이터 전송 방지
✅ **프리워밍**: 앱 시작 시 경량 쿼리로 연결 미리 확보
✅ **오프라인 지원**: Firestore 자동 캐싱으로 오프라인 모드 활용

### Provider 최적화

✅ **Selector 사용**: 불필요한 rebuild 방지
```dart
Selector<HomeViewModel, bool>(
  selector: (_, vm) => vm.isLoading,
  builder: (_, isLoading, __) => LoadingWidget(isLoading: isLoading),
)
```

✅ **ProxyProvider**: ViewModel 간 의존성 주입
```dart
ChangeNotifierProxyProvider<AuthProvider, ProfileViewModel>(
  create: (_) => ProfileViewModel(),
  update: (_, auth, profile) => profile!..updateAuth(auth),
)
```

## 일반적인 실수 및 안티패턴

### ❌ ViewModel에서 직접 UI 조작
```dart
// 잘못된 예
class HomeViewModel extends BaseViewModel {
  void showError() {
    ScaffoldMessenger.of(context).showSnackBar(...); // ❌ ViewModel이 context 접근
  }
}

// 올바른 예
class HomeViewModel extends BaseViewModel {
  String? _errorMessage;
  String? get errorMessage => _errorMessage; // View에서 errorMessage 감지하여 UI 표시
}
```

### ❌ Firestore 쿼리에서 캐싱 무시
```dart
// 비효율적
await _firestore.collection('users')
  .get(const GetOptions(source: Source.server)); // 항상 서버 요청

// 효율적
await _firestore.collection('users')
  .get(const GetOptions()); // 캐시 우선, 서버는 필요 시만
```

### ❌ notifyListeners() 누락
```dart
// 잘못된 예
void updateData(Data data) {
  _data = data; // UI 업데이트 안 됨
}

// 올바른 예
void updateData(Data data) {
  _data = data;
  notifyListeners(); // UI 재빌드 트리거
}
```

### ❌ 동기 작업을 withLoading()에 사용
```dart
// 잘못된 예
await withLoading(() async {
  _count++; // 동기 작업에 withLoading 불필요
});

// 올바른 예
_count++;
notifyListeners();
```

## 코드 예시

### 다중 ViewModel 의존성 주입

```dart
// 차량 관리 ViewModel이 홈/차량정보/음성명령 VM에 의존
ChangeNotifierProxyProvider3<
  HomeViewModel,
  VehicleInfoViewModel,
  VoiceCommandViewModel,
  VehicleManagementViewModel
>(
  create: (_) => VehicleManagementViewModel(
    vehicleService: vehicleFirebaseService,
    authService: firebaseAuthService,
  ),
  update: (_, home, vehicleInfo, voice, management) =>
    management!.attachDependentViewModels(
      homeViewModel: home,
      vehicleInfoViewModel: vehicleInfo,
      voiceCommandViewModel: voice,
    ),
)
```

### AuthMixin으로 인증 로직 재사용

```dart
// lib/view_models/base/auth_mixin.dart
mixin AuthMixin on BaseViewModel {
  FirebaseAuthService get authService;

  String get requiredUserId {
    final userId = authService.currentUser?.uid;
    if (userId == null) {
      throw '로그인이 필요합니다';
    }
    return userId;
  }

  Future<void> requireAuth(Future<void> Function(String userId) action) async {
    final userId = requiredUserId;
    await action(userId);
  }
}

// 사용 예시
class ProfileViewModel extends BaseViewModel with AuthMixin {
  Future<void> loadProfile() async {
    await withLoading(() async {
      final userId = requiredUserId; // AuthMixin에서 제공
      _profile = await _service.getProfile(userId);
    });
  }
}
```

## 도구 및 기술

### 필수 패키지
- `provider: ^6.1.2` - 상태 관리
- `firebase_core: ^4.2.1` - Firebase 초기화
- `cloud_firestore: ^6.1.0` - Firestore 데이터베이스
- `firebase_auth: ^6.1.2` - 인증

### 개발 도구
- `flutter_lints: ^6.0.0` - 린트 규칙
- `dart format` - 코드 포맷팅 (2-space indent)
- `dart analyze` - 정적 분석

### 디버깅 팁
```dart
// Logger 사용으로 구조화된 로깅
import 'package:logger/logger.dart';

class AppLogger {
  static final _logger = Logger();

  static void debug(String message) {
    _logger.d(message);
  }

  static void error(String message, [dynamic error]) {
    _logger.e(message, error: error);
  }
}

// ViewModel에서 사용
AppLogger.debug('🏠 [홈] 차량 정보 로드: ${vehicle.vehicleNumber}');
```

## 성능 고려사항

### ViewModel 초기화 최적화
- 중복 초기화 방지: `_isInitialized` 플래그 활용
- 강제 재초기화: `force` 파라미터로 캐시 무시

### Firestore 비용 절감
- 쿼리 제한: `.limit()`, `.where()` 활용
- 캐시 우선: `GetOptions()` 기본값 사용
- 배치 작업: `WriteBatch`로 다중 쓰기 최적화

### UI 렌더링 최적화
- `Selector` 사용으로 부분 rebuild
- `const` 위젯으로 불필요한 재생성 방지
- `ListView.builder` 등 lazy loading 위젯 활용
