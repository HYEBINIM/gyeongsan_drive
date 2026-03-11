import 'package:flutter/material.dart';
import '../../models/safe_home_settings.dart';
import '../../models/destination_search_result.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/safe_home/firestore_safe_home_service.dart';
import '../../services/destination_search/destination_search_service.dart';
import '../../utils/crypto_utils.dart';
import '../base/base_view_model.dart';
import '../base/auth_mixin.dart';

/// 안전귀가 설정 ViewModel
class SafeHomeSettingsViewModel extends BaseViewModel with AuthMixin {
  final FirestoreSafeHomeService _databaseService;
  final DestinationSearchService _searchService;

  @override
  final FirebaseAuthService authService;

  // 상태
  SafeHomeSettings? _settings;

  // Getters
  SafeHomeSettings? get settings => _settings;
  String? get destination => _settings?.destination;
  String? get arrivalTime => _settings?.arrivalTime;
  TimeOfDay? get arrivalTimeOfDay => _settings?.arrivalTimeOfDay;
  bool get autoReport => _settings?.autoReport ?? false;
  bool get isPasswordSet => _settings?.isPasswordSet ?? false;
  List<EmergencyContact> get emergencyContacts =>
      _settings?.emergencyContacts ?? [];
  int get noMovementDetectionMinutes =>
      _settings?.noMovementDetectionMinutes ?? 5;
  int get arrivalTimeOverlayMinutes =>
      _settings?.arrivalTimeOverlayMinutes ?? 5;
  int get warningAlertCount => _settings?.warningAlertCount ?? 3;
  bool get isModeActive => _settings?.isModeActive ?? false;
  DateTime? get modeStartedAt => _settings?.modeStartedAt;
  String? get passwordHash => _settings?.passwordHash;

  /// 검색 서비스 접근 (Bottom Sheet에서 사용)
  DestinationSearchService get searchService => _searchService;

  SafeHomeSettingsViewModel({
    required FirestoreSafeHomeService databaseService,
    required this.authService,
    required DestinationSearchService searchService,
  }) : _databaseService = databaseService,
       _searchService = searchService;

  /// 초기화 (Firebase에서 설정 불러오기)
  Future<void> initialize() async {
    await withLoading(() async {
      final userId = requiredUserId;

      _settings = await _databaseService.getSafeHomeSettings(userId);

      // 설정이 없으면 기본값 생성 및 저장
      if (_settings == null) {
        _settings = const SafeHomeSettings(
          autoReport: false,
          isPasswordSet: false,
          emergencyContacts: [],
        );
        await _databaseService.saveSafeHomeSettings(userId, _settings!);
      }
    });
  }

  /// 목적지 설정
  Future<void> setDestination(String destination) async {
    final userId = requiredUserId;

    await _databaseService.updateSafeHomeSettings(userId, {
      'destination': destination,
    });

    _settings = _settings?.copyWith(destination: destination);
    notifyListeners();
  }

  /// 목적지 위치(위도/경도) 설정
  Future<void> setDestinationLocation(double lat, double lng) async {
    final userId = requiredUserId;

    await _databaseService.updateSafeHomeSettings(userId, {
      'destination_lat': lat,
      'destination_lng': lng,
    });

    _settings = _settings?.copyWith(destinationLat: lat, destinationLng: lng);
    notifyListeners();
  }

  /// 검색 결과에서 목적지 선택
  /// 목적지명과 좌표를 한 번에 설정
  Future<void> selectDestination(SearchResult result) async {
    final userId = requiredUserId;

    // 한 번의 요청으로 목적지명과 좌표를 함께 저장
    await _databaseService.updateSafeHomeSettings(userId, {
      'destination': result.placeName,
      'destination_lat': result.lat,
      'destination_lng': result.lng,
    });

    _settings = _settings?.copyWith(
      destination: result.placeName,
      destinationLat: result.lat,
      destinationLng: result.lng,
    );

    notifyListeners();
  }

  /// 도착 시간 설정
  Future<void> setArrivalTime(TimeOfDay time) async {
    final userId = requiredUserId;

    final timeString =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    await _databaseService.updateSafeHomeSettings(userId, {
      'arrival_time': timeString,
    });

    _settings = _settings?.copyWith(arrivalTime: timeString);
    notifyListeners();
  }

  /// 자동신고 토글
  Future<void> toggleAutoReport(bool enabled) async {
    final userId = requiredUserId;

    await _databaseService.updateSafeHomeSettings(userId, {
      'auto_report': enabled,
    });

    _settings = _settings?.copyWith(autoReport: enabled);
    notifyListeners();
  }

  /// 보안 암호 설정 상태 변경
  Future<void> setPasswordStatus(bool isSet) async {
    final userId = requiredUserId;

    await _databaseService.updateSafeHomeSettings(userId, {
      'is_password_set': isSet,
    });

    _settings = _settings?.copyWith(isPasswordSet: isSet);
    notifyListeners();
  }

  /// 비상 연락처 추가
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    final userId = requiredUserId;

    final updatedContacts = [...emergencyContacts, contact];

    await _databaseService.updateSafeHomeSettings(userId, {
      'emergency_contacts': updatedContacts.map((c) => c.toJson()).toList(),
    });

    _settings = _settings?.copyWith(emergencyContacts: updatedContacts);
    notifyListeners();
  }

  /// 비상 연락처 삭제
  Future<void> removeEmergencyContact(int index) async {
    final userId = requiredUserId;

    if (index < 0 || index >= emergencyContacts.length) {
      throw '잘못된 인덱스입니다.';
    }

    final updatedContacts = [...emergencyContacts];
    updatedContacts.removeAt(index);

    await _databaseService.updateSafeHomeSettings(userId, {
      'emergency_contacts': updatedContacts.map((c) => c.toJson()).toList(),
    });

    _settings = _settings?.copyWith(emergencyContacts: updatedContacts);
    notifyListeners();
  }

  // ============================================================================
  // 이상 감지 기준 설정 메서드
  // ============================================================================

  /// 음직임 없음 감지 시간 설정
  Future<void> updateNoMovementDetection(int minutes) async {
    await _updateThresholdSetting(
      key: 'no_movement_detection_minutes',
      value: minutes,
      updateLocal: (settings) =>
          settings.copyWith(noMovementDetectionMinutes: minutes),
    );
  }

  /// 도착시간 초과 허용 설정
  Future<void> updateArrivalTimeOverlay(int minutes) async {
    await _updateThresholdSetting(
      key: 'arrival_time_overlay_minutes',
      value: minutes,
      updateLocal: (settings) =>
          settings.copyWith(arrivalTimeOverlayMinutes: minutes),
    );
  }

  /// 경고 알림 횟수 설정
  Future<void> updateWarningAlertCount(int count) async {
    await _updateThresholdSetting(
      key: 'warning_alert_count',
      value: count,
      updateLocal: (settings) => settings.copyWith(warningAlertCount: count),
    );
  }

  Future<void> _updateThresholdSetting({
    required String key,
    required int value,
    required SafeHomeSettings Function(SafeHomeSettings settings) updateLocal,
  }) async {
    await _updateSingleSetting(key, value);
    if (_settings != null) {
      _settings = updateLocal(_settings!);
    }
    notifyListeners();
  }

  /// 단일 설정 업데이트 공통 로직 (DRY 원칙)
  Future<void> _updateSingleSetting(String key, int value) async {
    final userId = requiredUserId;

    await _databaseService.updateSafeHomeSettings(userId, {key: value});
  }

  // ============================================================================
  // 보안 암호 관리 메서드
  // ============================================================================

  /// 보안 암호 설정
  Future<void> setPassword(String pin) async {
    final hash = CryptoUtils.hashPin(pin);
    await _updateSettings({'password_hash': hash, 'is_password_set': true});
    _settings = _settings?.copyWith(passwordHash: hash, isPasswordSet: true);
  }

  /// 보안 암호 검증
  bool verifyPassword(String pin) {
    if (passwordHash == null) return false;
    return CryptoUtils.verifyPin(pin, passwordHash!);
  }

  /// 보안 암호 삭제
  Future<void> deletePassword(String currentPin) async {
    if (!verifyPassword(currentPin)) {
      throw '암호가 일치하지 않습니다';
    }
    await _updateSettings({'password_hash': null, 'is_password_set': false});
    _settings = _settings?.copyWith(passwordHash: null, isPasswordSet: false);
  }

  // ============================================================================
  // 안전귀가 모드 관리 메서드
  // ============================================================================

  /// 안전귀가 모드 시작 가능 여부 확인
  /// - 목적지, 도착 시간, 비상 연락처, 보안 암호가 모두 설정되어 있어야 함
  bool canStartSafeHomeMode() {
    if (_settings == null) return false;

    // 목적지 설정 여부
    if (_settings!.destination == null ||
        _settings!.destinationLat == null ||
        _settings!.destinationLng == null) {
      return false;
    }

    // 도착 시간 설정 여부
    if (_settings!.arrivalTime == null) {
      return false;
    }

    // 비상 연락처 1개 이상 여부
    if (_settings!.emergencyContacts.isEmpty) {
      return false;
    }

    // 보안 암호 설정 여부 (필수 조건 추가)
    if (!_settings!.isPasswordSet || _settings!.passwordHash == null) {
      return false;
    }

    return true;
  }

  /// 미완료된 필수 설정 항목 목록 반환
  List<String> getMissingRequirements() {
    final missing = <String>[];

    if (_settings?.destination == null ||
        _settings?.destinationLat == null ||
        _settings?.destinationLng == null) {
      missing.add('목적지');
    }

    if (_settings?.arrivalTime == null) {
      missing.add('도착 시간');
    }

    if (_settings?.emergencyContacts.isEmpty ?? true) {
      missing.add('비상 연락처');
    }

    if (!(_settings?.isPasswordSet ?? false) ||
        _settings?.passwordHash == null) {
      missing.add('보안 암호');
    }

    return missing;
  }

  /// 안전귀가 모드 시작
  Future<void> startSafeHomeMode() async {
    if (!canStartSafeHomeMode()) {
      throw '필수 설정이 완료되지 않았습니다';
    }

    // 한국어 주석: Firebase와 로컬 상태 간 시각 동기화를 위해 한 번만 호출
    final now = DateTime.now();
    await _updateSettings({
      'is_mode_active': true,
      'mode_started_at': now.millisecondsSinceEpoch,
    });

    _settings = _settings?.copyWith(isModeActive: true, modeStartedAt: now);
    // 한국어 주석: 로컬 상태(_settings) 갱신 후에도 구독자들이
    // 변경된 값을 즉시 반영하도록 알림을 한 번 더 보냅니다.
    notifyListeners();
  }

  /// 안전귀가 모드 종료
  Future<void> stopSafeHomeMode() async {
    await _updateSettings({'is_mode_active': false, 'mode_started_at': null});

    _settings = _settings?.copyWith(isModeActive: false, modeStartedAt: null);
    // 한국어 주석: 시작 로직과 동일하게 로컬 상태 변경 직후에도 알림을 보냅니다.
    notifyListeners();
  }

  // ============================================================================
  // 범용 설정 업데이트 메서드
  // ============================================================================

  /// 범용 설정 업데이트 메서드 (DRY 원칙)
  Future<void> _updateSettings(Map<String, dynamic> updates) async {
    final userId = requiredUserId;

    await _databaseService.updateSafeHomeSettings(userId, updates);
    notifyListeners();
  }
}
