import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../services/storage/local_storage_service.dart';
import '../views/login/login_screen.dart'; // 한국어 주석: LoginScreen import 경로 수정
import '../views/main/main_navigation_screen.dart';
import 'app_routes.dart';

/// 라우트 메타데이터
/// 각 라우트의 접근 제어 정책을 선언적으로 정의
class RouteMetadata {
  final bool requiresAuth; // 로그인 필수
  final bool requiresEmailVerified; // 이메일 인증 필수
  final bool requiresOnboarding; // 온보딩 완료 필수

  const RouteMetadata({
    this.requiresAuth = false,
    this.requiresEmailVerified = false,
    this.requiresOnboarding = false,
  });
}

/// Route Guard 미들웨어
/// KISS 원칙: 중앙 집중식 라우트 접근 제어로 복잡도 감소
/// DRY 원칙: 각 화면에서 중복되던 인증 체크를 한 곳에 집중
class RouteGuard {
  static const String _emailVerificationRequiredMessage =
      '이메일 인증 후 이용 가능한 기능입니다. 지역정보 탭으로 이동합니다.';

  // 한국어 주석: 라우트별 메타데이터 맵 (선언적 정의)
  static final Map<String, RouteMetadata> _routeMetadata = {
    // === 로그인 필수 라우트 ===
    AppRoutes.home: const RouteMetadata(
      requiresAuth: true,
      requiresEmailVerified: true,
    ),

    // 프로필 관련
    AppRoutes.profile: const RouteMetadata(requiresAuth: true),
    AppRoutes.profileEdit: const RouteMetadata(requiresAuth: true),
    AppRoutes.changePassword: const RouteMetadata(requiresAuth: true),
    AppRoutes.changeEmail: const RouteMetadata(requiresAuth: true),
    AppRoutes.deleteAccount: const RouteMetadata(requiresAuth: true),

    // 차량 관련
    AppRoutes.vehicleRegistration: const RouteMetadata(
      requiresAuth: true,
      requiresEmailVerified: true,
    ),
    AppRoutes.vehicleManagement: const RouteMetadata(requiresAuth: true),

    // 안전귀가
    AppRoutes.safeHome: const RouteMetadata(
      requiresAuth: true,
      requiresEmailVerified: true,
    ),
    AppRoutes.safeHomeSettings: const RouteMetadata(requiresAuth: true),

    // 설정
    AppRoutes.appSettings: const RouteMetadata(requiresAuth: true),
    AppRoutes.notificationSettings: const RouteMetadata(requiresAuth: true),

    // 문의
    AppRoutes.inquiryList: const RouteMetadata(requiresAuth: true),
    AppRoutes.inquiryCreate: const RouteMetadata(requiresAuth: true),
    AppRoutes.inquiryDetail: const RouteMetadata(requiresAuth: true),

    // === 공개 라우트 (로그인 불필요) ===
    AppRoutes.splash: const RouteMetadata(),
    AppRoutes.onboarding: const RouteMetadata(),
    AppRoutes.login: const RouteMetadata(),
    AppRoutes.signup: const RouteMetadata(),
    AppRoutes.findId: const RouteMetadata(),
    AppRoutes.findPassword: const RouteMetadata(),
    AppRoutes.mainNavigation: const RouteMetadata(), // 탭 내부에서 제어
    AppRoutes.navigation: const RouteMetadata(), // 경로 탐색 (공개)
    AppRoutes.guidance: const RouteMetadata(), // 길안내 (공개)
    AppRoutes.webview: const RouteMetadata(),
    AppRoutes.roadInfo: const RouteMetadata(),
    AppRoutes.announcementList: const RouteMetadata(),
    AppRoutes.announcementDetail: const RouteMetadata(),
  };

  /// 한국어 주석: 라우트 접근 제어 체크
  /// null 반환: 통과 (접근 허용)
  /// Route 반환: 리다이렉트 필요 (로그인 화면 등)
  static Route<dynamic>? guard(
    RouteSettings settings,
    AuthProvider authProvider,
    LocalStorageService storageService,
  ) {
    // 한국어 주석: 라우트 메타데이터 조회 (없으면 기본값: 공개)
    final metadata = _routeMetadata[settings.name] ?? const RouteMetadata();

    // 1. 인증 필수 체크
    if (metadata.requiresAuth && !authProvider.isAuthenticated) {
      // 한국어 주석: 로그인 화면으로 리다이렉트 + 복귀 경로 저장
      return MaterialPageRoute(
        builder: (_) => const LoginScreen(),
        settings: RouteSettings(
          name: AppRoutes.login,
          arguments: {
            'returnRoute': settings.name, // 로그인 후 복귀할 경로
            'returnArguments': settings.arguments, // 원래 arguments 보존
          },
        ),
      );
    }

    // 2. 이메일 인증 필수 체크
    if (metadata.requiresEmailVerified &&
        authProvider.isAuthenticated &&
        !authProvider.isEmailVerified) {
      debugPrint('[RouteGuard] 이메일 인증 필요: ${settings.name}');
      return MaterialPageRoute(
        builder: (_) => const MainNavigationScreen(
          initialIndex: 2,
          guardMessage: _emailVerificationRequiredMessage,
        ),
        settings: const RouteSettings(name: AppRoutes.mainNavigation),
      );
    }

    // 한국어 주석: 모든 체크 통과 → 접근 허용
    return null;
  }

  /// 한국어 주석: 특정 라우트가 로그인 필수인지 확인
  static bool requiresAuth(String routeName) {
    final metadata = _routeMetadata[routeName];
    return metadata?.requiresAuth ?? false;
  }

  /// 한국어 주석: 특정 라우트가 이메일 인증 필수인지 확인
  static bool requiresEmailVerified(String routeName) {
    final metadata = _routeMetadata[routeName];
    return metadata?.requiresEmailVerified ?? false;
  }
}
