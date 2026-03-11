import 'package:flutter/material.dart';

/// 스낵바 공통 유틸리티
///
/// 일관된 UX/UI를 제공하기 위한 스낵바 헬퍼 함수 모음
///
/// 특징:
/// - Material 3 플로팅 스타일 적용
/// - 앱 로고 아이콘 표시
/// - 타입별 색상 및 Duration 표준화
/// - DRY 원칙 적용 (코드 중복 제거)
///
/// 사용 예시:
/// ```dart
/// SnackBarUtils.showSuccess(context, '작업이 완료되었습니다');
/// SnackBarUtils.showError(context, '오류가 발생했습니다');
/// SnackBarUtils.showWarning(context, '권한이 필요합니다');
/// SnackBarUtils.showInfo(context, '설정이 변경되었습니다');
/// ```
class SnackBarUtils {
  // 한국어 주석: private constructor (유틸리티 클래스는 인스턴스 생성 불가)
  SnackBarUtils._();

  /// 앱 로고 경로
  static const String _appLogoPath = 'assets/icons/ic_app.png';

  /// 앱 로고 아이콘 위젯 크기
  static const double _iconSize = 24.0;

  /// 스낵바 둥근 모서리 반경
  static const double _borderRadius = 12.0;

  /// 스낵바 패딩
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  );

  /// 성공 메시지 스낵바 표시
  ///
  /// [context]: BuildContext
  /// [message]: 표시할 메시지
  /// [duration]: 표시 시간 (기본값: 2초)
  ///
  /// 사용 예시:
  /// ```dart
  /// SnackBarUtils.showSuccess(context, '프로필이 업데이트되었습니다');
  /// ```
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: colorScheme.secondaryContainer,
      textColor: colorScheme.onSurface,
      duration: duration,
    );
  }

  /// 에러 메시지 스낵바 표시
  ///
  /// [context]: BuildContext
  /// [message]: 표시할 메시지
  /// [duration]: 표시 시간 (기본값: 3초)
  ///
  /// 사용 예시:
  /// ```dart
  /// SnackBarUtils.showError(context, '로그인에 실패했습니다');
  /// ```
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: colorScheme.secondaryContainer,
      textColor: colorScheme.onSurface,
      duration: duration,
    );
  }

  /// 경고 메시지 스낵바 표시
  ///
  /// [context]: BuildContext
  /// [message]: 표시할 메시지
  /// [duration]: 표시 시간 (기본값: 3초)
  ///
  /// 사용 예시:
  /// ```dart
  /// SnackBarUtils.showWarning(context, '백그라운드 권한이 필요합니다');
  /// ```
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: colorScheme.secondaryContainer,
      textColor: colorScheme.onSurface,
      duration: duration,
    );
  }

  /// 정보 메시지 스낵바 표시
  ///
  /// [context]: BuildContext
  /// [message]: 표시할 메시지
  /// [duration]: 표시 시간 (기본값: 2초)
  ///
  /// 사용 예시:
  /// ```dart
  /// SnackBarUtils.showInfo(context, '목적지가 설정되었습니다');
  /// ```
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: colorScheme.secondaryContainer,
      textColor: colorScheme.onSurface,
      duration: duration,
    );
  }

  /// 스낵바 표시 공통 로직 (DRY 원칙)
  ///
  /// [context]: BuildContext
  /// [message]: 표시할 메시지
  /// [backgroundColor]: 배경색
  /// [textColor]: 텍스트 색상
  /// [duration]: 표시 시간
  static void _showSnackBar({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required Color textColor,
    required Duration duration,
  }) {
    // 한국어 주석: 기존 스낵바가 있으면 제거 (중복 표시 방지)
    ScaffoldMessenger.of(context).clearSnackBars();

    // 한국어 주석: 텍스트 너비 측정
    final textPainter = TextPainter(
      text: TextSpan(
        text: message,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    // 한국어 주석: 총 너비 계산 (아이콘 + 간격 + 텍스트 + 패딩 + 여유)
    final contentWidth = _iconSize + 12 + textPainter.width + 32 + 16;
    final screenWidth = MediaQuery.of(context).size.width;
    final snackBarWidth = contentWidth.clamp(150.0, screenWidth - 32);

    // 한국어 주석: 새 스낵바 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        width: snackBarWidth, // 한국어 주석: 동적 너비
        content: Row(
          mainAxisSize: MainAxisSize.min, // 한국어 주석: 콘텐츠 크기에 맞춤
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 한국어 주석: 앱 로고 아이콘
            Image.asset(
              _appLogoPath,
              width: _iconSize,
              height: _iconSize,
              errorBuilder: (context, error, stackTrace) {
                // 한국어 주석: 이미지 로드 실패 시 기본 아이콘 표시
                return Icon(
                  Icons.info_outline,
                  size: _iconSize,
                  color: textColor,
                );
              },
            ),
            const SizedBox(width: 12),
            // 한국어 주석: 메시지 텍스트 (가운데 정렬)
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating, // 한국어 주석: 플로팅 스타일
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
        // 한국어 주석: width와 margin은 동시에 사용할 수 없으므로
        // 동적 너비를 유지하고 margin은 기본값을 사용합니다.
        padding: _padding,
        duration: duration,
        elevation: 4,
      ),
    );
  }
}
