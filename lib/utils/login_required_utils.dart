import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../widgets/common/login_required_dialog.dart';

/// 로그인 필요 에러 처리 유틸리티
/// DRY/KISS 원칙 준수: 각 화면에서 중복되는 로그인 분기 로직을 한 곳에 모음
class LoginRequiredUtils {
  static const String _loginRequiredKeyword = '로그인이 필요합니다';

  // 인스턴스 생성 방지
  LoginRequiredUtils._();

  /// 에러 메시지가 로그인 필요 상황인지 여부를 확인
  static bool isLoginRequiredError(String? message) {
    if (message == null) {
      return false;
    }
    return message.contains(_loginRequiredKeyword);
  }

  /// 에러 메시지에 따라 기본 버튼 라벨을 결정
  /// - 로그인 필요: "로그인하기"
  /// - 그 외: "다시 시도"
  static String resolvePrimaryButtonLabel(String? message) {
    return isLoginRequiredError(message) ? '로그인하기' : '다시 시도';
  }

  /// 에러 메시지에 따라 버튼 액션을 분기 처리
  /// - 로그인 필요: 로그인 유도 다이얼로그 → 로그인 화면으로 이동
  /// - 그 외: onRetry 콜백 실행
  static Future<void> handlePrimaryAction({
    required BuildContext context,
    required String? errorMessage,
    required Future<void> Function() onRetry,
    String? returnRoute,
    Object? returnArguments,
  }) async {
    if (isLoginRequiredError(errorMessage)) {
      // 한국어 주석: 로그인 필요 → 공통 바텀시트로 안내
      final shouldLogin = await showLoginRequiredDialog(context);
      if (shouldLogin == true && context.mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.login,
          arguments: <String, dynamic>{
            'returnRoute': returnRoute ?? AppRoutes.mainNavigation,
            'returnArguments': returnArguments,
          },
        );
      }
      return;
    }

    await onRetry();
  }
}
