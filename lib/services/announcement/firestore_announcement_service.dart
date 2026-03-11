import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../models/announcement/announcement.dart';

/// Firestore 공지사항 서비스
/// 공지사항 조회 기능 제공 (읽기 전용)
class FirestoreAnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'eastapp-dev',
  );

  /// 공지사항 컬렉션 참조
  CollectionReference get _announcementsCollection =>
      _firestore.collection('announcements');

  /// 모든 공지사항 조회 (최신순)
  Stream<List<Announcement>> getAllAnnouncements() {
    return _announcementsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Announcement.fromFirestore(doc))
              .toList();
        });
  }

  /// 특정 공지사항 조회
  Future<Announcement?> getAnnouncementById(String id) async {
    try {
      final doc = await _announcementsCollection.doc(id).get();
      if (doc.exists) {
        return Announcement.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('공지사항 조회 실패: $e');
    }
  }

  /// 중요 공지사항만 조회
  Stream<List<Announcement>> getImportantAnnouncements() {
    return _announcementsCollection
        .where('isImportant', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Announcement.fromFirestore(doc))
              .toList();
        });
  }

  /// 카테고리별 공지사항 조회
  Stream<List<Announcement>> getAnnouncementsByCategory(String category) {
    return _announcementsCollection
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Announcement.fromFirestore(doc))
              .toList();
        });
  }

  /// 페이지네이션을 위한 제한된 수의 공지사항 조회
  Future<List<Announcement>> getAnnouncementsWithLimit(int limit) async {
    try {
      final snapshot = await _announcementsCollection
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Announcement.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('공지사항 조회 실패: $e');
    }
  }
}
