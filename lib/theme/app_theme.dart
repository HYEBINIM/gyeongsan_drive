import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import '../utils/constants.dart';

/// 앱 전역 테마 정의
/// 로우 라이트(Low Light) 다크 테마에 최적화
class AppTheme {
  AppTheme._(); // private constructor to prevent instantiation

  /// 로우 라이트 테마 (메인 테마)
  /// 저조도 환경에 최적화된 어두운 테마
  static ThemeData get lowLightTheme {
    return ThemeData.dark().copyWith(
      // 로우 라이트 색상 스키마 적용
      colorScheme: AppColors.lowLightScheme,

      // AppBar 테마
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0, // 스크롤 시 색상 변화 방지
        backgroundColor: AppColors.lowLightScheme.surface,
        foregroundColor: AppColors.lowLightScheme.onSurface,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light, // 밝은 아이콘 (다크 배경용)
          statusBarBrightness: Brightness.dark,
        ),
      ),

      // Scaffold 배경색
      scaffoldBackgroundColor: AppColors.lowLightScheme.surface,

      // Card 테마
      cardTheme: CardThemeData(
        color: AppColors.lowLightScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ElevatedButton 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lowLightScheme.primary,
          foregroundColor: AppColors.lowLightScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // TextButton 테마
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lowLightScheme.primary,
        ),
      ),

      // OutlinedButton 테마
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lowLightScheme.primary,
          side: BorderSide(color: AppColors.lowLightScheme.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // InputDecoration 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lowLightScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.lowLightScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.lowLightScheme.error,
            width: 2,
          ),
        ),
      ),

      // BottomNavigationBar 테마
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lowLightScheme.surface,
        selectedItemColor: AppColors.lowLightScheme.primary,
        unselectedItemColor: AppColors.lowLightScheme.onSurface.withValues(
          alpha: 0.6,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Divider 테마
      dividerTheme: DividerThemeData(
        color: AppColors.lowLightScheme.onSurface.withValues(alpha: 0.12),
        thickness: 1,
      ),

      // 텍스트 테마 (KakaoFont 적용)
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        displayMedium: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        displaySmall: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        headlineLarge: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        headlineMedium: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        headlineSmall: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        titleLarge: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        titleMedium: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        titleSmall: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        bodyLarge: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        bodyMedium: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        bodySmall: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        labelLarge: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        labelMedium: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        labelSmall: TextStyle(fontFamily: AppConstants.fontFamilySmall),
      ),
    );
  }

  /// 일반 다크 테마 (옵션)
  /// 필요 시 사용 가능한 대안 테마
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      colorScheme: AppColors.darkScheme,
      // 필요 시 추가 커스터마이징
    );
  }

  /// 라이트 테마
  /// Spotify 감성의 밝은 테마
  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      // Spotify 라이트 색상 스키마 적용
      colorScheme: AppColors.lightScheme,

      // AppBar 테마
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0, // 스크롤 시 색상 변화 방지
        backgroundColor: AppColors.lightScheme.surface,
        foregroundColor: AppColors.lightScheme.onSurface,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark, // 밝은 배경에 어두운 아이콘
          statusBarBrightness: Brightness.light,
        ),
      ),

      // Scaffold 배경색
      scaffoldBackgroundColor: AppColors.lightScheme.surface,

      // Card 테마
      cardTheme: CardThemeData(
        color: AppColors.lightScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ElevatedButton 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightScheme.primary,
          foregroundColor: AppColors.lightScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // TextButton 테마
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightScheme.primary,
        ),
      ),

      // OutlinedButton 테마
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightScheme.primary,
          side: BorderSide(color: AppColors.lightScheme.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // InputDecoration 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.lightScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.lightScheme.error, width: 2),
        ),
      ),

      // BottomNavigationBar 테마
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightScheme.surface,
        selectedItemColor: AppColors.lightScheme.primary,
        unselectedItemColor: AppColors.lightScheme.onSurface.withValues(
          alpha: 0.6,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Divider 테마
      dividerTheme: DividerThemeData(
        color: AppColors.lightScheme.outlineVariant,
        thickness: 1,
      ),

      // 텍스트 테마 (KakaoFont 적용)
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        displayMedium: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        displaySmall: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        headlineLarge: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        headlineMedium: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        headlineSmall: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        titleLarge: TextStyle(fontFamily: AppConstants.fontFamilyBig),
        titleMedium: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        titleSmall: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        bodyLarge: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        bodyMedium: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        bodySmall: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        labelLarge: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        labelMedium: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        labelSmall: TextStyle(fontFamily: AppConstants.fontFamilySmall),
      ),
    );
  }
}
