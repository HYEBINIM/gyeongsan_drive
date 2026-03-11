import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/database/firestore_database_service.dart';
import '../base/base_view_model.dart';
import '../base/auth_mixin.dart';

/// 프로필 화면 ViewModel
/// 사용자 정보 조회 및 실시간 업데이트를 담당
class ProfileViewModel extends BaseViewModel with AuthMixin {
  final FirestoreDatabaseService _databaseService = FirestoreDatabaseService();

  @override
  final FirebaseAuthService authService;

  ProfileViewModel({required this.authService});

  /// 현재 사용자 정보 (캐시)
  User? _currentUser;

  /// 현재 사용자 정보 getter
  @override
  User? get currentUser => _currentUser;

  /// 사용자 이름
  @override
  String get displayName => _currentUser?.displayName ?? '사용자';

  /// 사용자 이메일
  String get email => _currentUser?.email ?? '';

  /// 프로필 사진 URL
  String? get photoURL => _currentUser?.photoURL;

  /// 초기화 - 현재 사용자 정보 로드
  void initialize() {
    _currentUser = authService.currentUser;
    notifyListeners();
  }

  /// 사용자 정보 새로고침
  /// 다른 화면에서 프로필 정보가 변경된 경우 호출하여 UI 업데이트
  Future<void> refreshUserInfo() async {
    await withLoadingSilent(() async {
      // Firebase Auth에서 최신 사용자 정보 가져오기
      await authService.currentUser?.reload();
      _currentUser = authService.currentUser;
    });
  }

  /// 이메일 동기화 체크
  /// Firebase Auth와 Firestore의 이메일이 다른 경우 Firestore 업데이트
  /// 이메일 변경 인증 완료 후 앱으로 돌아왔을 때 자동 호출
  Future<void> checkAndSyncEmail() async {
    await withLoadingSilent(() async {
      final userId = requiredUserId;
      final authEmail = currentUser?.email;

      if (authEmail == null) {
        return;
      }

      // Firestore에서 사용자 데이터 조회
      final userData = await _databaseService.getUserData(userId);

      if (userData == null) {
        return;
      }

      final firestoreEmail = userData.email;

      // Firebase Auth와 Firestore의 이메일이 다른 경우 동기화
      if (authEmail != firestoreEmail) {
        debugPrint('이메일 불일치 감지: Auth=$authEmail, Firestore=$firestoreEmail');
        await _databaseService.updateEmail(userId, firestoreEmail, authEmail);
        debugPrint('Firestore 이메일 동기화 완료');
      }
    });
  }
}
