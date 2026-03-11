import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../services/auth/firebase_auth_service.dart';

/// 인증 관련 공통 로직 Mixin
/// DRY 원칙: 모든 ViewModel에서 중복되던 인증 체크 로직을 한 곳에 집중
/// ViewModel에 mixin하여 인증 기능 재사용
///
/// 사용 예시:
/// ```dart
/// class HomeViewModel extends BaseViewModel with AuthMixin {
///   @override
///   final FirebaseAuthService authService;
///
///   HomeViewModel({required this.authService});
///
///   Future<void> loadData() async {
///     await withLoading(() async {
///       requireAuth(); // Mixin 메서드로 간결한 인증 체크
///       final data = await _service.getData(requiredUserId);
///       // ...
///     });
///   }
/// }
/// ```
mixin AuthMixin on ChangeNotifier {
  /// 한국어 주석: AuthService 인스턴스 (각 ViewModel이 구현)
  /// getter로 선언하여 서브클래스가 제공하도록 강제
  FirebaseAuthService get authService;

  /// 현재 로그인한 사용자 (캐시)
  User? get currentUser => authService.currentUser;

  /// 로그인 여부
  bool get isAuthenticated => currentUser != null;

  /// 이메일 인증 완료 여부
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// 사용자 UID (안전한 조회, null 가능)
  String? get userId => currentUser?.uid;

  /// 사용자 이메일
  String? get userEmail => currentUser?.email;

  /// 사용자 표시 이름
  String? get displayName => currentUser?.displayName;

  /// 한국어 주석: 로그인 필수 체크
  /// 로그인하지 않은 경우 예외 발생
  /// 반환 타입: String? (성공 시 null, 실패 시 에러 메시지)
  String? requireAuth() {
    if (!isAuthenticated) {
      return '로그인이 필요합니다';
    }
    return null; // 성공
  }

  /// 한국어 주석: 로그인 필수 체크 (예외 발생 버전)
  /// 로그인하지 않은 경우 예외를 throw
  /// UI가 아닌 비즈니스 로직에서 사용
  void requireAuthOrThrow() {
    if (!isAuthenticated) {
      throw '로그인이 필요합니다';
    }
  }

  /// 한국어 주석: 이메일 인증 필수 체크
  /// 로그인하지 않았거나 이메일 인증이 안 된 경우 에러 메시지 반환
  String? requireEmailVerified() {
    final authError = requireAuth();
    if (authError != null) return authError;

    if (!isEmailVerified) {
      return '이메일 인증이 필요합니다';
    }
    return null; // 성공
  }

  /// 한국어 주석: 이메일 인증 필수 체크 (예외 발생 버전)
  void requireEmailVerifiedOrThrow() {
    requireAuthOrThrow();
    if (!isEmailVerified) {
      throw '이메일 인증이 필요합니다';
    }
  }

  /// 한국어 주석: 필수 UID 조회
  /// 로그인 안 되어 있으면 예외 발생
  /// null 체크 없이 안전하게 UID 사용 가능
  String get requiredUserId {
    final uid = userId;
    if (uid == null) {
      throw '로그인이 필요합니다';
    }
    return uid;
  }

  /// 한국어 주석: 필수 이메일 조회
  /// 로그인 안 되어 있으면 예외 발생
  String get requiredEmail {
    final email = userEmail;
    if (email == null) {
      throw '로그인이 필요합니다';
    }
    return email;
  }
}
