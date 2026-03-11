import 'dart:async';
import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../utils/constants.dart';
import '../../services/storage/local_storage_service.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/database/firestore_database_service.dart'; // RTDB → Firestore

/// 스플래시 화면의 비즈니스 로직을 담당하는 ViewModel
class SplashViewModel extends ChangeNotifier {
  final LocalStorageService _storageService = LocalStorageService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreDatabaseService _databaseService =
      FirestoreDatabaseService(); // RTDB → Firestore
  Timer? _timer;

  /// 스플래시 화면 타이머 시작
  /// [context]를 받아 지정된 시간 후 온보딩 완료 여부 확인 후 이동
  void startSplashTimer(BuildContext context) {
    _timer = Timer(
      const Duration(seconds: AppConstants.splashDurationSeconds),
      () => _navigateToNextScreen(context),
    );
  }

  /// 다음 화면으로 이동
  /// 온보딩 완료 여부 및 자동 로그인 여부에 따라 적절한 화면으로 이동
  Future<void> _navigateToNextScreen(BuildContext context) async {
    if (!context.mounted) return;

    try {
      // 1. 온보딩 완료 여부 확인
      final isOnboardingComplete = await _storageService.isOnboardingComplete();

      if (!isOnboardingComplete) {
        // 온보딩 미완료 → 온보딩 화면으로 이동
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
        }
        return;
      }

      // 2. 자동 로그인 체크
      final isAutoLoginEnabled = await _storageService.isAutoLoginEnabled();
      final currentUser = _authService.currentUser;

      if (isAutoLoginEnabled &&
          currentUser != null &&
          currentUser.emailVerified) {
        // Firebase 사용자가 존재하고 이메일 인증 완료
        // Database에 사용자 데이터 존재 확인
        final exists = await _databaseService.userExists(currentUser.uid);

        if (exists) {
          // 마지막 로그인 시간 업데이트
          await _databaseService.updateLastLogin(currentUser.uid);

          // 한국어 주석: 자동 로그인 성공 → 홈 탭(index: 0)으로 이동
          if (context.mounted) {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.mainNavigation,
              arguments: 0, // 홈 탭
            );
          }
          return;
        }
      }

      // 한국어 주석: 자동 로그인 실패 또는 비활성화 → 지역정보 탭(index: 2)으로 이동
      // 선택적 로그인 전략: 로그인 없이도 공개 콘텐츠 이용 가능
      if (context.mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.mainNavigation,
          arguments: 2, // 지역정보 탭 (로그인 불필요)
        );
      }
    } catch (e) {
      // 에러 발생 시 기본적으로 온보딩 화면으로 이동
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
    }
  }

  /// ViewModel이 dispose될 때 타이머 정리
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
