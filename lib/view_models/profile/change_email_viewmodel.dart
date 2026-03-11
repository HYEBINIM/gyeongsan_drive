import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/database/firestore_database_service.dart';

/// 이메일 변경 ViewModel
/// 이메일 변경 및 Firestore 동기화를 담당
class ChangeEmailViewModel extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreDatabaseService _databaseService = FirestoreDatabaseService();

  bool _isLoading = false;
  String? _errorMessage;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// 현재 사용자 이메일 가져오기
  String get currentEmail => _authService.currentUser?.email ?? '';

  /// 이메일 변경 요청
  /// 1. 현재 비밀번호로 재인증
  /// 2. 새 이메일로 인증 이메일 발송
  Future<bool> requestEmailChange(
    String currentPassword,
    String newEmail,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUser = _authService.currentUser;
      final currentEmail = currentUser?.email;

      if (currentUser == null || currentEmail == null) {
        throw '로그인된 사용자가 없습니다.';
      }

      // 1. 현재 비밀번호로 재인증
      final credential = EmailAuthProvider.credential(
        email: currentEmail,
        password: currentPassword,
      );
      await currentUser.reauthenticateWithCredential(credential);

      // 2. 새 이메일로 인증 이메일 발송
      await currentUser.verifyBeforeUpdateEmail(newEmail);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          _errorMessage = '비밀번호가 일치하지 않습니다';
          break;
        case 'email-already-in-use':
          _errorMessage = '이미 사용 중인 이메일입니다';
          break;
        case 'invalid-email':
          _errorMessage = '유효하지 않은 이메일 형식입니다';
          break;
        case 'requires-recent-login':
          _errorMessage = '보안을 위해 다시 로그인해주세요';
          break;
        default:
          _errorMessage = '오류: ${e.message}';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Firestore 이메일 동기화
  /// 사용자가 이메일 인증 완료 후 호출 (Firebase Auth 이메일 변경 완료 상태)
  Future<bool> syncFirestoreEmail(String oldEmail, String newEmail) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUser = _authService.currentUser;

      if (currentUser == null) {
        throw '로그인된 사용자가 없습니다.';
      }

      final uid = currentUser.uid;

      // Firestore 및 emailIndex 업데이트
      await _databaseService.updateEmail(uid, oldEmail, newEmail);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
