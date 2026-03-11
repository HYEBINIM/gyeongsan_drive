import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../models/user_model.dart';

/// Cloud Firestore 데이터베이스 서비스
/// 사용자 데이터 관리를 담당 (RTDB에서 마이그레이션됨)
class FirestoreDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'eastapp-dev',
  );

  /// 사용자 데이터 저장 또는 업데이트
  /// 신규 사용자 생성 시 또는 기존 사용자 정보 업데이트 시 사용
  /// 이메일 인덱스도 함께 저장
  Future<void> saveUserData(UserModel user) async {
    try {
      // 한국어 주석: 쓰기 2회를 배치 1회로 합쳐 네트워크 왕복 최소화
      final batch = _firestore.batch();

      final userRef = _firestore.collection('users').doc(user.uid);
      final emailRef = _firestore.collection('emailIndex').doc(user.email);

      // 사용자 문서와 이메일 인덱스를 함께 커밋
      batch.set(userRef, user.toJson());
      batch.set(emailRef, {
        'uid': user.uid,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다. 이메일 인증을 완료해주세요.';
      }
      throw '사용자 데이터 저장 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '사용자 데이터 저장 중 오류가 발생했습니다: $e';
    }
  }

  /// 사용자 데이터 읽기
  /// uid를 기반으로 사용자 데이터 조회
  Future<UserModel?> getUserData(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();

      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      if (data == null) return null;

      return UserModel.fromJson(data);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다. 이메일 인증을 완료해주세요.';
      }
      throw '사용자 데이터 조회 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '사용자 데이터 조회 중 오류가 발생했습니다: $e';
    }
  }

  /// 사용자 존재 여부 확인
  /// 신규 사용자인지 기존 사용자인지 판별
  Future<bool> userExists(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      return snapshot.exists;
    } on FirebaseException catch (e) {
      // permission-denied는 무시 (이메일 미인증 상태일 수 있음)
      if (e.code == 'permission-denied') {
        return false;
      }
      throw '사용자 확인 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '사용자 확인 중 오류가 발생했습니다: $e';
    }
  }

  /// 마지막 로그인 시간 업데이트
  /// 기존 사용자의 로그인 시간만 갱신
  Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': DateTime.now().toIso8601String(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다. 이메일 인증을 완료해주세요.';
      }
      throw '로그인 시간 업데이트 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '로그인 시간 업데이트 중 오류가 발생했습니다: $e';
    }
  }

  /// 사용자 displayName 업데이트
  /// 프로필 편집 시 사용
  Future<void> updateDisplayName(String uid, String newName) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'displayName': newName,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다.';
      }
      throw '이름 업데이트 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '이름 업데이트 중 오류가 발생했습니다: $e';
    }
  }

  /// 사용자 이메일 업데이트 (emailIndex도 함께 업데이트)
  /// 이메일 변경 시 사용 - 원자적 트랜잭션으로 처리
  Future<void> updateEmail(String uid, String oldEmail, String newEmail) async {
    try {
      // 배치를 사용하여 모든 작업을 원자적으로 처리
      final batch = _firestore.batch();

      // 1. users 문서의 email 필드 업데이트
      final userRef = _firestore.collection('users').doc(uid);
      batch.update(userRef, {'email': newEmail});

      // 2. 기존 이메일 인덱스 삭제
      final oldEmailRef = _firestore.collection('emailIndex').doc(oldEmail);
      batch.delete(oldEmailRef);

      // 3. 새 이메일 인덱스 생성
      final newEmailRef = _firestore.collection('emailIndex').doc(newEmail);
      batch.set(newEmailRef, {
        'uid': uid,
        'email': newEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 모든 작업 커밋
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다.';
      }
      throw '이메일 업데이트 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '이메일 업데이트 중 오류가 발생했습니다: $e';
    }
  }

  /// 사용자 데이터 실시간 감지
  /// 사용자 데이터 변경 시 자동으로 업데이트 (선택사항)
  Stream<UserModel?> watchUserData(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data();
      if (data == null) return null;

      return UserModel.fromJson(data);
    });
  }

  /// 사용자 데이터 삭제
  /// GDPR 준수를 위한 사용자 데이터 삭제 기능 (선택사항)
  /// 이메일 인덱스도 함께 삭제
  Future<void> deleteUserData(String uid, String email) async {
    try {
      // 사용자 데이터 삭제
      await _firestore.collection('users').doc(uid).delete();
      // 이메일 인덱스 삭제
      await deleteEmailMapping(email);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다.';
      }
      throw '사용자 데이터 삭제 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '사용자 데이터 삭제 중 오류가 발생했습니다: $e';
    }
  }

  /// 이름과 이메일로 사용자 검색 (아이디 찾기용)
  /// 입력한 이름과 이메일이 모두 일치하는 사용자를 찾음
  Future<UserModel?> findUserByNameAndEmail(String name, String email) async {
    try {
      // 이메일로 사용자 검색 (Firestore는 where 쿼리 사용)
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      // 검색 결과에서 이름이 일치하는 사용자 찾기
      for (final doc in snapshot.docs) {
        final userData = doc.data();
        final userModel = UserModel.fromJson(userData);

        // 이름과 이메일이 모두 일치하는지 확인
        if (userModel.displayName == name && userModel.email == email) {
          return userModel;
        }
      }

      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다.';
      }
      throw '사용자 검색 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '사용자 검색 중 오류가 발생했습니다: $e';
    }
  }

  /// 이메일로 UID 조회 (이메일 인덱스 사용)
  /// 회원가입 시 미완료 계정 확인용
  Future<String?> getUidByEmail(String email) async {
    try {
      // Firestore는 특수문자 인코딩 불필요
      final snapshot = await _firestore
          .collection('emailIndex')
          .doc(email)
          .get();

      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      return data?['uid'] as String?;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다.';
      }
      throw '이메일 조회 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '이메일 조회 중 오류가 발생했습니다: $e';
    }
  }

  /// 이메일 인덱스에 매핑 저장
  /// saveUserData와 함께 호출되어야 함
  Future<void> saveEmailMapping(String email, String uid) async {
    try {
      // Firestore는 특수문자 인코딩 불필요
      await _firestore.collection('emailIndex').doc(email).set({
        'uid': uid,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다. 이메일 인증을 완료해주세요.';
      }
      throw '이메일 매핑 저장 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '이메일 매핑 저장 중 오류가 발생했습니다: $e';
    }
  }

  /// 이메일 인덱스에서 매핑 삭제
  /// deleteUserData와 함께 호출되어야 함
  Future<void> deleteEmailMapping(String email) async {
    try {
      // Firestore는 특수문자 인코딩 불필요
      await _firestore.collection('emailIndex').doc(email).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다.';
      }
      throw '이메일 매핑 삭제 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '이메일 매핑 삭제 중 오류가 발생했습니다: $e';
    }
  }

  /// 사용자의 모든 Firestore 데이터 완전 삭제
  /// GDPR 준수를 위한 계정 삭제 시 사용
  /// 서브컬렉션(vehicles, safe_home_settings)과 관련 컬렉션(inquiries) 모두 삭제
  Future<void> deleteAllUserData(String uid, String email) async {
    try {
      final batch = _firestore.batch();

      // 1. vehicles 서브컬렉션의 모든 문서 삭제
      final vehiclesSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('vehicles')
          .get();

      for (final doc in vehiclesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 2. safe_home_settings 서브컬렉션 삭제
      final safeHomeRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('safe_home_settings')
          .doc('current');
      batch.delete(safeHomeRef);

      // 3. inquiries 컬렉션에서 사용자 문의 삭제
      final inquiriesSnapshot = await _firestore
          .collection('inquiries')
          .where('userId', isEqualTo: uid)
          .get();

      for (final doc in inquiriesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 4. emailIndex 삭제
      batch.delete(_firestore.collection('emailIndex').doc(email));

      // 5. users 메인 문서 삭제
      batch.delete(_firestore.collection('users').doc(uid));

      // 일괄 커밋 (원자적 작업)
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw '권한이 없습니다.';
      }
      throw '사용자 데이터 삭제 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '사용자 데이터 삭제 중 오류가 발생했습니다: $e';
    }
  }

  /// FCM 토큰 저장
  /// 사용자의 FCM 토큰을 Firestore에 저장하여 푸시 알림 전송에 사용
  /// [userId] 사용자 UID
  /// [token] FCM 토큰
  Future<void> saveUserFCMToken(String userId, String token) async {
    try {
      // 한국어 주석: set(merge: true)를 사용하여 문서가 없어도 생성되고, 있으면 병합
      // update()는 문서가 없으면 실패하므로 FCM 초기화 시점에 문서가 없을 수 있음
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // 에러 무시 (토큰 저장 실패해도 앱 동작에는 영향 없음)
      // ignore: avoid_print
      print('FCM 토큰 저장 실패: $e');
    }
  }
}
