// UTF-8 인코딩 파일
// 한국어 주석: 안전귀가 모니터링 서비스 (위치 이상/도착 시간 초과)

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/location_model.dart';
import '../../models/safe_home_event.dart';
import '../../models/safe_home_settings.dart';
import '../location/location_service.dart';

/// 한국어 주석: 안전귀가 모니터링 서비스
/// - 위치 스트림을 구독하여 일정 시간 동안 움직임이 없으면 이상 감지
/// - 설정된 도착 시간 + 허용치 초과 시 이벤트 발생
/// - KISS/DRY: 최소 요구 기능만 구현, 콜백 대신 Stream으로 단일 이벤트 채널 제공
class SafeHomeMonitorService {
  final LocationService _locationService;

  StreamSubscription<LocationModel>? _locationSub; // 위치 구독
  final StreamController<SafeHomeEvent> _eventCtrl =
      StreamController<SafeHomeEvent>.broadcast();

  Timer? _noMovementTimer; // 움직임 없음 타이머
  Timer? _arrivalTimeoutTimer; // 도착 시간 초과 타이머

  // 한국어 주석: 내부 상태
  SafeHomeSettings? _settings;
  DateTime? _modeStartedAt;
  DateTime? _lastMovedAt; // 마지막으로 의미있는 이동이 감지된 시각
  LocationModel? _lastLocation;

  // 한국어 주석: 노이즈 방지를 위한 최소 이동 거리(미터)
  static const double _minMovementMeters = 15.0;

  SafeHomeMonitorService({required LocationService locationService})
    : _locationService = locationService;

  /// 한국어 주석: 이벤트 스트림 (UI/VM에서 구독)
  Stream<SafeHomeEvent> get events => _eventCtrl.stream;

  /// 한국어 주석: 모니터링 시작
  /// - 설정과 모드 시작 시각을 전달받아 타이머와 위치 스트림을 초기화
  Future<void> start({
    required SafeHomeSettings settings,
    required DateTime modeStartedAt,
  }) async {
    _settings = settings;
    _modeStartedAt = modeStartedAt;
    _lastMovedAt = DateTime.now();

    // 위치 스트림 시작 (이미 다른 VM에서 추적 중이어도 독립 구독 가능)
    _locationSub?.cancel();
    // 한국어 주석: 안전귀가 모드에서는 백그라운드에서도 지속되도록 전용 스트림 사용
    _locationSub = _locationService
        .getSafeHomeBackgroundLocationStream()
        .listen(
          _onLocation,
          onError: (error) {
            debugPrint('❌ 모니터링 위치 스트림 에러: $error');
          },
        );

    // 타이머 설정
    _scheduleNoMovementTimer();
    _scheduleArrivalTimeoutTimer();
    debugPrint('✅ 안전귀가 모니터링 시작');
  }

  /// 한국어 주석: 모니터링 중지 (리소스 정리)
  void stop() {
    _locationSub?.cancel();
    _locationSub = null;
    _noMovementTimer?.cancel();
    _arrivalTimeoutTimer?.cancel();
    _noMovementTimer = null;
    _arrivalTimeoutTimer = null;
    _lastLocation = null;
    _lastMovedAt = null;
    debugPrint('⏹️ 안전귀가 모니터링 중지');
  }

  /// 한국어 주석: 설정 변경 반영 (필요 시)
  void updateSettings(SafeHomeSettings settings) {
    _settings = settings;
    // 설정 변경 시 타이머 재설정
    _scheduleNoMovementTimer();
    _scheduleArrivalTimeoutTimer();
  }

  // ==========================================================================
  // 내부 구현
  // ==========================================================================

  /// 한국어 주석: 위치 업데이트 처리
  void _onLocation(LocationModel location) {
    if (_lastLocation == null) {
      _lastLocation = location;
      _lastMovedAt = DateTime.now();
      return;
    }

    final movedMeters = _locationService.getDistanceBetween(
      startLatitude: _lastLocation!.latitude,
      startLongitude: _lastLocation!.longitude,
      endLatitude: location.latitude,
      endLongitude: location.longitude,
    );

    if (movedMeters >= _minMovementMeters) {
      _lastLocation = location;
      _lastMovedAt = DateTime.now();
      // 한국어 주석: 의미있는 이동이 있으면 움직임 없음 타이머를 재설정
      _scheduleNoMovementTimer();
    }
  }

  /// 한국어 주석: 움직임 없음 타이머 재설정
  void _scheduleNoMovementTimer() {
    _noMovementTimer?.cancel();
    if (_settings == null || _lastMovedAt == null) return;

    final minutes = _settings!.noMovementDetectionMinutes;
    final triggerAt = _lastMovedAt!.add(Duration(minutes: minutes));
    final delay = triggerAt.difference(DateTime.now());

    if (delay.isNegative) {
      // 이미 초과한 경우 즉시 이벤트 발행 (중복 방지 위해 0ms 지연)
      _noMovementTimer = Timer(
        const Duration(milliseconds: 1),
        _emitNoMovement,
      );
    } else {
      _noMovementTimer = Timer(delay, _emitNoMovement);
    }
  }

  /// 한국어 주석: 도착 시간 초과 타이머 재설정
  void _scheduleArrivalTimeoutTimer() {
    _arrivalTimeoutTimer?.cancel();
    if (_settings?.arrivalTime == null || _modeStartedAt == null) return;

    final planned = _computePlannedArrivalDateTime(
      _settings!.arrivalTime!,
      _modeStartedAt!,
    );
    final overlay = Duration(minutes: _settings!.arrivalTimeOverlayMinutes);
    final triggerAt = planned.add(overlay);
    final delay = triggerAt.difference(DateTime.now());

    if (delay.isNegative) {
      _arrivalTimeoutTimer = Timer(
        const Duration(milliseconds: 1),
        _emitArrivalTimeout,
      );
    } else {
      _arrivalTimeoutTimer = Timer(delay, _emitArrivalTimeout);
    }
  }

  /// 한국어 주석: 도착 예정 시각 계산
  /// - 모드 시작일의 HH:mm을 기준으로 계산
  /// - 모드 시작 시각 이후 시간이면 다음날로 롤오버
  DateTime _computePlannedArrivalDateTime(String hhmm, DateTime baseDay) {
    final parts = hhmm.split(':');
    int hour = 0;
    int minute = 0;

    if (parts.length == 2) {
      final parsedHour = int.tryParse(parts[0]);
      final parsedMinute = int.tryParse(parts[1]);

      if (parsedHour == null || parsedMinute == null) {
        debugPrint('⚠️ 도착 시간 파싱 실패: "$hhmm" (잘못된 숫자 형식) → 기본값 00:00 사용');
      } else {
        hour = parsedHour;
        minute = parsedMinute;
      }
    } else {
      debugPrint('⚠️ 잘못된 도착 시간 형식: "$hhmm" (HH:mm 필요) → 기본값 00:00 사용');
    }

    final planned = DateTime(
      baseDay.year,
      baseDay.month,
      baseDay.day,
      hour,
      minute,
    );
    if (planned.isBefore(baseDay)) {
      return planned.add(const Duration(days: 1));
    }
    return planned;
  }

  /// 한국어 주석: 움직임 없음 이벤트 발행
  void _emitNoMovement() {
    final now = DateTime.now();
    _eventCtrl.add(
      SafeHomeEvent(
        type: SafeHomeEventType.noMovementDetected,
        message: '설정 시간 동안 움직임이 감지되지 않았습니다.',
        timestamp: now,
      ),
    );
    // 한국어 주석: 계속 가만히 있을 수 있으므로,
    // 마지막 이동 시각을 현재 시각으로 갱신한 뒤 동일한 대기 시간 후에
    // 다시 움직임 없음 이벤트를 발생시키도록 타이머를 재설정합니다.
    _lastMovedAt = now;
    _scheduleNoMovementTimer();
  }

  /// 한국어 주석: 도착 시간 초과 이벤트 발행
  void _emitArrivalTimeout() {
    _eventCtrl.add(
      SafeHomeEvent(
        type: SafeHomeEventType.arrivalTimeExceeded,
        message: '도착 예정 시간을 초과했습니다.',
        timestamp: DateTime.now(),
      ),
    );
    // 한국어 주석: 1회성 이벤트. 필요 시 외부에서 재스케줄
  }

  /// 한국어 주석: 폐기
  void dispose() {
    stop();
    _eventCtrl.close();
  }
}
