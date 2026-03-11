import 'package:flutter/material.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/database/firestore_database_service.dart';

/// 프로필 편집 ViewModel
/// 사용자 이름 변경 기능을 담당
class ProfileEditViewModel extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreDatabaseService _databaseService = FirestoreDatabaseService();

  bool _isLoading = false;
  String? _errorMessage;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// 현재 사용자 이름 가져오기
  String get currentName => _authService.currentUser?.displayName ?? '';

  /// 프로필 이름 업데이트
  /// Firebase Auth와 Firestore 모두 업데이트
  Future<bool> updateProfile(String newName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUser = _authService.currentUser;

      if (currentUser == null) {
        throw '로그인된 사용자가 없습니다.';
      }

      final uid = currentUser.uid;

      // 1. Firebase Auth displayName 업데이트
      await currentUser.updateDisplayName(newName);
      await currentUser.reload();

      // 2. Firestore displayName 업데이트 (데이터 동기화)
      await _databaseService.updateDisplayName(uid, newName);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
