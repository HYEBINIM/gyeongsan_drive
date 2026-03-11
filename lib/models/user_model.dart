import 'package:firebase_auth/firebase_auth.dart';
import 'notification_settings.dart';

/// 사용자 데이터 모델
/// Firebase Realtime Database에 저장될 사용자 정보
class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String provider;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  // 약관 동의 정보
  final bool agreedToService; // 이용약관 동의 여부
  final bool agreedToPrivacy; // 개인정보 처리방침 동의 여부
  final bool agreedToLocation; // 위치기반 서비스 약관 동의 여부
  final bool isOver14; // 만 14세 이상 확인
  final DateTime? termsAgreedAt; // 약관 동의 일시

  // 알림 설정 정보
  final NotificationSettings? notificationSettings;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    required this.provider,
    required this.emailVerified,
    required this.createdAt,
    required this.lastLoginAt,
    this.agreedToService = false,
    this.agreedToPrivacy = false,
    this.agreedToLocation = false,
    this.isOver14 = false,
    this.termsAgreedAt,
    this.notificationSettings,
  });

  /// Firebase User 객체에서 UserModel 생성
  factory UserModel.fromFirebaseUser(User user) {
    // 로그인 제공자 확인 (google.com, password 등)
    final provider = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password';

    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoURL: user.photoURL,
      provider: provider,
      emailVerified: user.emailVerified,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
  }

  /// JSON에서 UserModel 생성
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
      provider: json['provider'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : DateTime.now(),
      agreedToService: json['agreedToService'] as bool? ?? false,
      agreedToPrivacy: json['agreedToPrivacy'] as bool? ?? false,
      agreedToLocation: json['agreedToLocation'] as bool? ?? false,
      isOver14: json['isOver14'] as bool? ?? false,
      termsAgreedAt: json['termsAgreedAt'] != null
          ? DateTime.parse(json['termsAgreedAt'] as String)
          : null,
      notificationSettings: json['notificationSettings'] != null
          ? NotificationSettings.fromJson(
              json['notificationSettings'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// UserModel을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'provider': provider,
      'emailVerified': emailVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'agreedToService': agreedToService,
      'agreedToPrivacy': agreedToPrivacy,
      'agreedToLocation': agreedToLocation,
      'isOver14': isOver14,
      'termsAgreedAt': termsAgreedAt?.toIso8601String(),
      if (notificationSettings != null)
        'notificationSettings': notificationSettings!.toJson(),
    };
  }

  /// 마지막 로그인 시간 업데이트
  UserModel copyWithLastLogin(DateTime newLastLogin) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
      provider: provider,
      emailVerified: emailVerified,
      createdAt: createdAt,
      lastLoginAt: newLastLogin,
      agreedToService: agreedToService,
      agreedToPrivacy: agreedToPrivacy,
      agreedToLocation: agreedToLocation,
      isOver14: isOver14,
      termsAgreedAt: termsAgreedAt,
      notificationSettings: notificationSettings,
    );
  }

  /// UserModel 복사 및 일부 필드 업데이트
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    String? provider,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? agreedToService,
    bool? agreedToPrivacy,
    bool? agreedToLocation,
    bool? isOver14,
    DateTime? termsAgreedAt,
    NotificationSettings? notificationSettings,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      provider: provider ?? this.provider,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      agreedToService: agreedToService ?? this.agreedToService,
      agreedToPrivacy: agreedToPrivacy ?? this.agreedToPrivacy,
      agreedToLocation: agreedToLocation ?? this.agreedToLocation,
      isOver14: isOver14 ?? this.isOver14,
      termsAgreedAt: termsAgreedAt ?? this.termsAgreedAt,
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }
}
