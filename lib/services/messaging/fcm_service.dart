// UTF-8 인코딩 파일
// 한국어 주석: Firebase Cloud Messaging 서비스

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/firestore_database_service.dart';
import '../../routes/app_routes.dart';
import '../../main.dart' show navigatorKey;

/// FCM 푸시 알림 서비스
class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirestoreDatabaseService _db = FirestoreDatabaseService();

  bool _initialized = false;
  String? _fcmToken;

  /// FCM 토큰 getter
  String? get fcmToken => _fcmToken;

  /// 초기화
  Future<void> initialize() async {
    if (_initialized) return;

    // 권한 요청 (iOS)
    await _requestPermission();

    // FCM 토큰 가져오기
    _fcmToken = await _messaging.getToken();
    if (_fcmToken != null) {
      // Firestore에 FCM 토큰 저장
      await _saveFCMTokenToFirestore(_fcmToken!);
    }

    // 토큰 갱신 리스너
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveFCMTokenToFirestore(newToken);
    });

    // 로컬 알림 초기화
    await _initializeLocalNotifications();

    // Foreground 메시지 핸들러
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background 메시지 핸들러 (main.dart에서 등록)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 한국어 주석: 앱이 종료된 상태에서 알림으로 시작된 경우 처리
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    _initialized = true;
  }

  /// 권한 요청 (iOS 및 Android 13+)
  Future<void> _requestPermission() async {
    // iOS 권한 요청
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // 권한 거부됨
      return;
    }

    // Android: Firebase Messaging SDK가 자동으로 런타임 권한 요청
    // requestPermission() 호출 시 Android 13+ (API 33+)에서도 자동 처리됨
  }

  /// FCM 토큰을 Firestore에 저장
  Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      // Firebase Auth에서 현재 사용자 UID 가져오기
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _db.saveUserFCMToken(user.uid, token);
      }
    } catch (e) {
      // 에러 무시 (로그인 전일 수 있음)
    }
  }

  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        // 알림 탭 시 처리
        _handleNotificationTap(details.payload);
      },
    );

    // Android 채널 생성
    const channel = AndroidNotificationChannel(
      'general_notifications',
      '일반 알림',
      description: '공지사항 및 문의 답변 알림',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Foreground 메시지 핸들러
  void _handleForegroundMessage(RemoteMessage message) {
    // 앱이 foreground일 때 로컬 알림 표시
    final notification = message.notification;
    if (notification != null) {
      // payload 형식: "type:id"
      final type = message.data['type'] ?? '';
      final id =
          message.data['announcementId'] ?? message.data['inquiryId'] ?? '';
      final payload = '$type:$id';

      _showLocalNotification(
        title: notification.title ?? '',
        body: notification.body ?? '',
        payload: payload,
      );
    }
  }

  /// 메시지 열림 핸들러 (Background → Foreground)
  void _handleMessageOpenedApp(RemoteMessage message) {
    // 알림 탭으로 앱 열림
    final type = message.data['type'] ?? '';
    final id =
        message.data['announcementId'] ?? message.data['inquiryId'] ?? '';
    final payload = '$type:$id';
    _handleNotificationTap(payload);
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'general_notifications',
      '일반 알림',
      channelDescription: '공지사항 및 문의 답변 알림',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 2147483647,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  /// 알림 탭 핸들러
  void _handleNotificationTap(String? payload) {
    if (payload == null) return;

    // payload 형식: "type:id" (예: "announcement:abc123" 또는 "inquiry_reply:xyz789")
    final parts = payload.split(':');
    if (parts.length != 2) return;

    final type = parts[0];
    final id = parts[1];

    // 한국어 주석: 첫 프레임 이후에 네비게이션을 수행하여
    // 딥링크가 앱 시작 직후에도 안전하게 동작하도록 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Navigator Key를 사용하여 화면 이동
      final context = navigatorKey.currentContext;
      if (context == null) {
        return;
      }

      // 타입에 따라 화면 이동
      switch (type) {
        case 'announcement':
          // 공지사항 상세 화면으로 이동 (ID 기반 딥링크)
          Navigator.pushNamed(
            context,
            AppRoutes.announcementDetail,
            arguments: id, // 공지사항 ID 전달
          );
          break;
        case 'inquiry_reply':
          // 문의 상세 화면으로 이동 (ID 기반 딥링크)
          Navigator.pushNamed(
            context,
            AppRoutes.inquiryDetail,
            arguments: id, // 문의 ID 전달
          );
          break;
      }
    });
  }

  /// 특정 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// 특정 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}

/// Background 메시지 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background 메시지 처리 (로그 등)
}
