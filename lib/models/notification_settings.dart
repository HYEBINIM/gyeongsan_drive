/// 알림 설정 모델
class NotificationSettings {
  /// 전체 알림 수신 여부 (마스터 스위치)
  final bool enabled;

  /// 알림 소리 여부
  final bool sound;

  /// 알림 진동 여부
  final bool vibration;

  /// 공지사항 알림 수신 여부
  final bool announcements;

  /// 문의 답변 알림 수신 여부
  final bool inquiryReplies;

  const NotificationSettings({
    required this.enabled,
    required this.sound,
    required this.vibration,
    this.announcements = true,
    this.inquiryReplies = true,
  });

  /// 기본값 생성
  /// 모든 알림 설정이 활성화된 상태
  static NotificationSettings defaults() => const NotificationSettings(
    enabled: true,
    sound: true,
    vibration: true,
    announcements: true,
    inquiryReplies: true,
  );

  /// JSON에서 역직렬화
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] as bool? ?? true,
      sound: json['sound'] as bool? ?? true,
      vibration: json['vibration'] as bool? ?? true,
      announcements: json['announcements'] as bool? ?? true,
      inquiryReplies: json['inquiryReplies'] as bool? ?? true,
    );
  }

  /// JSON으로 직렬화
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'sound': sound,
      'vibration': vibration,
      'announcements': announcements,
      'inquiryReplies': inquiryReplies,
    };
  }

  /// 복사본 생성 (불변 객체 패턴)
  NotificationSettings copyWith({
    bool? enabled,
    bool? sound,
    bool? vibration,
    bool? announcements,
    bool? inquiryReplies,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
      announcements: announcements ?? this.announcements,
      inquiryReplies: inquiryReplies ?? this.inquiryReplies,
    );
  }

  @override
  String toString() {
    return 'NotificationSettings(enabled: $enabled, sound: $sound, vibration: $vibration, announcements: $announcements, inquiryReplies: $inquiryReplies)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        other.enabled == enabled &&
        other.sound == sound &&
        other.vibration == vibration &&
        other.announcements == announcements &&
        other.inquiryReplies == inquiryReplies;
  }

  @override
  int get hashCode =>
      Object.hash(enabled, sound, vibration, announcements, inquiryReplies);
}
