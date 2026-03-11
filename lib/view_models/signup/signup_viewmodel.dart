import 'package:flutter/material.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/database/firestore_database_service.dart'; // RTDB → Firestore
import '../../models/user_model.dart';
import '../../models/notification_settings.dart';
import '../../routes/app_routes.dart';
import '../../utils/constants.dart';
import '../../utils/email_validator.dart';

/// 회원가입 단계
enum SignupStep {
  nameInput, // 이름 입력
  emailInput, // 이메일 입력
  emailVerification, // 이메일 검증 대기
  passwordInput, // 비밀번호 설정
  termsAgreement, // 약관 동의
}

/// 회원가입 화면의 비즈니스 로직을 담당하는 ViewModel
class SignupViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreDatabaseService _databaseService =
      FirestoreDatabaseService(); // RTDB → Firestore

  SignupStep _currentStep = SignupStep.nameInput;
  String _userName = '';
  String? _userEmail;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // 비밀번호 입력 상태
  String _password = '';

  // 비밀번호 검증 상태
  final Map<String, bool> _validationStatus = {
    'length': false,
    'letter': false,
    'number': false,
    'special': false,
  };

  // 약관 동의 상태
  bool _agreedToService = false;
  bool _agreedToPrivacy = false;
  bool _agreedToLocation = false;
  bool _isOver14 = false;

  SignupStep get currentStep => _currentStep;
  String get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // 첫 단계(이름 입력)인지 확인
  bool get isFirstStep => _currentStep == SignupStep.nameInput;

  // 약관 동의 getter
  bool get agreedToService => _agreedToService;
  bool get agreedToPrivacy => _agreedToPrivacy;
  bool get agreedToLocation => _agreedToLocation;
  bool get isOver14 => _isOver14;

  // 검증 상태 외부 노출용 getter
  Map<String, bool> get validationStatus => _validationStatus;

  // 모든 필수 약관에 동의했는지 확인
  bool get isAllTermsAgreed =>
      _agreedToService && _agreedToPrivacy && _agreedToLocation && _isOver14;

  // 전체 동의 여부 (모든 약관에 동의했는지)
  bool get isAllAgreed => isAllTermsAgreed;

  // 모든 비밀번호 조건 충족 여부
  bool get isPasswordValid => _validationStatus.values.every((v) => v);

  // 비밀번호 설정 단계 "다음" 버튼 활성화 여부
  bool get isPasswordNextButtonEnabled {
    return _password.isNotEmpty && isPasswordValid && !_isLoading;
  }

  // 약관 동의 단계 "회원가입 완료" 버튼 활성화 여부
  bool get isCompleteButtonEnabled {
    return isAllTermsAgreed && !_isLoading;
  }

  /// 실시간 비밀번호 검증
  void _validatePassword(String password) {
    _validationStatus['length'] = password.length >= 8;
    _validationStatus['letter'] = password.contains(RegExp(r'[a-zA-Z]'));
    _validationStatus['number'] = password.contains(RegExp(r'[0-9]'));
    _validationStatus['special'] = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );
  }

  /// 앱 라이프사이클 감지 (포그라운드 복귀 시 검증 체크)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _currentStep == SignupStep.emailVerification) {
      _checkVerificationOnResume();
    }
  }

  /// 이름 입력 및 다음 단계로 이동
  void submitName(String name) {
    // 유효성 검증
    if (name.trim().isEmpty) {
      _errorMessage = AppConstants.emptyName;
      notifyListeners();
      return;
    }

    if (name.trim().length < 2) {
      _errorMessage = AppConstants.invalidName;
      notifyListeners();
      return;
    }

    // 이름 저장 및 다음 단계로 이동
    _userName = name.trim();
    _currentStep = SignupStep.emailInput;
    _errorMessage = null;
    notifyListeners();
  }

  /// 이메일 검증 메일 발송 (미완료 계정 처리 포함)
  Future<void> sendVerificationEmail(String email) async {
    if (!EmailValidator.isValid(email)) {
      _errorMessage = AppConstants.invalidEmail;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.createTempAccountWithEmail(email);
      _userEmail = email;
      _currentStep = SignupStep.emailVerification;
      _errorMessage = null;
    } catch (e) {
      // email-already-in-use 에러 처리
      final errorMessage = e.toString();
      if (errorMessage.contains('이미 사용 중인 이메일입니다')) {
        await _handleEmailAlreadyInUse(email);
      } else {
        _errorMessage = errorMessage;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 이메일 중복 시 미완료 계정 처리
  Future<void> _handleEmailAlreadyInUse(String email) async {
    try {
      final result = await _authService.handleIncompleteAccount(
        email,
        _databaseService,
      );

      if (result == IncompleteAccountResult.resetRequired) {
        // 미완료 계정 → 비밀번호 재설정 안내
        _errorMessage =
            '이전에 가입을 시도했던 이메일입니다.\n'
            '비밀번호 재설정 이메일을 발송했습니다.\n'
            '이메일을 확인하여 비밀번호를 재설정한 후 로그인해주세요.';
      } else if (result == IncompleteAccountResult.duplicate) {
        // 완료된 계정 → 중복 에러
        _errorMessage = '이미 가입된 이메일입니다. 로그인해주세요.';
      }
    } catch (e) {
      _errorMessage = '계정 확인 중 오류가 발생했습니다: $e';
    }
  }

  /// 검증 이메일 재전송
  Future<void> resendVerificationEmail() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendEmailVerification();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 앱 복귀 시 검증 상태 자동 확인
  Future<void> _checkVerificationOnResume() async {
    try {
      final isVerified = await _authService.checkEmailVerified();
      if (isVerified) {
        _currentStep = SignupStep.passwordInput;
        _successMessage = AppConstants.verificationComplete;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      // 에러 무시 (백그라운드 체크)
    }
  }

  /// 사용자가 직접 인증 완료 여부를 확인할 때 호출
  /// - 한국어 주석: 웹/특정 환경에서 lifecycle 복귀 이벤트가 호출되지 않는 경우를 대비한 수동 확인 버튼 지원
  Future<void> checkEmailVerification() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isVerified = await _authService.checkEmailVerified();
      if (isVerified) {
        _currentStep = SignupStep.passwordInput;
        _successMessage = AppConstants.verificationComplete;
        _errorMessage = null;
      } else {
        _errorMessage = AppConstants.emailNotVerified;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 비밀번호 설정 완료 후 약관 동의 단계로 이동
  void moveToTermsAgreement() {
    // 비밀번호 검증
    if (_password.isEmpty || !isPasswordValid) {
      _errorMessage = '비밀번호 조건을 모두 충족해주세요';
      notifyListeners();
      return;
    }

    // 약관 동의 단계로 이동
    _currentStep = SignupStep.termsAgreement;
    _errorMessage = null;
    notifyListeners();
  }

  /// 회원가입 완료 (약관 동의 후)
  Future<void> completeSignup(BuildContext context) async {
    // 방어 코드: 비밀번호가 없으면 이전 단계로
    if (_password.isEmpty || !isPasswordValid) {
      _errorMessage = '비밀번호를 다시 설정해주세요';
      _currentStep = SignupStep.passwordInput;
      notifyListeners();
      return;
    }

    // 약관 동의 검증
    if (!isAllTermsAgreed) {
      _errorMessage = AppConstants.termsNotAgreedError;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 비밀번호 업데이트 (_password 직접 사용)
      await _authService.updatePassword(_password);

      // displayName 업데이트 (Firebase Auth에 동기화)
      await _authService.updateDisplayName(_userName);

      // 사용자 데이터를 데이터베이스에 저장
      final user = _authService.currentUser;
      if (user != null) {
        // UserModel 생성 시 displayName과 약관 동의 정보, 기본 알림 설정 포함
        final userModel = UserModel.fromFirebaseUser(user).copyWith(
          displayName: _userName,
          agreedToService: _agreedToService,
          agreedToPrivacy: _agreedToPrivacy,
          agreedToLocation: _agreedToLocation,
          isOver14: _isOver14,
          termsAgreedAt: DateTime.now(),
          notificationSettings: NotificationSettings.defaults(), // 기본 알림 설정
        );
        await _databaseService.saveUserData(userModel);
      }

      // 홈 화면으로 이동
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.mainNavigation);
      }
    } catch (e) {
      // 회원가입 실패 시 생성된 계정 삭제 (롤백)
      try {
        await _authService.deleteCurrentUser();
      } catch (deleteError) {
        // 삭제 실패는 무시
      }

      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 전체 동의 토글
  void toggleAllAgreed(bool value) {
    _agreedToService = value;
    _agreedToPrivacy = value;
    _agreedToLocation = value;
    _isOver14 = value;
    _errorMessage = null;
    notifyListeners();
  }

  /// 이용약관 동의 토글
  void toggleServiceAgreed(bool value) {
    _agreedToService = value;
    _errorMessage = null;
    notifyListeners();
  }

  /// 개인정보 처리방침 동의 토글
  void togglePrivacyAgreed(bool value) {
    _agreedToPrivacy = value;
    _errorMessage = null;
    notifyListeners();
  }

  /// 위치기반 서비스 약관 동의 토글
  void toggleLocationAgreed(bool value) {
    _agreedToLocation = value;
    _errorMessage = null;
    notifyListeners();
  }

  /// 만 14세 이상 확인 토글
  void toggleOver14(bool value) {
    _isOver14 = value;
    _errorMessage = null;
    notifyListeners();
  }

  /// 비밀번호 입력 감지
  void setPassword(String password) {
    _password = password;
    _validatePassword(password); // 실시간 검증
    notifyListeners();
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 이전 단계로 이동 (첫 단계가 아닐 때만 호출)
  void goToPreviousStep() {
    // 한국어 주석: 방어 코드 - 첫 단계에서는 호출되지 않아야 함
    if (_currentStep == SignupStep.nameInput) return;

    // 이전 단계로 이동
    switch (_currentStep) {
      case SignupStep.emailInput:
        _currentStep = SignupStep.nameInput;
        break;
      case SignupStep.emailVerification:
        _currentStep = SignupStep.emailInput;
        break;
      case SignupStep.passwordInput:
        _currentStep = SignupStep.emailVerification;
        break;
      case SignupStep.termsAgreement:
        _currentStep = SignupStep.passwordInput;
        break;
      case SignupStep.nameInput:
        // 첫 단계는 여기까지 오지 않음
        break;
    }

    // DRY: 에러 메시지 초기화 및 알림은 한 번만
    _errorMessage = null;
    notifyListeners();
  }
}
