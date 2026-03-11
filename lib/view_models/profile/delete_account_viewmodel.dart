import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/database/firestore_database_service.dart';
import '../../services/storage/local_storage_service.dart';

/// 계정 삭제 ViewModel
/// MVVM 패턴에 따라 계정 삭제 관련 비즈니스 로직을 담당
class DeleteAccountViewModel extends ChangeNotifier {
  // Service 의존성 주입
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreDatabaseService _databaseService = FirestoreDatabaseService();
  final LocalStorageService _storageService = LocalStorageService();

  // 상태 관리
  bool _isLoading = false;
  String? _errorMessage;
  String _userProvider = 'password'; // 기본값

  // 재인증 상태
  // 최근 재인증 여부와 시각을 관리하여 민감 작업 전에 강제 확인
  bool _reauthenticated = false;
  DateTime? _reauthenticatedAt;
  static const Duration _reauthValidity = Duration(minutes: 5);

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get userProvider => _userProvider;
  bool get reauthenticated => _reauthenticated;
  DateTime? get reauthenticatedAt => _reauthenticatedAt;
  bool get isReauthValid {
    // 최근 재인증 유효성(기본 5분) 확인
    if (!_reauthenticated || _reauthenticatedAt == null) return false;
    return DateTime.now().difference(_reauthenticatedAt!) <= _reauthValidity;
  }

  // 생성자: Provider 초기화
  DeleteAccountViewModel() {
    _initializeProvider();
  }

  /// Provider 초기화
  void _initializeProvider() {
    _userProvider = _authService.getUserProvider();
  }

  /// 재인증 실행 (삭제와 분리)
  /// [password] 이메일 로그인 사용자의 비밀번호 (구글 로그인 시 null)
  /// 성공 시 true, 실패 시 false 반환
  Future<bool> reauthenticate(String? password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      // Provider에 따라 재인증 방식 분기
      if (_authService.hasGoogleProvider()) {
        // 구글 재인증 시도 (항상 UI 노출 의도)
        await _authService.reauthenticateWithGoogle();
      } else {
        // 이메일/비밀번호 재인증
        if (password == null || password.isEmpty) {
          throw Exception('비밀번호를 입력해주세요');
        }
        await _authService.reauthenticateWithPassword(password);
      }

      // 재인증 성공 처리
      _reauthenticated = true;
      _reauthenticatedAt = DateTime.now();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      return false;
    } catch (e) {
      _errorMessage = '오류: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 계정 삭제
  /// - 삭제 전 최근 재인증이 유효해야 함
  /// 성공 시 true, 실패 시 false 반환
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUser = _authService.currentUser;
      final email = currentUser?.email;

      // 로그인 상태 확인
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 1. 최근 재인증 확인 (삭제 전 강제)
      if (!isReauthValid) {
        _errorMessage = '보안을 위해 먼저 재인증을 완료해주세요';
        return false;
      }

      // 2. Firestore의 사용자 데이터 완전 삭제
      await _databaseService.deleteAllUserData(currentUser.uid, email ?? '');

      // 3. Firebase Auth 계정 삭제
      await currentUser.delete();

      // 4. 로컬 저장소 클리어
      await _storageService.clearAutoLogin();

      // 5. 재인증 상태 초기화 (안전장치)
      _reauthenticated = false;
      _reauthenticatedAt = null;

      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      return false;
    } catch (e) {
      _errorMessage = '오류: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Firebase 에러를 사용자 친화적인 메시지로 변환
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return '비밀번호가 일치하지 않습니다';
      case 'requires-recent-login':
        return '보안을 위해 다시 로그인해주세요';
      case 'user-not-found':
        return '사용자를 찾을 수 없습니다';
      case 'invalid-credential':
        return '인증 정보가 올바르지 않습니다';
      default:
        return '오류: ${e.message}';
    }
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
