import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../models/inquiry/inquiry.dart';

/// Firestore 문의 서비스
/// 사용자 문의 작성, 조회, 삭제 기능 제공
class FirestoreInquiryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'eastapp-dev',
  );

  /// 문의 컬렉션 참조
  CollectionReference get _inquiriesCollection =>
      _firestore.collection('inquiries');

  /// 사용자의 모든 문의 조회 (최신순)
  Stream<List<Inquiry>> getUserInquiries(String userId) {
    return _inquiriesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Inquiry.fromFirestore(doc))
              .toList();
        });
  }

  /// 특정 문의 조회
  Future<Inquiry?> getInquiryById(String id) async {
    try {
      final doc = await _inquiriesCollection.doc(id).get();
      if (doc.exists) {
        return Inquiry.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('문의 조회 실패: $e');
    }
  }

  /// 문의 작성
  Future<String> createInquiry(Inquiry inquiry) async {
    try {
      final docRef = await _inquiriesCollection.add(inquiry.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('문의 작성 실패: $e');
    }
  }

  /// 문의 삭제 (답변 전에만 삭제 가능)
  Future<void> deleteInquiry(String id) async {
    try {
      // 먼저 문의를 조회해서 답변 여부 확인
      final inquiry = await getInquiryById(id);
      if (inquiry == null) {
        throw Exception('문의를 찾을 수 없습니다');
      }

      // 답변이 완료된 문의는 삭제 불가
      if (inquiry.status == InquiryStatus.answered) {
        throw Exception('답변이 완료된 문의는 삭제할 수 없습니다');
      }

      await _inquiriesCollection.doc(id).delete();
    } catch (e) {
      throw Exception('문의 삭제 실패: $e');
    }
  }

  /// 사용자의 답변 대기중인 문의 수 조회
  Future<int> getPendingInquiryCount(String userId) async {
    try {
      final snapshot = await _inquiriesCollection
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: InquiryStatus.pending.name)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      throw Exception('대기중인 문의 수 조회 실패: $e');
    }
  }

  /// 사용자의 답변 완료된 문의 수 조회
  Future<int> getAnsweredInquiryCount(String userId) async {
    try {
      final snapshot = await _inquiriesCollection
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: InquiryStatus.answered.name)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      throw Exception('답변 완료된 문의 수 조회 실패: $e');
    }
  }
}
