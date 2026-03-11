import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 한국어 주석: Firestore 프리워밍용
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'firebase_options.dart'; // flutterfire configure로 생성됨
import 'view_models/splash/splash_viewmodel.dart';
import 'view_models/login/login_viewmodel.dart';
import 'view_models/signup/signup_viewmodel.dart';
import 'view_models/home/home_viewmodel.dart';
import 'view_models/home/voice_command_viewmodel.dart';
import 'view_models/find_id/find_id_viewmodel.dart';
import 'view_models/find_password/find_password_viewmodel.dart';
import 'view_models/vehicle_registration/vehicle_registration_viewmodel.dart';
import 'view_models/vehicle_info/vehicle_info_viewmodel.dart';
import 'view_models/region_info/region_info_viewmodel.dart';
import 'view_models/navigation/navigation_viewmodel.dart';
import 'view_models/safe_home/safe_home_settings_viewmodel.dart';
import 'view_models/safe_home/safe_home_monitor_viewmodel.dart';
import 'view_models/vehicle_management/vehicle_management_viewmodel.dart';
import 'view_models/theme/theme_viewmodel.dart';
import 'view_models/notification/notification_settings_viewmodel.dart';
import 'view_models/profile/profile_viewmodel.dart';
import 'view_models/profile/profile_edit_viewmodel.dart';
import 'view_models/profile/change_password_viewmodel.dart';
import 'view_models/profile/change_email_viewmodel.dart';
import 'view_models/road_surface/road_surface_viewmodel.dart';
import 'views/splash/splash_screen.dart';
import 'views/onboarding/onboarding_screen.dart';
import 'views/login/login_screen.dart';
import 'views/signup/signup_screen.dart';
import 'views/home/home_screen.dart';
import 'views/main/main_navigation_screen.dart';
import 'views/profile/profile_screen.dart';
import 'views/profile/profile_edit_screen.dart';
import 'views/profile/change_password_screen.dart';
import 'views/profile/change_email_screen.dart';
import 'views/profile/delete_account_screen.dart';
import 'views/settings/app_settings_screen.dart';
import 'views/settings/notification_settings_screen.dart';
import 'views/find_id/find_id_screen.dart';
import 'views/find_password/find_password_screen.dart';
import 'views/vehicle_registration/vehicle_registration_screen.dart';
import 'views/navigation/navigation_screen.dart';
import 'views/navigation/guidance_screen.dart';
import 'views/safe_home/safe_home_screen.dart';
import 'views/safe_home/safe_home_settings_screen.dart';
import 'views/webview/webview_screen.dart';
import 'views/announcement/announcement_list_screen.dart';
import 'views/announcement/announcement_detail_screen.dart';
import 'views/inquiry/inquiry_list_screen.dart';
import 'views/inquiry/inquiry_create_screen.dart';
import 'views/inquiry/inquiry_detail_screen.dart';
import 'views/road_surface/road_surface_screen.dart';
import 'views/road_info/road_info_screen.dart';
import 'views/vehicle_management/vehicle_management_screen.dart';
import 'models/announcement/announcement.dart';
import 'services/auth/firebase_auth_service.dart';
import 'services/safe_home/firestore_safe_home_service.dart'; // Firestore 안전귀가
import 'services/destination_search/destination_search_service.dart';
import 'services/functions/cloud_functions_service.dart';
import 'services/mcp/mcp_vehicle_client.dart';
import 'services/vehicle/vehicle_api_service.dart';
import 'services/vehicle_info/battery_status_service.dart';
import 'services/vehicle_info/driving_score_service.dart';
import 'services/vehicle/firestore_vehicle_service.dart'; // Firestore 차량
import 'services/location/location_service.dart';
import 'services/geocoding/geocoding_service.dart';
import 'services/region_info/firestore_region_info_service.dart'; // Firestore 지역정보
import 'services/navigation/navigation_service.dart';
import 'services/navigation/valhalla_api_service.dart';
import 'services/navigation/guidance_service.dart';
import 'services/storage/local_storage_service.dart';
import 'routes/app_routes.dart';
import 'routes/route_guard.dart'; // 한국어 주석: Route Guard 미들웨어
import 'theme/app_theme.dart';
import 'services/notification/notification_service.dart';
import 'services/messaging/fcm_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/auth_provider.dart'; // 한국어 주석: 전역 인증 상태 Provider
import 'services/voice/navigation_context_resolver.dart';
import 'services/voice/rule_vehicle_voice_service.dart';
import 'widgets/road_surface/road_condition_detail_sheet.dart'; // 한국어 주석: 도로 상태 이미지 캐시 초기화
import 'widgets/voice/voice_wake_listener_host.dart';

/// FCM Background 메시지 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase 초기화 (Background에서도 필요)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 백그라운드 메시지 처리 로그
  // ignore: avoid_print
  print('Background message received: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 한국어 주석: Firestore 콜드스타트 비용을 백그라운드에서 선행 처리(프리워밍)
  Future<void> prewarmFirestore() async {
    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'eastapp-dev',
      );
      // 존재 여부와 무관한 경량 쿼리 (권한 문제 발생 시 무시)
      await firestore
          .collection('__warmup__')
          .limit(1)
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      // 한국어 주석: 권한/네트워크 오류는 무시(사용자 흐름 차단 금지)
    }
  }

  // 한국어 주석: 비동기 실행(앱 시작을 지연시키지 않음)
  // ignore: discarded_futures
  Future.microtask(prewarmFirestore);

  // 한국어 주석: 도로 상태 이미지 URL 영구 캐시 초기화 (백그라운드)
  // ignore: discarded_futures
  Future.microtask(RoadConditionDetailSheet.initializePersistentCache);

  // 환경 변수 로드 (.env 파일)
  // 한국어 주석: .env를 필수로 로드
  await dotenv.load(fileName: '.env');

  // 네이버 맵 SDK 초기화
  // ignore: deprecated_member_use
  await NaverMapSdk.instance.initialize(
    // clientId: 't14lkvxmuw',
    onAuthFailed: (e) {
      // ignore: avoid_print
      print('네이버 맵 인증 실패: $e');
    },
  );

  // 상태 바 아이콘 스타일 설정 (로우 라이트 테마용 - 밝은 아이콘)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light, // 어두운 배경에 밝은 아이콘
      statusBarBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());

  // 한국어 주석: 앱 시작 후 알림 서비스 초기화 (시스템 채널/권한)
  // - 별도 await 없이 백그라운드 초기화
  // - 최초 이벤트에서 자동 초기화되지만, 권한/채널 선행 준비를 위해 호출
  //   (DRY/KISS: 전역 싱글턴 사용)
  NotificationService.instance.initialize();

  // FCM Background 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // FCM 서비스 초기화 (토큰 가져오기 및 메시지 리스너 등록)
  FCMService.instance.initialize();
}

/// Global Navigator Key (딥링크 처리용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 애플리케이션의 루트 위젯
/// MVVM 패턴을 적용하여 Provider로 상태 관리
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Firebase 서비스 인스턴스 생성
    final firebaseAuthService = FirebaseAuthService();
    final cloudFunctionsService = CloudFunctionsService();
    final mcpVehicleClient = McpVehicleClient();

    // 차량 관련 서비스 인스턴스 생성
    final vehicleApiService = VehicleApiService(mcpClient: mcpVehicleClient);
    final drivingScoreService = DrivingScoreService(
      mcpClient: mcpVehicleClient,
    );
    final batteryStatusService = BatteryStatusService(
      mcpClient: mcpVehicleClient,
    );
    final vehicleFirebaseService =
        FirestoreVehicleService(); // RTDB → Firestore

    // 위치 관련 서비스 인스턴스 생성
    final locationService = LocationService();
    final geocodingService = GeocodingService();
    final regionInfoService = FirestoreRegionInfoService(); // RTDB → Firestore

    // 길안내 서비스 인스턴스 생성
    final valhallaApiService = ValhallaApiService();
    final navigationService = NavigationService(
      valhallaApi: valhallaApiService,
    );
    final guidanceService = GuidanceService();
    final navigationContextResolver = NavigationContextResolver(
      geocodingService: geocodingService,
    );

    // 안전귀가 서비스 인스턴스 생성
    final safeHomeDatabaseService =
        FirestoreSafeHomeService(); // RTDB → Firestore
    final destinationSearchService = DestinationSearchService();

    return MultiProvider(
      providers: [
        // === 전역 서비스 (싱글턴) ===
        // 한국어 주석: FirebaseAuthService를 Provider로 등록 (DI)
        Provider<FirebaseAuthService>(
          create: (_) => firebaseAuthService,
          dispose: (_, service) {}, // 한국어 주석: 외부에서 생성한 인스턴스이므로 dispose 불필요
        ),
        // 한국어 주석: LocalStorageService를 Provider로 등록
        Provider<LocalStorageService>(create: (_) => LocalStorageService()),
        // 한국어 주석: 지오코딩/네비게이션 컨텍스트 Resolver 공유
        Provider<GeocodingService>.value(value: geocodingService),
        Provider<NavigationContextResolver>.value(
          value: navigationContextResolver,
        ),

        // === 전역 인증 상태 (SSOT) ===
        // 한국어 주석: AuthProvider - 앱 전체의 인증 상태를 중앙 관리
        ChangeNotifierProvider<AuthProvider>(
          create: (context) =>
              AuthProvider(context.read<FirebaseAuthService>()),
        ),

        // 테마 ViewModel 등록
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
        // 알림 설정 ViewModel 등록
        ChangeNotifierProvider(
          create: (_) => NotificationSettingsViewModel()..initialize(),
        ),
        // 스플래시 화면 ViewModel 등록
        ChangeNotifierProvider(create: (_) => SplashViewModel()),
        // 로그인 화면 ViewModel 등록
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        // 회원가입 화면 ViewModel 등록
        ChangeNotifierProvider(create: (_) => SignupViewModel()),
        // 프로필 관련 ViewModel 등록
        ChangeNotifierProvider(
          create: (_) => ProfileViewModel(authService: firebaseAuthService),
        ),
        ChangeNotifierProvider(create: (_) => ProfileEditViewModel()),
        ChangeNotifierProvider(create: (_) => ChangePasswordViewModel()),
        ChangeNotifierProvider(create: (_) => ChangeEmailViewModel()),
        // 음성 명령 ViewModel 등록 (홈 VM보다 먼저 생성)
        ChangeNotifierProvider(
          create: (_) => VoiceCommandViewModel(
            authService: firebaseAuthService,
            vehicleService: vehicleFirebaseService,
            ruleVehicleVoiceService: RuleVehicleVoiceService(
              vehicleApiService: vehicleApiService,
              drivingScoreService: drivingScoreService,
            ),
            navigationResolver: navigationContextResolver,
          ),
        ),
        // 홈 화면 ViewModel 등록 (음성 VM 주입)
        ChangeNotifierProxyProvider<VoiceCommandViewModel, HomeViewModel>(
          create: (_) => HomeViewModel(
            apiService: vehicleApiService,
            firebaseService: vehicleFirebaseService,
            authService: firebaseAuthService,
          ),
          update: (_, voiceViewModel, homeViewModel) =>
              homeViewModel!..attachVoiceCommandViewModel(voiceViewModel),
        ),
        // 아이디 찾기 화면 ViewModel 등록
        ChangeNotifierProvider(
          create: (_) =>
              FindIdViewModel(functionsService: cloudFunctionsService),
        ),
        // 비밀번호 찾기 화면 ViewModel 등록
        ChangeNotifierProvider(
          create: (_) =>
              FindPasswordViewModel(authService: firebaseAuthService),
        ),
        // 차량 등록 화면 ViewModel 등록
        ChangeNotifierProvider(
          create: (_) => VehicleRegistrationViewModel(
            vehicleFirebaseService: vehicleFirebaseService,
            authService: firebaseAuthService,
          ),
        ),
        // 차량 정보 화면 ViewModel 등록
        ChangeNotifierProvider(
          create: (_) => VehicleInfoViewModel(
            scoreService: drivingScoreService,
            batteryService: batteryStatusService,
            firebaseService: vehicleFirebaseService,
            authService: firebaseAuthService,
          ),
        ),
        // 지역 정보 화면 ViewModel 등록
        ChangeNotifierProvider(
          create: (_) => RegionInfoViewModel(
            locationService: locationService,
            regionInfoService: regionInfoService,
            geocodingService: geocodingService,
          ),
        ),
        // 길안내 화면 ViewModel 등록
        ChangeNotifierProvider(
          create: (_) => NavigationViewModel(
            navigationService: navigationService,
            locationService: locationService,
            geocodingService: geocodingService,
            guidanceService: guidanceService,
          ),
        ),
        // 안전귀가 설정 화면 ViewModel 등록
        ChangeNotifierProvider(
          create: (_) => SafeHomeSettingsViewModel(
            databaseService: safeHomeDatabaseService,
            authService: firebaseAuthService,
            searchService: destinationSearchService,
          ),
        ),
        // 안전귀가 모니터링 ViewModel (앱 전역 제공: 백그라운드 유지)
        ChangeNotifierProvider(create: (_) => SafeHomeMonitorViewModel()),
        // 노면 정보 화면 ViewModel 등록
        ChangeNotifierProvider(create: (_) => RoadSurfaceViewModel()),
        // 차량 관리 화면 ViewModel 등록 (홈/차량정보/음성명령 VM 연동)
        ChangeNotifierProxyProvider3<
          HomeViewModel,
          VehicleInfoViewModel,
          VoiceCommandViewModel,
          VehicleManagementViewModel
        >(
          create: (_) => VehicleManagementViewModel(
            vehicleService: vehicleFirebaseService,
            authService: firebaseAuthService,
          ),
          update:
              (
                _,
                homeViewModel,
                vehicleInfoViewModel,
                voiceCommandViewModel,
                managementViewModel,
              ) => managementViewModel!.attachDependentViewModels(
                homeViewModel: homeViewModel,
                vehicleInfoViewModel: vehicleInfoViewModel,
                voiceCommandViewModel: voiceCommandViewModel,
              ),
        ),
      ],
      child: Consumer2<ThemeViewModel, AuthProvider>(
        builder: (context, themeViewModel, authProvider, _) {
          // 한국어 주석: 앱 시작 시 테마 초기화
          if (themeViewModel.themeMode == 'system') {
            // 아직 초기화되지 않았으면 초기화
            themeViewModel.initialize();
          }

          return MaterialApp(
            navigatorKey: navigatorKey, // 딥링크 처리를 위한 Global Key
            title: 'Flutter WebView',
            // 동적 테마 적용
            theme: AppTheme.lightTheme, // 라이트 모드용
            darkTheme: AppTheme.lowLightTheme, // 다크 모드용
            themeMode: themeViewModel.materialThemeMode, // 사용자 선택에 따라 전환
            // 초기 화면을 스플래시 화면으로 설정
            initialRoute: AppRoutes.splash,
            // 라우트 정의
            routes: {
              AppRoutes.splash: (context) => const SplashScreen(),
              AppRoutes.onboarding: (context) => const OnboardingScreen(),
              AppRoutes.login: (context) => const LoginScreen(),
              AppRoutes.signup: (context) => const SignupScreen(),
              // mainNavigation: arguments로 초기 탭 인덱스(int)를 전달받아 설정
              AppRoutes.mainNavigation: (context) {
                final arguments = ModalRoute.of(context)?.settings.arguments;
                var initialIndex = 0;
                String? guardMessage;

                if (arguments is int) {
                  initialIndex = arguments;
                } else if (arguments is Map<String, dynamic>) {
                  initialIndex = arguments['initialIndex'] as int? ?? 0;
                  guardMessage = arguments['guardMessage'] as String?;
                }

                return MainNavigationScreen(
                  initialIndex: initialIndex,
                  guardMessage: guardMessage,
                );
              },
              AppRoutes.profile: (context) => const ProfileScreen(),
              AppRoutes.profileEdit: (context) => const ProfileEditScreen(),
              AppRoutes.changePassword: (context) =>
                  const ChangePasswordScreen(),
              AppRoutes.changeEmail: (context) => const ChangeEmailScreen(),
              AppRoutes.deleteAccount: (context) => const DeleteAccountScreen(),
              AppRoutes.appSettings: (context) => const AppSettingsScreen(),
              AppRoutes.notificationSettings: (context) =>
                  const NotificationSettingsScreen(),
              AppRoutes.findId: (context) => const FindIdScreen(),
              AppRoutes.findPassword: (context) => const FindPasswordScreen(),
              // 차량 관리 화면
              AppRoutes.vehicleManagement: (context) =>
                  const VehicleManagementScreen(),
              // 안전귀가 설정 화면
              AppRoutes.safeHomeSettings: (context) =>
                  const SafeHomeSettingsScreen(),
              // 공지사항 목록 화면
              AppRoutes.announcementList: (context) =>
                  const AnnouncementListScreen(),
              // 문의 목록 화면
              AppRoutes.inquiryList: (context) => const InquiryListScreen(),
              // 문의 작성 화면
              AppRoutes.inquiryCreate: (context) => const InquiryCreateScreen(),
              // 노면정보 화면
              AppRoutes.roadSurface: (context) => const RoadSurfaceScreen(),
              // 도로정보 화면 (네이버 지도 기반)
              AppRoutes.roadInfo: (context) => const RoadInfoScreen(),
            },
            // onGenerateRoute로 arguments를 전달받는 라우트 처리
            onGenerateRoute: (settings) {
              // === Route Guard: 인증 필요 라우트 접근 제어 ===
              // 한국어 주석: RouteGuard가 null 반환 시 접근 허용, Route 반환 시 리다이렉트
              final guardedRoute = RouteGuard.guard(
                settings,
                authProvider,
                context.read<LocalStorageService>(),
              );
              if (guardedRoute != null) {
                return guardedRoute; // 인증 실패 → 로그인 화면으로 리다이렉트
              }

              // === 동적 라우트 처리 (arguments 필요한 화면들) ===
              if (settings.name == AppRoutes.home) {
                return MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                );
              }
              if (settings.name == AppRoutes.vehicleRegistration) {
                return MaterialPageRoute(
                  builder: (context) => const VehicleRegistrationScreen(),
                );
              }
              if (settings.name == AppRoutes.safeHome) {
                return MaterialPageRoute(
                  builder: (context) => const SafeHomeScreenWithProvider(),
                );
              }
              if (settings.name == AppRoutes.navigation) {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => NavigationScreen(
                    start: args?['start'],
                    destination: args?['destination'],
                  ),
                );
              }
              if (settings.name == AppRoutes.guidance) {
                return MaterialPageRoute(
                  builder: (context) => const GuidanceScreen(),
                );
              }
              if (settings.name == AppRoutes.webview) {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => WebViewScreen(
                    url: args?['url'] ?? 'about:blank',
                    title: args?['title'],
                  ),
                );
              }
              if (settings.name == AppRoutes.announcementDetail) {
                final args = settings.arguments;
                if (args is Announcement) {
                  // 한국어 주석: 목록 화면 등에서 바로 공지 객체를 전달한 경우
                  return MaterialPageRoute(
                    builder: (context) =>
                        AnnouncementDetailScreen(announcement: args),
                  );
                }
                if (args is String) {
                  // 한국어 주석: 푸시 알림 딥링크로 공지 ID만 전달된 경우
                  return MaterialPageRoute(
                    builder: (context) =>
                        AnnouncementDetailScreen(announcementId: args),
                  );
                }
                // 한국어 주석: 잘못된 arguments가 전달된 경우 기본 화면으로 리다이렉트
                return MaterialPageRoute(
                  builder: (context) => const AnnouncementListScreen(),
                );
              }
              if (settings.name == AppRoutes.inquiryDetail) {
                final inquiryId = settings.arguments as String;
                return MaterialPageRoute(
                  builder: (context) =>
                      InquiryDetailScreen(inquiryId: inquiryId),
                );
              }
              return null;
            },
            builder: (context, child) {
              if (child == null) {
                return const SizedBox.shrink();
              }
              return VoiceWakeListenerHost(child: child);
            },
          );
        },
      ),
    );
  }
}
