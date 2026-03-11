import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 권한 거부 시 표시할 경고 다이얼로그
class PermissionDeniedDialog extends StatelessWidget {
  /// 설정으로 이동 버튼 클릭 시 호출되는 콜백
  final VoidCallback onSettingsPressed;

  /// 앱 종료 버튼 클릭 시 호출되는 콜백
  final VoidCallback onExitPressed;

  const PermissionDeniedDialog({
    super.key,
    required this.onSettingsPressed,
    required this.onExitPressed,
  });

  @override
  Widget build(BuildContext context) {
    // 한국어 주석: 뒤로가기 버튼으로 다이얼로그 닫기 허용
    return PopScope(
      canPop: true,
      child: AlertDialog(
        title: const Text(
          AppConstants.permissionDeniedTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: AppConstants.fontFamilyBig,
          ),
        ),
        content: const Text(
          AppConstants.permissionDeniedMessage,
          style: TextStyle(
            fontSize: 14,
            fontFamily: AppConstants.fontFamilySmall,
          ),
        ),
        actions: [
          // 앱 종료 버튼
          TextButton(
            onPressed: onExitPressed,
            child: const Text(AppConstants.exitAppButton),
          ),

          // 설정으로 이동 버튼
          ElevatedButton(
            onPressed: onSettingsPressed,
            child: const Text(AppConstants.goToSettingsButton),
          ),
        ],
      ),
    );
  }
}
