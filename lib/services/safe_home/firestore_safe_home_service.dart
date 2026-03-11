import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../models/safe_home_settings.dart';

/// 안전귀가 설정 Firestore 서비스
/// RTDB에서 마이그레이션됨
class FirestoreSafeHomeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'eastapp-dev',
  );

  // 안전귀가 설정은 서브컬렉션의 'current' 문서에 저장
  static const String _settingsDocId = 'current';

  /// 안전귀가 설정 저장
  /// [uid] 사용자 UID
  /// [settings] 저장할 설정 객체
  Future<void> saveSafeHomeSettings(
    String uid,
    SafeHomeSettings settings,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('safe_home_settings')
          .doc(_settingsDocId)
          .set(settings.toJson());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다. 로그인을 확인해주세요.';
      }
      throw '설정 저장 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '설정 저장 중 오류가 발생했습니다: $e';
    }
  }

  /// 안전귀가 설정 읽기
  /// [uid] 사용자 UID
  /// 설정이 없으면 null 반환
  Future<SafeHomeSettings?> getSafeHomeSettings(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('safe_home_settings')
          .doc(_settingsDocId)
          .get();

      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      if (data == null) return null;

      return SafeHomeSettings.fromJson(data);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다. 로그인을 확인해주세요.';
      }
      throw '설정 조회 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '설정 조회 중 오류가 발생했습니다: $e';
    }
  }

  /// 안전귀가 설정 실시간 감지
  /// [uid] 사용자 UID
  /// 설정이 변경될 때마다 Stream으로 전달
  Stream<SafeHomeSettings?> watchSafeHomeSettings(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('safe_home_settings')
        .doc(_settingsDocId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return null;
          }

          try {
            final data = snapshot.data();
            if (data == null) return null;

            return SafeHomeSettings.fromJson(data);
          } catch (e) {
            return null;
          }
        });
  }

  /// 안전귀가 설정 일부만 업데이트
  /// [uid] 사용자 UID
  /// [updates] 업데이트할 필드 맵
  Future<void> updateSafeHomeSettings(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      // updated_at 타임스탬프 자동 추가 (서버 시간 사용)
      updates['updated_at'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('safe_home_settings')
          .doc(_settingsDocId)
          .update(updates);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다. 로그인을 확인해주세요.';
      }
      throw '설정 업데이트 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '설정 업데이트 중 오류가 발생했습니다: $e';
    }
  }

  /// 안전귀가 설정 삭제
  /// [uid] 사용자 UID
  Future<void> deleteSafeHomeSettings(String uid) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('safe_home_settings')
          .doc(_settingsDocId)
          .delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다. 로그인을 확인해주세요.';
      }
      throw '설정 삭제 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '설정 삭제 중 오류가 발생했습니다: $e';
    }
  }
}
