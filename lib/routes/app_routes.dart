/// 애플리케이션 라우트 경로 정의
class AppRoutes {
  // 생성자를 private으로 설정하여 인스턴스화 방지
  AppRoutes._();

  // 라우트 경로 상수
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String mainNavigation = '/main-navigation';
  static const String profile = '/profile';
  static const String profileEdit = '/profile-edit';
  static const String changePassword = '/change-password';
  static const String changeEmail = '/change-email';
  static const String deleteAccount = '/delete-account';
  static const String appSettings = '/app-settings';
  static const String notificationSettings = '/notification-settings';
  static const String findId = '/find-id';
  static const String findPassword = '/find-password';
  static const String vehicleRegistration = '/vehicle-registration';
  static const String vehicleManagement = '/vehicle-management'; // 차량 관리 화면
  static const String navigation = '/navigation'; // 경로 탐색 화면
  static const String guidance = '/guidance'; // 길안내 화면
  static const String safeHome = '/safe-home'; // 안전귀가 화면
  static const String safeHomeSettings = '/safe-home-settings'; // 안전귀가 설정 화면
  static const String webview = '/webview'; // 웹뷰 화면
  static const String roadInfo = '/road-info'; // 도로정보 화면
  static const String announcementList = '/announcement-list'; // 공지사항 목록 화면
  static const String announcementDetail = '/announcement-detail'; // 공지사항 상세 화면
  static const String inquiryList = '/inquiry-list'; // 문의 목록 화면
  static const String inquiryCreate = '/inquiry-create'; // 문의 작성 화면
  static const String inquiryDetail = '/inquiry-detail'; // 문의 상세 화면
  static const String roadSurface = '/road-surface'; // 노면정보 화면
}
