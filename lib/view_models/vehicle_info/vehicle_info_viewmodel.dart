import '../../models/driving_score_model.dart';
import '../../models/vehicle_info_model.dart';
import '../../models/battery_status_model.dart';
import '../../services/vehicle_info/driving_score_service.dart';
import '../../services/vehicle_info/battery_status_service.dart';
import '../../services/vehicle/firestore_vehicle_service.dart'; // RTDB → Firestore
import '../../services/auth/firebase_auth_service.dart';
import '../../services/storage/local_storage_service.dart';
import '../base/base_view_model.dart';
import '../base/auth_mixin.dart';
import '../../utils/app_logger.dart';

/// 차량 정보 ViewModel (MVVM 패턴)
class VehicleInfoViewModel extends BaseViewModel with AuthMixin {
  // 서비스 의존성
  final DrivingScoreService _scoreService;
  final BatteryStatusService _batteryService;
  final FirestoreVehicleService _firebaseService; // RTDB → Firestore
  final LocalStorageService _localStorageService;

  @override
  final FirebaseAuthService authService;

  // 상태
  VehicleInfo? _vehicleInfo; // 사용자의 차량 정보
  DrivingScoreData? _scoreData;
  int _selectedTabIndex = 0; // 0: 운전점수, 1: 배터리 상태
  bool _hasVehicle = false; // 차량 등록 여부
  DateTime? _selectedDate; // 선택된 날짜 (주간 점수 차트)
  Map<DateTime, DrivingHabits>? _dailyHabitsMap; // 날짜별 운전 습관 맵
  DateTime? _lastScoreUpdatedAt; // 운전 점수 데이터가 마지막으로 갱신된 시각 (일 단위 캐시)

  // 배터리 상태 관련 상태
  BatteryStatusData? _batteryData;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  BatteryAssessmentState _batteryState = BatteryAssessmentState.idle;
  String? _batteryErrorMessage;
  // 한국어 주석: 간단한 월별 캐시 (키: mtId|year-month)
  final Map<String, BatteryStatusData> _batteryCache = {};
  // 한국어 주석: 동일 파라미터 중복 호출을 합치기 위한 in-flight 요청 맵
  final Map<String, Future<BatteryStatusData>> _batteryInFlightRequests = {};
  int _batteryRequestToken = 0;
  String? _activeBatteryRequestKey;

  // Getters
  VehicleInfo? get vehicleInfo => _vehicleInfo;
  DrivingScoreData? get scoreData => _scoreData;
  int get selectedTabIndex => _selectedTabIndex;
  bool get hasVehicle => _hasVehicle;
  DateTime? get selectedDate => _selectedDate;

  // 배터리 상태 관련 Getters
  BatteryStatusData? get batteryData => _batteryData;
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;
  BatteryAssessmentState get batteryState => _batteryState;
  bool get isBatteryLoading =>
      _batteryState == BatteryAssessmentState.requesting ||
      _batteryState == BatteryAssessmentState.processing;
  bool get isBatteryProcessing =>
      _batteryState == BatteryAssessmentState.processing;
  String? get batteryErrorMessage => _batteryErrorMessage;
  // 한국어 주석: 캐시 조회(테스트/디버그용)
  Map<String, BatteryStatusData> get batteryCache => _batteryCache;

  /// 선택된 날짜의 운전 습관 데이터 반환
  DrivingHabits? get selectedDayHabits {
    if (_selectedDate == null) {
      return null;
    }

    final normalizedDate = _normalizeDate(_selectedDate!);
    final habits = _dailyHabitsMap?[normalizedDate];
    if (habits != null) {
      return habits;
    }

    final hasSelectedScore =
        _scoreData?.weeklyScores.any(
          (score) => _normalizeDate(score.date) == normalizedDate,
        ) ??
        false;

    if (hasSelectedScore) {
      return const DrivingHabits.empty();
    }

    return null;
  }

  /// 한국어 주석: 운전 점수 캐시가 오늘 날짜 기준으로 유효한지 확인
  bool _isTodayScoreCacheValid() {
    if (_scoreData == null ||
        _dailyHabitsMap == null ||
        _lastScoreUpdatedAt == null) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cachedDay = DateTime(
      _lastScoreUpdatedAt!.year,
      _lastScoreUpdatedAt!.month,
      _lastScoreUpdatedAt!.day,
    );

    return today == cachedDay;
  }

  /// 생성자
  VehicleInfoViewModel({
    DrivingScoreService? scoreService,
    BatteryStatusService? batteryService,
    required FirestoreVehicleService firebaseService,
    required this.authService,
    LocalStorageService? localStorageService,
  }) : _scoreService = scoreService ?? DrivingScoreService(),
       _batteryService = batteryService ?? BatteryStatusService(),
       _firebaseService = firebaseService,
       _localStorageService = localStorageService ?? LocalStorageService();

  /// 초기화 - 사용자 차량 확인 후 운전 점수 데이터 로드
  Future<void> initialize({bool force = false}) async {
    await withLoading(() async {
      // 1. 현재 로그인한 사용자 확인
      final userId = requiredUserId;

      // 2. 사용자의 활성화된 차량 조회
      final vehicleInfo = await _firebaseService.getUserActiveVehicle(
        userId,
        forceServer: force, // force가 true면 캐시 무시하고 서버에서 최신 데이터 가져오기
      );

      if (vehicleInfo == null) {
        // 등록된 차량 없음
        _hasVehicle = false;
        _vehicleInfo = null;
        _scoreData = null;
        _dailyHabitsMap = null;
        _selectedDate = null;
        _lastScoreUpdatedAt = null;
        _batteryData = null;
        _batteryErrorMessage = null;
        cancelBatteryPolling(notify: false);
        _setBatteryState(BatteryAssessmentState.idle, notify: false);
        throw '등록된 차량이 없습니다';
      } else {
        // 차량 있음
        _hasVehicle = true;
        _vehicleInfo = vehicleInfo;

        // 한국어 주석: 차량 정보 초기화 시 mtid 및 차량번호 디버그 출력
        AppLogger.debug(
          '📊 [차량정보] 차량 정보 로드: ${vehicleInfo.vehicleNumber} (MT_ID: ${vehicleInfo.mtId})',
        );

        // 운전 점수 데이터 로드
        await _loadScoreData(useCache: !force);
      }
    });
  }

  /// 운전 점수 데이터 로드 (내부 메서드)
  /// - 기본적으로 하루(00시 기준) 동안 메모리 캐시를 사용하여 API 호출을 최소화
  /// - [useCache]가 false이면 캐시를 무시하고 항상 네트워크에서 새로 조회
  Future<void> _loadScoreData({bool useCache = true}) async {
    if (_vehicleInfo == null) return;

    // 한국어 주석: 오늘 날짜 기준으로 캐시가 유효하면 네트워크 호출 없이 즉시 반환
    if (useCache && _isTodayScoreCacheValid()) {
      AppLogger.debug(
        '📊 [차량정보] 운전 점수 메모리 캐시 사용: '
        '${_vehicleInfo!.vehicleNumber} (MT_ID: ${_vehicleInfo!.mtId})',
      );
      return;
    }

    // 한국어 주석: 앱 재시작 후에도 하루 안에서는 로컬 저장소(SharedPreferences)에
    // 저장된 캐시가 있으면 우선 사용하여 빠르게 UI를 구성
    if (useCache) {
      final cachedScore = await _localStorageService.getTodayDrivingScoreCache(
        _vehicleInfo!.mtId,
      );
      final cachedHabits = await _localStorageService.getTodayDrivingHabitsCache(
        _vehicleInfo!.mtId,
      );
      if (cachedScore != null && cachedHabits != null) {
        AppLogger.debug(
          '📊 [차량정보] 운전 점수 로컬 캐시 사용: '
          '${_vehicleInfo!.vehicleNumber} (MT_ID: ${_vehicleInfo!.mtId})',
        );
        _scoreData = cachedScore;
        _dailyHabitsMap = cachedHabits;
        _lastScoreUpdatedAt = DateTime.now();
        _selectLatestScoreDate();
        return;
      }
    }

    // 한국어 주석: 운전 점수 데이터 요청 시 mtid 및 차량번호 디버그 출력
    AppLogger.debug(
      '📊 [차량정보] 운전 점수 데이터 요청: ${_vehicleInfo!.vehicleNumber} (MT_ID: ${_vehicleInfo!.mtId})',
    );

    final result = await _scoreService.fetchDrivingScoreQueryResult(
      mtId: _vehicleInfo!.mtId,
    );
    _scoreData = result.scoreData;
    _dailyHabitsMap = result.dailyHabitsMap;
    _lastScoreUpdatedAt = DateTime.now(); // 한국어 주석: 일 단위 캐시 시각 기록
    await _localStorageService.saveDrivingScoreCache(
      _vehicleInfo!.mtId,
      result.scoreData,
    ); // 한국어 주석: 앱 재시작 시 재사용할 수 있도록 로컬 캐시 저장
    await _localStorageService.saveDrivingHabitsCache(
      _vehicleInfo!.mtId,
      result.dailyHabitsMap,
    );
    _selectLatestScoreDate();
  }

  /// 날짜 선택 처리
  void selectDate(DateTime date) {
    _selectedDate = _normalizeDate(date);
    notifyListeners();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void _selectLatestScoreDate() {
    if (_scoreData != null && _scoreData!.weeklyScores.isNotEmpty) {
      _selectedDate = _normalizeDate(_scoreData!.weeklyScores.last.date);
      return;
    }

    _selectedDate = null;
  }

  /// 운전 점수 데이터 로드 (외부 호출용 - 호환성 유지)
  Future<void> loadScoreData() async {
    await withLoading(() async {
      await _loadScoreData(useCache: true);
    });
  }

  /// 탭 선택
  void selectTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  /// 날짜 범위 선택 후 데이터 로드 (실제 API 연동)
  Future<void> selectDateRange(DateTime startDate, DateTime endDate) async {
    if (_vehicleInfo == null) return;

    await withLoading(() async {
      final result = await _scoreService.fetchDrivingScoreQueryResult(
        mtId: _vehicleInfo!.mtId,
        startDate: startDate,
        endDate: endDate,
      );
      _scoreData = result.scoreData;
      _dailyHabitsMap = result.dailyHabitsMap;
      _lastScoreUpdatedAt = null;
      _selectLatestScoreDate();
    });
  }

  /// 데이터 새로고침
  Future<void> refreshData() async {
    if (_vehicleInfo == null) {
      // 차량 정보가 없으면 전체 초기화
      await initialize();
      return;
    }

    await withLoading(() async {
      // 한국어 주석: 새로고침은 항상 네트워크에서 최신 데이터를 가져오도록 캐시를 무시
      await _loadScoreData(useCache: false);
    });
  }

  /// 배터리 상태 데이터 로드 (내부 메서드)
  Future<void> _loadBatteryData({bool useCache = true}) async {
    if (_vehicleInfo == null) return;

    // 한국어 주석: 배터리 데이터 요청 시 mtid 및 차량번호 디버그 출력
    AppLogger.debug(
      '🔋 [차량정보] 배터리 데이터 요청: ${_vehicleInfo!.vehicleNumber} (MT_ID: ${_vehicleInfo!.mtId}), 년월 = $_selectedYear-$_selectedMonth',
    );

    await _loadBatteryDataFor(
      mtId: _vehicleInfo!.mtId,
      year: _selectedYear,
      month: _selectedMonth,
      useCache: useCache,
    );
  }

  /// 배터리 상태 데이터 로드 (외부 호출용)
  Future<void> loadBatteryData() async {
    await _loadBatteryData(useCache: true);
  }

  /// 년월 선택 후 배터리 데이터 로드
  Future<void> selectYearMonth(int year, int month) async {
    if (_vehicleInfo == null) return;

    // 한국어 주석: 년월 선택 시 mtid 및 차량번호 디버그 출력
    AppLogger.debug(
      '🔋 [차량정보] 년월 선택: ${_vehicleInfo!.vehicleNumber} (MT_ID: ${_vehicleInfo!.mtId}), 년월 = $year-$month',
    );

    _selectedYear = year;
    _selectedMonth = month;
    notifyListeners();

    await _loadBatteryDataFor(
      mtId: _vehicleInfo!.mtId,
      year: year,
      month: month,
      useCache: true,
    );
  }

  /// 배터리 데이터 새로고침
  Future<void> refreshBatteryData() async {
    if (_vehicleInfo == null) {
      return;
    }

    // 한국어 주석: 새로고침은 네트워크 강제 갱신 (캐시 무시)
    await _loadBatteryData(useCache: false);
  }

  /// 배터리 에러 메시지 초기화
  void clearBatteryError() {
    _batteryErrorMessage = null;
    if (_batteryState == BatteryAssessmentState.failed) {
      _setBatteryState(
        _batteryData == null
            ? BatteryAssessmentState.idle
            : BatteryAssessmentState.ready,
        notify: false,
      );
    }
    notifyListeners();
  }

  Future<void> _loadBatteryDataFor({
    required String mtId,
    required int year,
    required int month,
    required bool useCache,
  }) async {
    final key = _buildCacheKey(mtId, year, month);
    if (useCache && _batteryCache.containsKey(key)) {
      _batteryData = _batteryCache[key];
      _batteryErrorMessage = null;
    }

    final isDedupeRequest = _batteryInFlightRequests.containsKey(key);
    final requestToken = _nextBatteryRequestToken(
      key: key,
      dedupe: isDedupeRequest,
    );

    _batteryErrorMessage = null;
    _setBatteryState(BatteryAssessmentState.requesting);

    final Future<BatteryStatusData> requestFuture;
    if (isDedupeRequest) {
      requestFuture = _batteryInFlightRequests[key]!;
    } else {
      requestFuture = _batteryService.fetchBatteryStatusFromApi(
        mtId: mtId,
        year: year,
        month: month,
        onStateChanged: (state) {
          if (!_isActiveBatteryRequest(requestToken, key)) {
            return;
          }
          if (state == BatteryAssessmentState.requesting ||
              state == BatteryAssessmentState.processing) {
            _setBatteryState(state);
          }
        },
        isCancelled: () => !_isActiveBatteryRequest(requestToken, key),
      );
      _batteryInFlightRequests[key] = requestFuture;
    }

    try {
      final data = await requestFuture;
      if (!_isActiveBatteryRequest(requestToken, key)) {
        return;
      }

      _batteryData = data;
      _batteryCache[key] = data;
      _batteryErrorMessage = null;
      _setBatteryState(BatteryAssessmentState.ready);
    } on BatteryRequestCancelledException {
      if (!_isActiveBatteryRequest(requestToken, key)) {
        return;
      }
      _setBatteryState(
        _batteryData == null
            ? BatteryAssessmentState.idle
            : BatteryAssessmentState.ready,
      );
    } catch (e) {
      if (!_isActiveBatteryRequest(requestToken, key)) {
        return;
      }

      _batteryErrorMessage = _resolveBatteryErrorMessage(e);
      _setBatteryState(BatteryAssessmentState.failed);
    } finally {
      if (!isDedupeRequest &&
          identical(_batteryInFlightRequests[key], requestFuture)) {
        _batteryInFlightRequests.remove(key);
      }
    }
  }

  String _resolveBatteryErrorMessage(Object error) {
    if (error is BatteryStatusException) {
      return error.message;
    }

    final message = error.toString();
    const exceptionPrefix = 'Exception: ';
    if (message.startsWith(exceptionPrefix)) {
      return message.substring(exceptionPrefix.length);
    }
    return message;
  }

  int _nextBatteryRequestToken({required String key, required bool dedupe}) {
    final hasSameActiveRequest =
        dedupe &&
        _activeBatteryRequestKey == key &&
        _batteryInFlightRequests.containsKey(key);

    if (hasSameActiveRequest) {
      return _batteryRequestToken;
    }

    _batteryRequestToken += 1;
    _activeBatteryRequestKey = key;
    return _batteryRequestToken;
  }

  bool _isActiveBatteryRequest(int token, String key) {
    return _batteryRequestToken == token && _activeBatteryRequestKey == key;
  }

  void _setBatteryState(BatteryAssessmentState state, {bool notify = true}) {
    _batteryState = state;
    if (notify) {
      notifyListeners();
    }
  }

  /// 화면 이탈/탭 전환 시 진행 중 polling 결과를 무효화
  void cancelBatteryPolling({bool notify = true}) {
    _batteryRequestToken += 1;
    _activeBatteryRequestKey = null;
    if (!notify) {
      return;
    }

    _setBatteryState(
      _batteryData == null
          ? BatteryAssessmentState.idle
          : BatteryAssessmentState.ready,
    );
  }

  // 한국어 주석: 캐시 키 빌더 (mtId|year-month)
  String _buildCacheKey(String mtId, int year, int month) {
    return '$mtId|$year-${month.toString().padLeft(2, '0')}';
  }

  /// 한국어 주석: 차량 관리 화면에서 활성 차량을 변경한 직후
  /// 새 MT_ID로 운전 점수(및 필요 시 배터리) 데이터를 빠르게 로드하기 위한 헬퍼
  Future<void> applyActiveVehicleAndReload(VehicleInfo vehicle) async {
    // 한국어 주석: 차량 적용 시 mtid 및 차량번호 디버그 출력
    AppLogger.debug(
      '📊 [차량정보] 활성 차량 적용: ${vehicle.vehicleNumber} (MT_ID: ${vehicle.mtId})',
    );

    // 즉시 활성 차량 교체 및 상태 반영
    clearError();
    _vehicleInfo = vehicle;

    _hasVehicle = true;
    // 한국어 주석: 배터리/점수는 새 차량 기준으로 재계산
    _scoreData = null;
    _dailyHabitsMap = null;
    _selectedDate = null;
    _lastScoreUpdatedAt = null;
    // 배터리는 탭 진입 시 로드하므로 여기서는 초기화만
    cancelBatteryPolling(notify: false);
    _batteryData = null;
    _batteryErrorMessage = null;
    _setBatteryState(BatteryAssessmentState.idle, notify: false);
    notifyListeners(); // 즉시 UI 반영: 새 차량 정보를 구독자들에게 알림

    await withLoading(() async {
      await _loadScoreData(useCache: true);
    });
  }
}
