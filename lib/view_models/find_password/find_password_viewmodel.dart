import 'package:flutter/material.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/email_validator.dart';

/// 비밀번호 찾기 화면의 비즈니스 로직을 담당하는 ViewModel
class FindPasswordViewModel extends ChangeNotifier {
  final FirebaseAuthService _authService;

  FindPasswordViewModel({required FirebaseAuthService authService})
    : _authService = authService;

  // 입력 상태
  String _email = '';

  // UI 상태
  bool _isLoading = false;
  String? _errorMessage;
  bool _emailSent = false;

  // Getters
  String get email => _email;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get emailSent => _emailSent;

  // 버튼 활성화 여부 (이메일 형식도 검증)
  bool get isButtonEnabled =>
      _email.isNotEmpty && EmailValidator.isValid(_email);

  /// 이메일 입력 처리
  void setEmail(String email) {
    _email = email.trim();
    _errorMessage = null;
    notifyListeners();
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 비밀번호 재설정 이메일 발송
  /// Firebase의 비밀번호 재설정 기능 사용
  Future<void> submitResetPassword() async {
    // 입력값 검증
    if (_email.isEmpty) {
      _errorMessage = AppConstants.emptyEmail;
      notifyListeners();
      return;
    }

    if (!EmailValidator.isValid(_email)) {
      _errorMessage = AppConstants.invalidEmail;
      notifyListeners();
      return;
    }

    // 로딩 시작
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Firebase 비밀번호 재설정 이메일 발송
      await _authService.sendPasswordResetEmail(_email);

      // 성공 상태 업데이트
      _emailSent = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // 에러 처리
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 상태 초기화
  void reset() {
    _email = '';
    _isLoading = false;
    _errorMessage = null;
    _emailSent = false;
    notifyListeners();
  }
}
