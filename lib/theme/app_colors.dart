import 'package:flutter/material.dart';

/// 앱 전역 색상 스키마 정의
/// - 스포티파이 감성으로 재조정(짙은 다크 중립 + Spotify Green 포인트)
class AppColors {
  AppColors._();

  // Premium Minimal Dark Scheme (세련된 딥 다크)
  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF1ED760), // Signature Green
    onPrimary: Color(0xFF000000), // Black text on Green
    // 배경: 거의 완전한 블랙으로 깊이감 부여
    surface: Color(0xFF050505),
    onSurface: Color(0xFFFFFFFF), // Pure White for crisp text
    // 보조/비활성: 쿨 그레이 톤으로 세련미 추가
    secondary: Color(0xFF8E8E93),
    onSecondary: Color(0xFF000000),
    outline: Color(0xFF333333),
    outlineVariant: Color(0xFF262626),

    error: Color(0xFFFF453A), // iOS Style Red
    onError: Color(0xFF000000),

    // 컨테이너 계열: 아주 미세한 단계로 구분 (Flat & Minimal)
    surfaceContainerLowest: Color(0xFF000000),
    surfaceContainerLow: Color(0xFF1A1A1A), // 주요 카드 배경 (고급스러운 다크 그레이)
    surfaceContainer: Color(0xFF242424),
    surfaceContainerHigh: Color(0xFF2C2C2C),
    surfaceContainerHighest: Color(0xFF383838),

    // 역상
    inverseSurface: Color(0xFFFFFFFF),
    onInverseSurface: Color(0xFF000000),
    inversePrimary: Color(0xFF1FDF64),
    scrim: Color(0xB3000000),
    shadow: Color(0xFF000000),

    // 컨테이너
    primaryContainer: Color(0xFF1ED760),
    onPrimaryContainer: Color(0xFF000000),
    secondaryContainer: Color(0xFF2C2C2E),
    onSecondaryContainer: Color(0xFFFFFFFF),
    tertiary: Color(0xFF64D2FF), // Cool Blue accent if needed
    onTertiary: Color(0xFF000000),
  );

  // 저조도(OLED) 버전 - Dark Scheme과 통합하여 일관성 유지
  static final lowLightScheme = darkScheme;

  // Clean Minimal Light Scheme (깨끗한 화이트 & 쿨 그레이)
  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1ED760),
    onPrimary: Color(0xFFFFFFFF),

    // 배경: 순백색
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF000000), // Pure Black
    // 보조/비활성
    secondary: Color(0xFF8E8E93),
    onSecondary: Color(0xFFFFFFFF),
    outline: Color(0xFFE5E5EA),
    outlineVariant: Color(0xFFF2F2F7),

    error: Color(0xFFFF3B30),
    onError: Color(0xFFFFFFFF),

    // 컨테이너 계열
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF4F5F7), // 주요 카드 배경 (아주 연한 쿨 그레이)
    surfaceContainer: Color(0xFFEEF0F2),
    surfaceContainerHigh: Color(0xFFE5E8EB),
    surfaceContainerHighest: Color(0xFFE1E4E8),

    // 역상
    inverseSurface: Color(0xFF1C1C1E),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFF1FDF64),
    scrim: Color(0x66000000),
    shadow: Color(0x00000000),

    // 컨테이너
    primaryContainer: Color(0xFFE8FAF0), // 아주 연한 민트
    onPrimaryContainer: Color(0xFF001807),
    secondaryContainer: Color(0xFFF2F2F7),
    onSecondaryContainer: Color(0xFF000000),
    tertiary: Color(0xFF5AC8FA),
    onTertiary: Color(0xFFFFFFFF),
  );

  // ThemeData 헬퍼: Scaffold 배경을 surface로 동기화
  static ThemeData themeFrom(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface, // ← 중요
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      dividerColor: scheme.surfaceContainerHighest,
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
