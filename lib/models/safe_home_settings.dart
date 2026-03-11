import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 안전귀가 설정 모델
class SafeHomeSettings {
  final String? destination; // 목적지 이름
  final double? destinationLat; // 목적지 위도
  final double? destinationLng; // 목적지 경도
  final String? arrivalTime; // 도착 시간 ("HH:mm" 형식)
  final bool autoReport; // 자동신고 활성화 여부
  final bool isPasswordSet; // 보안 암호 설정 여부
  final String? passwordHash; // 보안 암호 해시 (SHA-256)
  final List<EmergencyContact> emergencyContacts; // 비상 연락처 목록
  final int noMovementDetectionMinutes; // 음직임 없음 감지 시간 (분)
  final int arrivalTimeOverlayMinutes; // 도착시간 초과 허용 (분)
  final int warningAlertCount; // 경고 알림 횟수
  final bool isModeActive; // 안전귀가 모드 활성화 여부
  final DateTime? modeStartedAt; // 모드 시작 시각
  final int? updatedAt; // 업데이트 타임스탬프 (millisecondsSinceEpoch)
  final int? createdAt; // 생성 타임스탬프

  const SafeHomeSettings({
    this.destination,
    this.destinationLat,
    this.destinationLng,
    this.arrivalTime,
    this.autoReport = false,
    this.isPasswordSet = false,
    this.passwordHash,
    this.emergencyContacts = const [],
    this.noMovementDetectionMinutes = 5,
    this.arrivalTimeOverlayMinutes = 5,
    this.warningAlertCount = 3,
    this.isModeActive = false,
    this.modeStartedAt,
    this.updatedAt,
    this.createdAt,
  });

  /// Firestore Timestamp 또는 int를 millisecondsSinceEpoch로 변환
  static int? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return null;
  }

  /// Firebase JSON에서 객체 생성
  factory SafeHomeSettings.fromJson(Map<String, dynamic> json) {
    return SafeHomeSettings(
      destination: json['destination'] as String?,
      destinationLat: json['destination_lat'] as double?,
      destinationLng: json['destination_lng'] as double?,
      arrivalTime: json['arrival_time'] as String?,
      autoReport: json['auto_report'] as bool? ?? false,
      isPasswordSet: json['is_password_set'] as bool? ?? false,
      passwordHash: json['password_hash'] as String?,
      emergencyContacts:
          (json['emergency_contacts'] as List<dynamic>?)
              ?.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      noMovementDetectionMinutes:
          json['no_movement_detection_minutes'] as int? ?? 5,
      arrivalTimeOverlayMinutes:
          json['arrival_time_overlay_minutes'] as int? ?? 5,
      warningAlertCount: json['warning_alert_count'] as int? ?? 3,
      isModeActive: json['is_mode_active'] as bool? ?? false,
      modeStartedAt: json['mode_started_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['mode_started_at'] as int)
          : null,
      updatedAt: _parseTimestamp(json['updated_at']),
      createdAt: _parseTimestamp(json['created_at']),
    );
  }

  /// Firebase JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      if (destination != null) 'destination': destination,
      if (destinationLat != null) 'destination_lat': destinationLat,
      if (destinationLng != null) 'destination_lng': destinationLng,
      if (arrivalTime != null) 'arrival_time': arrivalTime,
      'auto_report': autoReport,
      'is_password_set': isPasswordSet,
      if (passwordHash != null) 'password_hash': passwordHash,
      'emergency_contacts': emergencyContacts
          .map((contact) => contact.toJson())
          .toList(),
      'no_movement_detection_minutes': noMovementDetectionMinutes,
      'arrival_time_overlay_minutes': arrivalTimeOverlayMinutes,
      'warning_alert_count': warningAlertCount,
      'is_mode_active': isModeActive,
      if (modeStartedAt != null)
        'mode_started_at': modeStartedAt!.millisecondsSinceEpoch,
      'updated_at': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
      'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 일부 필드만 변경한 새 객체 생성
  SafeHomeSettings copyWith({
    String? destination,
    double? destinationLat,
    double? destinationLng,
    String? arrivalTime,
    bool? autoReport,
    bool? isPasswordSet,
    String? passwordHash,
    List<EmergencyContact>? emergencyContacts,
    int? noMovementDetectionMinutes,
    int? arrivalTimeOverlayMinutes,
    int? warningAlertCount,
    bool? isModeActive,
    DateTime? modeStartedAt,
    int? updatedAt,
    int? createdAt,
  }) {
    return SafeHomeSettings(
      destination: destination ?? this.destination,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      autoReport: autoReport ?? this.autoReport,
      isPasswordSet: isPasswordSet ?? this.isPasswordSet,
      passwordHash: passwordHash ?? this.passwordHash,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      noMovementDetectionMinutes:
          noMovementDetectionMinutes ?? this.noMovementDetectionMinutes,
      arrivalTimeOverlayMinutes:
          arrivalTimeOverlayMinutes ?? this.arrivalTimeOverlayMinutes,
      warningAlertCount: warningAlertCount ?? this.warningAlertCount,
      isModeActive: isModeActive ?? this.isModeActive,
      modeStartedAt: modeStartedAt ?? this.modeStartedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 도착 시간을 TimeOfDay 객체로 변환
  TimeOfDay? get arrivalTimeOfDay {
    if (arrivalTime == null) return null;
    try {
      final parts = arrivalTime!.split(':');
      if (parts.length != 2) return null;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }
}

/// 비상 연락처 모델
class EmergencyContact {
  final String name; // 연락처 이름
  final String phone; // 전화번호

  const EmergencyContact({required this.name, required this.phone});

  /// JSON에서 객체 생성
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {'name': name, 'phone': phone};
  }
}
