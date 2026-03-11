// UTF-8 인코딩 파일
// 한국어 주석: 안전귀가 모니터링 ViewModel

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/safe_home_event.dart';
import '../../models/safe_home_settings.dart';
import '../../services/location/location_service.dart';
import '../../services/safe_home/safe_home_monitor_service.dart';
import '../../services/notification/notification_service.dart';

/// 한국어 주석: UI와 서비스 사이를 중재하는 ViewModel
/// - SafeHomeMonitorService를 감싸 이벤트를 상태로 노출
/// - 단순 상태만 보유하여 KISS/DRY를 유지
class SafeHomeMonitorViewModel extends ChangeNotifier {
  final SafeHomeMonitorService _monitorService;

  StreamSubscription<SafeHomeEvent>? _eventSub;

  // 한국어 주석: 최근 이벤트 및 발생 시각
  SafeHomeEvent? _lastEvent;

  // 한국어 주석: 경고 상태 관리 (SRP: 이벤트와 밀접한 경고 상태를 함께 관리)
  bool _isAlertActive = false;
  SafeHomeEvent? _activeAlertEvent;
  int _verificationFailCount = 0;
  // 한국어 주석: 암호 검증 성공 후 일정 시간 동안 새 이벤트를 무시하기 위한 쿨다운 종료 시각
  DateTime? _silencedUntil;
  // 한국어 주석: 안전귀가 모드 활성화 동안 발생한 경고(이상 이벤트) 횟수
  int _alertCount = 0;

  SafeHomeMonitorViewModel({LocationService? locationService})
    : _monitorService = SafeHomeMonitorService(
        locationService: locationService ?? LocationService(),
      );

  /// 한국어 주석: 최근 이벤트 Getter (UI에서 조회)
  SafeHomeEvent? get lastEvent => _lastEvent;

  /// 한국어 주석: 경고 활성화 여부
  bool get isAlertActive => _isAlertActive;

  /// 한국어 주석: 현재 활성 경고 이벤트
  SafeHomeEvent? get activeAlertEvent => _activeAlertEvent;

  /// 한국어 주석: 안전귀가 모드에서 누적된 경고 발생 횟수
  int get alertCount => _alertCount;

  /// 한국어 주석: 암호 입력 실패 횟수
  int get verificationFailCount => _verificationFailCount;

  /// 한국어 주석: 현재 쿨다운 상태 여부
  bool get isInCooldown =>
      _silencedUntil != null && DateTime.now().isBefore(_silencedUntil!);

  /// 한국어 주석: 모니터링 시작
  Future<void> start({
    required SafeHomeSettings settings,
    required DateTime modeStartedAt,
  }) async {
    // 한국어 주석: 새 모드 시작 시 경고 관련 상태 초기화
    _alertCount = 0;
    await _monitorService.start(
      settings: settings,
      modeStartedAt: modeStartedAt,
    );
    _eventSub?.cancel();
    _eventSub = _monitorService.events.listen((event) {
      // 한국어 주석: 쿨다운 중에는 새 이벤트를 무시하여 다이얼로그 재등장 방지
      if (isInCooldown) {
        return;
      }

      _lastEvent = event;
      // 한국어 주석: UI와 무관하게 시스템 알림으로 진동/알림을 표시 (백그라운드 대응)
      NotificationService.instance.showEventNotification(event);
      notifyListeners();
    });
  }

  /// 한국어 주석: 모니터링 중지
  void stop() {
    _eventSub?.cancel();
    _eventSub = null;
    _monitorService.stop();
    _lastEvent = null;
    // 한국어 주석: 모니터링 중지 시 경고도 함께 해제
    _isAlertActive = false;
    _activeAlertEvent = null;
    _verificationFailCount = 0;
    // 한국어 주석: 모드 종료 시 쿨다운도 초기화
    _silencedUntil = null;
    // 한국어 주석: 모드 종료 시 경고 횟수도 초기화
    _alertCount = 0;
    notifyListeners();
  }

  /// 한국어 주석: 설정 변경 반영
  void updateSettings(SafeHomeSettings settings) {
    _monitorService.updateSettings(settings);
  }

  /// 한국어 주석: 경고 활성화 (이벤트 발생 시 호출)
  ///
  /// 이미 활성화된 경고가 있으면 무시합니다 (중복 다이얼로그 방지).
  void activateAlert(SafeHomeEvent event) {
    if (_isAlertActive) {
      return;
    }

    _isAlertActive = true;
    _activeAlertEvent = event;
    _verificationFailCount = 0;
    notifyListeners();
  }

  /// 한국어 주석: 경고 해제 (올바른 암호 입력 시)
  void dismissAlert() {
    _isAlertActive = false;
    _activeAlertEvent = null;
    _verificationFailCount = 0;
    _lastEvent = null; // 한국어 주석: 이벤트 초기화로 다이얼로그 재표시 방지
    notifyListeners();
  }

  /// 한국어 주석: 암호 입력 실패 횟수 증가
  void incrementFailCount() {
    _verificationFailCount++;
    notifyListeners();
  }

  /// 한국어 주석: 경고(이상 이벤트) 발생 횟수 증가
  void incrementAlertCount() {
    _alertCount++;
    notifyListeners();
  }

  /// 한국어 주석: 쿨다운 적용 (해당 기간 동안 새 이벤트 무시)
  void applyCooldown(Duration duration) {
    // 한국어 주석: 음수/제로는 무시 (YAGNI: 유효성 최소화)
    if (duration.inMilliseconds <= 0) return;
    _silencedUntil = DateTime.now().add(duration);
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _monitorService.dispose();
    super.dispose();
  }
}
