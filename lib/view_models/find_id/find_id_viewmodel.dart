import 'package:flutter/material.dart';
import '../../services/functions/cloud_functions_service.dart';
import '../../utils/constants.dart';
import '../../utils/email_validator.dart';

/// 아이디 찾기 화면의 비즈니스 로직을 담당하는 ViewModel
class FindIdViewModel extends ChangeNotifier {
  final CloudFunctionsService _functionsService;

  FindIdViewModel({required CloudFunctionsService functionsService})
    : _functionsService = functionsService;

  // 입력 상태
  String _name = '';
  String _email = '';

  // UI 상태
  bool _isLoading = false;
  String? _errorMessage;
  bool _foundId = false; // 아이디 찾기 성공 여부
  String _maskedEmail = ''; // 마스킹된 이메일

  // Getters
  String get name => _name;
  String get email => _email;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get foundId => _foundId; // emailSent 대신 foundId 사용
  String get maskedEmail => _maskedEmail;

  // 버튼 활성화 여부
  bool get isButtonEnabled => _name.isNotEmpty && _email.isNotEmpty;

  /// 이름 입력 처리
  void setName(String name) {
    _name = name.trim();
    _errorMessage = null;
    notifyListeners();
  }

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

  /// 아이디 찾기 제출
  /// Cloud Function을 통해 서버 사이드에서 안전하게 처리
  /// - Rate limiting으로 무차별 대입 공격 방지
  /// - 이름 + 이메일 2단계 검증
  /// - 계정 존재 여부와 관계없이 동일한 응답 (이메일 열거 공격 방지)
  Future<void> submitFindId() async {
    // 입력값 검증
    if (_name.isEmpty) {
      _errorMessage = AppConstants.emptyName;
      notifyListeners();
      return;
    }

    if (_name.length < 2) {
      _errorMessage = AppConstants.invalidName;
      notifyListeners();
      return;
    }

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
      // Cloud Function 호출 (서버 사이드에서 안전하게 처리)
      final result = await _functionsService.findUserIdByNameAndEmail(
        name: _name,
        email: _email,
      );

      // 결과 처리
      if (result.verified) {
        // 아이디 찾기 성공
        _foundId = true;
        _maskedEmail = result.maskedEmail;
        _errorMessage = null;
      } else {
        // 아이디 찾기 실패
        _foundId = false;
        _maskedEmail = '';
        _errorMessage = result.message;
      }

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
    _name = '';
    _email = '';
    _isLoading = false;
    _errorMessage = null;
    _foundId = false;
    _maskedEmail = '';
    notifyListeners();
  }
}
