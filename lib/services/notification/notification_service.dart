// UTF-8 인코딩 파일
// 한국어 주석: 시스템 알림(채널) 기반 진동을 사용하기 위한 로컬 알림 서비스

import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/safe_home_event.dart';
import '../../models/notification_settings.dart';
import '../storage/local_storage_service.dart';

/// 한국어 주석: 시스템 알림 진동 사용을 위한 최소 래퍼
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final LocalStorageService _storageService = LocalStorageService();

  bool _initialized = false;
  bool _permissionRequested = false; // 권한 중복 요청 방지용
  NotificationSettings _settings = NotificationSettings.defaults();

  // 한국어 주석: Android 채널 정보 - 설정에 따라 동적 생성
  // 채널은 한 번 생성되면 설정 변경 불가 → 설정 조합별로 다른 채널 사용
  String _getChannelId() {
    // 설정 조합에 따른 고유 채널 ID
    final soundStr = _settings.sound ? 'sound' : 'nosound';
    final vibrationStr = _settings.vibration ? 'vib' : 'novib';
    return 'safehome_${soundStr}_$vibrationStr';
  }

  AndroidNotificationChannel _createChannel() {
    return AndroidNotificationChannel(
      _getChannelId(),
      '안전귀가 알림',
      description: '안전귀가 이상 감지/도착 시간 초과 알림',
      importance: Importance.high,
      enableVibration: _settings.vibration, // 설정에 따른 진동
      playSound: _settings.sound, // 설정에 따른 소리
      showBadge: false,
    );
  }

  /// 한국어 주석: 초기화 및 권한 요청 (한 번만)
  Future<void> initialize() async {
    if (_initialized) return;

    // 저장된 알림 설정 로드
    try {
      _settings = await _storageService.getNotificationSettings();
    } catch (e) {
      _settings = NotificationSettings.defaults();
    }

    // Android 초기화 설정
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 초기화 설정 (권한 요청 없이 초기화만 수행)
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false, // 권한은 나중에 requestPermission()에서 요청
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[],
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    // Android: 현재 설정에 맞는 채널 생성
    await _createAndRegisterChannel();

    _initialized = true;
  }

  /// 한국어 주석: 채널 생성 및 등록
  Future<void> _createAndRegisterChannel() async {
    final channel = _createChannel();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// 한국어 주석: 알림 설정 업데이트 (ViewModel에서 호출)
  Future<void> updateSettings(NotificationSettings settings) async {
    _settings = settings;
    // 설정 변경 시 새로운 채널 생성 (기존 채널은 유지)
    if (_initialized) {
      await _createAndRegisterChannel();
    }
  }

  /// 한국어 주석: 알림 권한 요청 (안전귀가 기능 사용 시 호출)
  /// 반환값: 권한이 승인되면 true, 거부되면 false
  Future<bool> requestPermission() async {
    // 중복 요청 방지
    if (_permissionRequested) {
      return true; // 이미 요청된 경우 true 반환 (실패 아님)
    }

    // 초기화되지 않았으면 먼저 초기화
    if (!_initialized) {
      await initialize();
    }

    bool granted = false;

    // Android 13+ 권한 요청
    if (Platform.isAndroid) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      granted = result ?? false;
    }

    // iOS 권한 요청
    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      granted = result ?? false;
    }

    _permissionRequested = true;

    return granted;
  }

  /// 한국어 주석: 이벤트 알림 표시 (설정 기반 진동/소리 사용)
  Future<void> showEventNotification(SafeHomeEvent event) async {
    if (!_initialized) await initialize();

    // 알림이 비활성화되어 있으면 표시하지 않음
    if (!_settings.enabled) return;

    // 현재 설정에 맞는 채널 사용
    final channel = _createChannel();

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: _settings.vibration, // 설정에 따른 진동
      playSound: _settings.sound, // 설정에 따른 소리
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: false,
      autoCancel: true,
      onlyAlertOnce: false, // 설정 변경 시 새 알림으로 인식되도록 false로 변경
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: _settings.sound, // 설정에 따른 소리
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String title;
    String body;
    switch (event.type) {
      case SafeHomeEventType.noMovementDetected:
        title = '움직임 없음 감지';
        body = '설정 시간 동안 움직임이 감지되지 않았습니다.';
        break;
      case SafeHomeEventType.arrivalTimeExceeded:
        title = '도착 시간 초과';
        body = '도착 예정 시간을 초과했습니다.';
        break;
    }

    await _plugin.show(
      // 한국어 주석: 동일 ID 사용 → 최신 이벤트로 갱신 (중복 방지)
      41001,
      title,
      body,
      details,
      payload: event.type.name,
    );
  }
}
