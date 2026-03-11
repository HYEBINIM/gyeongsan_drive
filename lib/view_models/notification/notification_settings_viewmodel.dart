// UTF-8 인코딩 파일
// 한국어 주석: 알림 설정 관리 ViewModel (KISS & YAGNI 원칙 적용)

import 'package:flutter/material.dart';
import '../../models/notification_settings.dart';
import '../../services/storage/local_storage_service.dart';
import '../../services/notification/notification_service.dart';

/// 알림 설정 관리 ViewModel
/// 전체 알림, 소리, 진동 설정 관리 및 저장
class NotificationSettingsViewModel extends ChangeNotifier {
  final LocalStorageService _storageService = LocalStorageService();
  final NotificationService _notificationService = NotificationService.instance;

  /// 현재 알림 설정
  NotificationSettings _settings = NotificationSettings.defaults();
  bool _isInitializing = false;
  bool _isInitialized = false;

  /// 알림 설정 getter
  NotificationSettings get settings => _settings;
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _isInitialized;
  bool get isReady => _isInitialized && !_isInitializing;

  /// 전체 알림 수신 여부
  bool get enabled => _settings.enabled;

  /// 알림 소리 여부
  bool get sound => _settings.sound;

  /// 알림 진동 여부
  bool get vibration => _settings.vibration;

  /// 공지사항 알림 수신 여부
  bool get announcements => _settings.announcements;

  /// 문의 답변 알림 수신 여부
  bool get inquiryReplies => _settings.inquiryReplies;

  /// 초기화: SharedPreferences에서 저장된 알림 설정 로드
  Future<void> initialize() async {
    if (_isInitializing || _isInitialized) return;

    _isInitializing = true;
    notifyListeners();

    try {
      _settings = await _storageService.getNotificationSettings();
      // NotificationService에 설정 동기화
      await _notificationService.updateSettings(_settings);
    } catch (e) {
      // 에러 발생 시 기본값 유지
      _settings = NotificationSettings.defaults();
    } finally {
      _isInitializing = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// 전체 알림 수신 토글
  /// [value] 알림 수신 활성화 여부
  Future<void> toggleEnabled(bool value) async {
    if (!isReady) return;
    if (_settings.enabled == value) return; // 같은 값이면 무시 (DRY)

    _settings = _settings.copyWith(enabled: value);
    notifyListeners(); // UI 즉시 업데이트

    try {
      await _storageService.saveNotificationSettings(_settings);
      // NotificationService에 설정 동기화
      await _notificationService.updateSettings(_settings);
    } catch (e) {
      // 저장 실패해도 UI는 이미 변경됨 (사용자 경험 우선)
      // 다음 실행 시 기본값으로 복원됨
    }
  }

  /// 알림 소리 토글
  /// [value] 알림 소리 활성화 여부
  Future<void> toggleSound(bool value) async {
    if (!isReady) return;
    if (_settings.sound == value) return; // 같은 값이면 무시 (DRY)

    _settings = _settings.copyWith(sound: value);
    notifyListeners(); // UI 즉시 업데이트

    try {
      await _storageService.saveNotificationSettings(_settings);
      // NotificationService에 설정 동기화
      await _notificationService.updateSettings(_settings);
    } catch (e) {
      // 저장 실패해도 UI는 이미 변경됨 (사용자 경험 우선)
    }
  }

  /// 알림 진동 토글
  /// [value] 알림 진동 활성화 여부
  Future<void> toggleVibration(bool value) async {
    if (!isReady) return;
    if (_settings.vibration == value) return; // 같은 값이면 무시 (DRY)

    _settings = _settings.copyWith(vibration: value);
    notifyListeners(); // UI 즉시 업데이트

    try {
      await _storageService.saveNotificationSettings(_settings);
      // NotificationService에 설정 동기화
      await _notificationService.updateSettings(_settings);
    } catch (e) {
      // 저장 실패해도 UI는 이미 변경됨 (사용자 경험 우선)
    }
  }

  /// 공지사항 알림 토글
  /// [value] 공지사항 알림 활성화 여부
  Future<void> toggleAnnouncements(bool value) async {
    if (!isReady) return;
    if (_settings.announcements == value) return;

    _settings = _settings.copyWith(announcements: value);
    notifyListeners();

    try {
      await _storageService.saveNotificationSettings(_settings);
    } catch (e) {
      // 저장 실패해도 UI는 이미 변경됨
    }
  }

  /// 문의 답변 알림 토글
  /// [value] 문의 답변 알림 활성화 여부
  Future<void> toggleInquiryReplies(bool value) async {
    if (!isReady) return;
    if (_settings.inquiryReplies == value) return;

    _settings = _settings.copyWith(inquiryReplies: value);
    notifyListeners();

    try {
      await _storageService.saveNotificationSettings(_settings);
    } catch (e) {
      // 저장 실패해도 UI는 이미 변경됨
    }
  }
}
