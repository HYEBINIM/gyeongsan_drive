import 'package:flutter/material.dart';
import '../../services/auth/firebase_auth_service.dart';

/// 비밀번호 변경 ViewModel
/// 비밀번호 변경 기능을 담당
class ChangePasswordViewModel extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();

  bool _isLoading = false;
  String? _errorMessage;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// 비밀번호 변경
  /// 1. 현재 비밀번호로 재인증
  /// 2. 새 비밀번호로 변경
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUser = _authService.currentUser;

      if (currentUser == null) {
        throw '로그인된 사용자가 없습니다.';
      }

      // 1. 현재 비밀번호로 재인증
      await _authService.reauthenticateWithPassword(currentPassword);

      // 2. 새 비밀번호로 변경
      await currentUser.updatePassword(newPassword);

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
