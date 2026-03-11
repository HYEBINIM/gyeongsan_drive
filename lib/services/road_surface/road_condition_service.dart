import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../models/road_condition_model.dart';

/// 도로 상태 정보 Firestore 서비스
/// road_conditions 컬렉션에서 데이터를 조회
class RoadConditionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'eastapp-dev',
  );

  /// 모든 도로 상태 정보 조회
  /// 최신 데이터부터 정렬하여 반환
  Future<List<RoadConditionModel>> getAllRoadConditions() async {
    try {
      final snapshot = await _firestore
          .collection('road_conditions')
          .orderBy('collect_tm', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RoadConditionModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw '도로 상태 정보 조회 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '도로 상태 정보 조회 중 오류가 발생했습니다: $e';
    }
  }

  /// 특정 위치 근처의 도로 상태 정보 조회
  /// [latitude] 위도
  /// [longitude] 경도
  /// [radiusKm] 반경 (km)
  Future<List<RoadConditionModel>> getRoadConditionsNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      // 한국어 주석: Firestore의 GeoPoint 쿼리 제한으로 인해
      // 간단한 bounding box 방식으로 필터링
      // 1도 위도 ≈ 111km, 1도 경도 ≈ 88km (한국 위도 기준)
      final latDelta = radiusKm / 111.0;
      final lngDelta = radiusKm / 88.0;

      final snapshot = await _firestore
          .collection('road_conditions')
          .where('latitude', isGreaterThan: latitude - latDelta)
          .where('latitude', isLessThan: latitude + latDelta)
          .get();

      // longitude 필터는 클라이언트에서 추가 적용
      final conditions = snapshot.docs
          .map((doc) => RoadConditionModel.fromFirestore(doc))
          .where(
            (condition) =>
                condition.longitude >= longitude - lngDelta &&
                condition.longitude <= longitude + lngDelta,
          )
          .toList();

      // 수집 시간 기준 내림차순 정렬
      conditions.sort((a, b) => b.collectTime.compareTo(a.collectTime));

      return conditions;
    } on FirebaseException catch (e) {
      throw '주변 도로 상태 정보 조회 중 오류가 발생했습니다: ${e.message}';
    } catch (e) {
      throw '주변 도로 상태 정보 조회 중 오류가 발생했습니다: $e';
    }
  }

  /// 도로 상태 정보 실시간 스트림
  /// 데이터 변경 시 자동 업데이트
  Stream<List<RoadConditionModel>> watchRoadConditions() {
    return _firestore
        .collection('road_conditions')
        .orderBy('collect_tm', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RoadConditionModel.fromFirestore(doc))
              .toList(),
        );
  }
}
