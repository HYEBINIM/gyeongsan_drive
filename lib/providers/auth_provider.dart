import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth/firebase_auth_service.dart';

/// 전역 인증 상태 관리 Provider
/// SSOT(Single Source of Truth): 앱 전체의 인증 상태를 중앙에서 관리
/// DRY 원칙: 인증 체크 로직을 한 곳에 집중
class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService;
  StreamSubscription<User?>? _authStateSubscription;
  User? _currentUser;

  AuthProvider(this._authService) {
    // 한국어 주석: 초기 사용자 설정
    _currentUser = _authService.currentUser;

    // 한국어 주석: Firebase Auth 상태 변화 감지 (로그인/로그아웃 시 자동 업데이트)
    _authStateSubscription = _authService.authStateChanges.listen((user) {
      _currentUser = user;
      notifyListeners(); // 모든 구독자에게 상태 변경 알림
    });
  }

  /// 현재 로그인한 사용자
  User? get currentUser => _currentUser;

  /// 로그인 여부
  bool get isAuthenticated => _currentUser != null;

  /// 이메일 인증 완료 여부
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;

  /// 사용자 UID (안전한 조회)
  String? get userId => _currentUser?.uid;

  /// 사용자 이메일
  String? get userEmail => _currentUser?.email;

  /// 사용자 표시 이름
  String? get displayName => _currentUser?.displayName;

  /// 한국어 주석: 로그인 필수 체크 (ViewModel이나 Widget에서 사용)
  /// 로그인하지 않은 경우 예외 발생
  void requireAuth() {
    if (!isAuthenticated) {
      throw '로그인이 필요합니다';
    }
  }

  /// 한국어 주석: 이메일 인증 필수 체크
  /// 로그인하지 않았거나 이메일 인증이 안 된 경우 예외 발생
  void requireEmailVerified() {
    requireAuth();
    if (!isEmailVerified) {
      throw '이메일 인증이 필요합니다';
    }
  }

  /// 한국어 주석: 필수 UID 조회 (로그인 안 되어 있으면 예외 발생)
  String get requiredUserId {
    final uid = userId;
    if (uid == null) {
      throw '로그인이 필요합니다';
    }
    return uid;
  }

  @override
  void dispose() {
    // 한국어 주석: 메모리 누수 방지를 위해 스트림 구독 해제
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
