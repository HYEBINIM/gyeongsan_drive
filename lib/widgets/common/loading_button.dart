import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 로딩 상태를 지원하는 범용 버튼 위젯
/// 로딩 중에는 CircularProgressIndicator를 표시하고 버튼을 비활성화합니다.
class LoadingButton extends StatelessWidget {
  /// 버튼에 표시할 텍스트
  final String text;

  /// 버튼 클릭 시 실행할 콜백
  final VoidCallback? onPressed;

  /// 로딩 상태 (true일 경우 스피너 표시 및 버튼 비활성화)
  final bool isLoading;

  /// 버튼 배경색 (null인 경우 테마의 primary 색상 사용)
  final Color? backgroundColor;

  /// 버튼 텍스트 색상 (null인 경우 테마의 onPrimary 색상 사용)
  final Color? textColor;

  /// 버튼 테두리 색상 (null인 경우 테두리 없음)
  final Color? borderColor;

  /// 버튼 왼쪽에 표시할 아이콘 위젯 (선택적)
  final Widget? icon;

  /// 버튼 높이 (Material 3 권장: 최소 48, 이상적 52)
  final double height;

  const LoadingButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.icon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveBackgroundColor = backgroundColor ?? colorScheme.primary;
    final effectiveTextColor = textColor ?? colorScheme.onPrimary;

    // Material 3 비활성화 색상 (38% 투명도)
    final disabledBackgroundColor = colorScheme.onSurface.withValues(
      alpha: 0.12,
    );
    final disabledTextColor = colorScheme.onSurface.withValues(alpha: 0.38);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveTextColor,
          disabledBackgroundColor: disabledBackgroundColor,
          disabledForegroundColor: disabledTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: borderColor != null
                ? BorderSide(color: borderColor!, width: 1)
                : BorderSide.none,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          // Material 3 패딩 (수평 24, 수직 충분한 공간)
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  // 로딩 중에는 primary 색상으로 스피너 표시 (가시성 향상)
                  color: colorScheme.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 12)],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: effectiveTextColor,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
