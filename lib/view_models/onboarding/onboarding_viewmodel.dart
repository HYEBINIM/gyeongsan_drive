import 'package:flutter/material.dart';
import '../../services/storage/local_storage_service.dart';
import '../../routes/app_routes.dart';
import '../../utils/snackbar_utils.dart';

/// 온보딩 화면의 비즈니스 로직을 담당하는 ViewModel
/// 권한 설명만 표시하고, 실제 권한 요청은 각 기능 사용 시점에 수행
class OnboardingViewModel extends ChangeNotifier {
  final LocalStorageService _storageService = LocalStorageService();

  /// 한국어 주석: 온보딩 완료 - 로그인 선택
  /// SharedPreferences에 완료 상태 저장 후 로그인 화면으로 이동
  Future<void> completeWithLogin(BuildContext context) async {
    try {
      // 온보딩 완료 상태 저장
      await _storageService.setOnboardingComplete();

      // 로그인 화면으로 이동
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (e) {
      // 에러 발생 시 사용자에게 알림
      if (context.mounted) {
        SnackBarUtils.showError(context, '온보딩 완료 처리 중 오류가 발생했습니다: $e');
      }
    }
  }

  /// 한국어 주석: 온보딩 완료 - 둘러보기 선택
  /// SharedPreferences에 완료 상태 저장 후 지역정보 탭으로 이동 (비로그인 상태)
  Future<void> completeWithoutLogin(BuildContext context) async {
    try {
      // 온보딩 완료 상태 저장
      await _storageService.setOnboardingComplete();

      // 한국어 주석: 지역정보 탭(index: 2)으로 이동 (로그인 불필요)
      if (context.mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.mainNavigation,
          arguments: 2, // 지역정보 탭
        );
      }
    } catch (e) {
      // 에러 발생 시 사용자에게 알림
      if (context.mounted) {
        SnackBarUtils.showError(context, '온보딩 완료 처리 중 오류가 발생했습니다: $e');
      }
    }
  }

  /// 한국어 주석: [DEPRECATED] 기존 메서드 (하위 호환성 유지)
  /// completeWithLogin() 사용 권장
  @Deprecated('Use completeWithLogin() instead')
  Future<void> completeOnboarding(BuildContext context) async {
    return completeWithLogin(context);
  }
}
