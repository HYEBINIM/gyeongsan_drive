import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:remixicon/remixicon.dart';

/// 애플리케이션 전역 상수 정의
class AppConstants {
  // 생성자를 private으로 설정하여 인스턴스화 방지
  AppConstants._();

  // 스플래시 화면 관련 상수
  static const int splashDurationSeconds = 4;

  // Assets 경로
  static const String logoGifPath = 'assets/logos/logo.gif';
  static const String msitLogoPath = 'assets/logos/msit.png';
  static const String niaLogoPath = 'assets/logos/NIA.png';

  // 로고 크기
  static const double topLogoSize = 150.0;

  // 여백
  static const double topLogoPadding = 20.0;

  // 폰트 패밀리
  static const String fontFamilyBig = 'Pretendard';
  static const String fontFamilySmall = 'Pretendard';

  // 로그인 화면 관련 상수
  static const Color emailButtonColor = Color(0xFF007AFF);
  static const Color googleButtonColor = Colors.white;
  static const Color googleButtonBorderColor = Color(0xFFE0E0E0);
  static const Color googleButtonTextColor = Color(0xFF000000);
  static const Color emailInputLabelColor = Color(0xFF535353);
  static const Color passwordInputLabelColor = Color(0xFF535353);

  // 로그인 텍스트
  static const String loginTitle = '가장 편한 방법으로\n시작해 보세요!';
  static const String loginSubtitle = '1분 이내 회원가입 가능해요';
  static const String emailLoginButton = '이메일 주소로 계속하기';
  static const String googleLoginButton = 'Google로 계속하기';
  static const String dividerText = '또는';
  static const String emailInputLabel = '아이디(이메일)';
  static const String passwordInputLabel = '비밀번호';
  static const String loginButtonText = '로그인';
  static const String findIdText = '아이디 찾기';
  static const String findPasswordText = '비밀번호 찾기';
  static const String signupText = '회원가입';
  static const String rememberMeText = '자동 로그인';

  // 회원가입 화면 관련 상수
  static const String signupTitle = '이메일로 가입하기';

  // 회원가입 단계별 제목
  static const String nameInputTitle = '이름을 적어 주세요';
  static const String emailInputTitle = '이메일을 적어 주세요';
  static const String passwordSetTitle = '비밀번호를 설정해주세요';
  static const String verificationSentTitle = '이메일을 확인해주세요';

  // 이름 입력 관련
  static const String nameLabel = '이름';
  static const String nameHint = '';
  static const String nameNextButton = '다음';

  // 이메일 입력 관련
  static const String emailLabel = '이메일';
  static const String emailHint = '';
  static const String verifyButton = '인증';
  static const String verificationSentMessage = '로 인증 메일을 보냈습니다';
  static const String verificationInstruction = '이메일을 확인하고 인증 링크를 클릭해주세요';
  static const String resendEmailButton = '인증 메일 재전송';

  // 비밀번호 입력 관련
  static const String passwordLabel = '비밀번호';
  static const String passwordHint = '';
  static const String passwordConfirmLabel = '비밀번호 확인';
  static const String passwordConfirmHint = '비밀번호를 다시 입력하세요';
  static const String completeSignupButton = '회원가입 완료';

  // 유효성 검증 메시지
  static const String emptyName = '이름을 입력해주세요';
  static const String invalidName = '이름은 2자 이상이어야 합니다';
  static const String invalidEmail = '올바른 이메일 형식이 아닙니다';
  static const String emptyEmail = '이메일을 입력해주세요';
  static const String emptyPassword = '비밀번호를 입력해주세요';
  static const String shortPassword = '비밀번호는 최소 6자 이상이어야 합니다';
  static const String passwordMismatch = '비밀번호가 일치하지 않습니다';
  static const String emailNotVerified = '이메일 인증이 완료되지 않았습니다';
  static const String checkingVerification = '이메일 인증 확인 중...';
  static const String verificationComplete = '이메일 인증이 완료되었습니다!';

  // 아이디 찾기 화면 관련 상수
  static const String findIdTitle = '아이디 찾기';
  static const String findIdInstruction = '가입 시 입력한 이름과 이메일을 입력해주세요';
  static const String findIdNameLabel = '이름';
  static const String findIdNameHint = '이름을 입력하세요';
  static const String findIdEmailLabel = '이메일';
  static const String findIdEmailHint = '이메일을 입력하세요';
  static const String findIdSubmitButton = '아이디 찾기';
  static const String findIdSuccessTitle = '인증 이메일 발송 완료';
  static const String findIdSuccessMessage =
      '입력하신 이메일로 인증 링크가 발송되었습니다.\n이메일에서 링크를 클릭하면 로그인 화면으로 이동합니다.';
  static const String findIdNotFoundError = '해당 정보로 가입된 계정을 찾을 수 없습니다.';
  static const String findIdConfirmButton = '확인';

  // 비밀번호 찾기 화면 관련 상수
  static const String findPasswordTitle = '비밀번호 찾기';
  static const String findPasswordInstruction =
      '가입 시 입력한 이메일을 입력해주세요.\n비밀번호 재설정 링크를 보내드립니다.';
  static const String findPasswordEmailLabel = '이메일';
  static const String findPasswordEmailHint = '이메일을 입력하세요';
  static const String findPasswordSubmitButton = '비밀번호 재설정 이메일 발송';
  static const String findPasswordSuccessTitle = '이메일 발송 완료';
  static const String findPasswordSuccessMessage =
      '비밀번호 재설정 이메일이 발송되었습니다.\n이메일에서 링크를 클릭하여 비밀번호를 재설정하세요.';
  static const String findPasswordConfirmButton = '확인';

  // 약관 동의 관련 상수
  static const String termsAgreeAll = '전체 동의';
  static const String termsAge14 = '만 14세 이상입니다';
  static const String termsService = '이용약관 동의';
  static const String termsPrivacy = '개인정보 처리방침 동의';
  static const String termsRequired = '(필수)';
  static const String termsNotAgreedError = '필수 약관에 모두 동의해주세요';
  static const String termsInstruction = '서비스 이용을 위해 아래 약관에 동의해주세요';

  // 약관 동의 다이얼로그 관련 상수
  static const String termsDialogTitle = '서비스 이용 약관 동의';
  static const String termsDialogMessage = '서비스 이용을 위해 아래 필수 약관에 동의해주세요';
  static const String termsDialogAgreeButton = '동의하고 시작하기';
  static const String termsDialogCancelButton = '취소';
  static const String termsDialogCancelWarning =
      '약관 동의를 거부하면 서비스를 이용할 수 없습니다.\n로그인이 취소됩니다.';

  // 온보딩 화면 관련 상수
  // 통합 온보딩 페이지 (단일 리스트 형태)
  static const String onboardingTitle = '앱 사용을 위해\n접근 권한을 허용해주세요';
  static const String onboardingSubtitle = '선택 권한';
  static const String onboardingDescription =
      '선택 권한의 경우 허용하지 않아도 서비스를 사용할 수 있으나 일부 서비스 이용이 제한될 수 있습니다.';
  static const String onboardingConfirmButton = '확인';

  // 권한별 간략 제목
  static const String locationPermissionShortTitle = '위치';
  static const String notificationPermissionShortTitle = '알림';
  static const String microphonePermissionShortTitle = '마이크';
  static const String contactPermissionShortTitle = '연락처';

  // 권한별 간략 설명
  static const String locationPermissionShortDesc = '지도 및 주변 정보 제공';
  static const String notificationPermissionShortDesc = '알림 메시지 발송';
  static const String microphonePermissionShortDesc = '음성 기능 사용';
  static const String contactPermissionShortDesc = '연락처 기반 서비스 제공';

  // 로컬 저장소 키
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String autoLoginKey = 'auto_login_enabled';
  static const String recentSearchesKey = 'recent_searches';
  static const String themeModeKey = 'theme_mode'; // system, light, dark
  static const String notificationSettingsKey = 'notification_settings';
  static const String userProfileCacheKey =
      'user_profile_initialized_uids'; // 사용자 프로필 초기화 여부 캐시
  static const String drivingScoreCacheKeyPrefix =
      'driving_score_cache_'; // 차량별 운전 점수 캐시(일 단위)
  static const String drivingHabitsCacheKeyPrefix =
      'driving_habits_cache_'; // 차량별 운전 습관 캐시(일 단위)

  // 위치 권한 페이지
  static const String locationPermissionTitle = '위치 정보 권한';
  static const String locationPermissionDescription =
      '주변 정보를 제공하기 위해\n위치 권한이 필요합니다.';

  // 알림 권한 페이지
  static const String notificationPermissionTitle = '알림 권한';
  static const String notificationPermissionDescription =
      '중요한 소식을 전달하기 위해\n알림 권한이 필요합니다.';

  // 마이크 권한 페이지
  static const String microphonePermissionTitle = '마이크 권한';
  static const String microphonePermissionDescription =
      '음성 기능을 사용하기 위해\n마이크 권한이 필요합니다.';

  // 공통 버튼
  static const String nextButton = '다음';
  static const String startButton = '시작하기';

  // 권한 거부 다이얼로그
  static const String permissionDeniedTitle = '권한이 필요합니다';
  static const String permissionDeniedMessage =
      '이 권한은 앱 사용에 필수입니다.\n설정에서 권한을 허용해주세요.';
  static const String goToSettingsButton = '설정으로 이동';
  static const String exitAppButton = '앱 종료';

  // 지역정보 카테고리
  static final List<Map<String, dynamic>> placeCategories = [
    {'id': 'hospital', 'name': '병원', 'icon': Icons.local_hospital},
    {'id': 'pharmacy', 'name': '약국', 'icon': Remix.capsule_fill},
    {'id': 'parking', 'name': '주차장', 'icon': Icons.local_parking},
    {'id': 'restroom', 'name': '화장실', 'icon': Icons.wc},
    {'id': 'restaurant', 'name': '음식점', 'icon': Icons.restaurant},
  ];

  // 음성 명령 API 관련 상수 (환경 변수에서 로드)
  /// Wisenut RAG API 엔드포인트
  static String get voiceCommandApiUrl =>
      dotenv.env['VOICE_COMMAND_API_URL'] ??
      'https://labs.wisenut.kr/clusters/local/namespaces/rag/services/mcp-client/query';

  /// API 인증 토큰 (x-token 헤더)
  static String get voiceCommandApiToken =>
      dotenv.env['VOICE_COMMAND_API_TOKEN'] ?? 'wisenut';

  /// API 인증 토큰 (wisenut-authorization 헤더)
  static String get voiceCommandApiAuth =>
      dotenv.env['VOICE_COMMAND_API_AUTH'] ?? 'miracle-wisenut';

  /// API max_tool_calls 파라미터
  static int get voiceCommandMaxToolCalls {
    final raw = dotenv.env['VOICE_COMMAND_MAX_TOOL_CALLS'];
    if (raw == null || raw.trim().isEmpty) {
      return 10;
    }

    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed <= 0) {
      return 10;
    }

    return parsed;
  }

  /// API 요청 타임아웃 (밀리초)
  static const int voiceCommandTimeoutMs = 30000; // 30초

  /// 음성 인식 언어 코드
  static const String voiceRecognitionLocale = 'ko_KR'; // 한국어

  /// 음성 인식 신뢰도 임계값 (0.0 ~ 1.0)
  /// 이 값보다 낮은 신뢰도의 음성 인식 결과는 거부됨
  static const double voiceConfidenceThreshold = 0.7; // 70%

  /// 음성 인식 하드 타임아웃 (밀리초)
  static const int voiceListeningTimeoutMs = 12000; // 12초

  /// 노이즈 필터링 필러 단어 패턴
  /// 한국어 필러 단어 (음, 어, 저, 그, 아, 으음 등)
  static final RegExp fillerWordsPattern = RegExp(
    r'\b(음+|어+|저+|그+|아+|으음+|어어+|음음+)\b',
    caseSensitive: false,
  );

  /// 음성 인식 최소 텍스트 길이
  /// 이보다 짧은 텍스트는 노이즈로 간주
  static const int minRecognizedTextLength = 2;

  /// 음성 인식 최대 재시도 횟수 (신뢰도 낮을 때)
  static const int maxLowConfidenceRetries = 2;

  /// 호출어 기반 음성 질의 관련 상수
  static const String voiceWakeWord = '이스트';
  static const int passiveWakeListeningTimeoutMs = 8000;
  static const int passiveWakePauseSeconds = 2;
  static const int armedQueryListeningTimeoutMs = 10000;
  static const int armedQueryPauseSeconds = 6;
  static const int passiveWakeIdleRestartDelayMs = 1000;
  static const int passiveWakeClientErrorInitialDelayMs = 1500;
  static const int passiveWakeClientErrorMaxDelayMs = 10000;
  static const int passiveWakeErrorLogCooldownMs = 15000;
  static const int speechTransitionCooldownMs = 500;
  static const String passiveWakeNoQuestionMessage = '질문을 듣지 못했습니다.';
  static const String passiveWakeUnsupportedMessage =
      '지원하지 않는 차량 질문입니다. 배터리 잔량, 현재 속도, 총 주행거리, 운전 점수 중 하나를 말씀해 주세요.';
  static const String passiveWakeVehicleUnavailableMessage =
      '차량 정보를 확인할 수 없습니다.';
  static const String passiveWakeFetchFailedMessage = '지금은 차량 정보를 불러올 수 없습니다.';

  // 지도 관련 상수
  /// 기본 지도 줌 레벨 (안전귀가, 네비게이션, 지역정보)
  static const double mapDefaultZoom = 15.0;

  /// 길안내 화면 줌 레벨 (더 상세한 뷰)
  static const double mapGuidanceZoom = 16.0;

  /// 최소 줌 레벨
  static const double mapMinZoom = 5.0;

  /// 최대 줌 레벨
  static const double mapMaxZoom = 21.0;

  // GPS 버튼 클릭 시 줌 레벨
  /// 안전귀가 화면 GPS 버튼 줌 레벨 (경로 확인하면서 내 위치 명확히)
  static const double mapGpsZoomSafeHome = 17.0;

  /// 네비게이션 화면 GPS 버튼 줌 레벨 (경로 선택 전 위치 확인)
  static const double mapGpsZoomNavigation = 17.0;

  /// 길안내 화면 GPS 버튼 줌 레벨 (턴바이턴 네비 중 도로 상세 정보)
  static const double mapGpsZoomGuidance = 18.0;

  /// 지역정보 화면 GPS 버튼 줌 레벨 (주변 시설 탐색에 적합한 거리)
  static const double mapGpsZoomRegionInfo = 16.5;
}
