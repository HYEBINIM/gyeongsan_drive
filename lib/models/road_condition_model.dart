import 'package:cloud_firestore/cloud_firestore.dart';

/// 도로 상태 정보 모델
/// Firestore road_conditions 컬렉션의 문서 구조를 매핑
class RoadConditionModel {
  /// Firestore 문서 ID
  final String id;

  /// 수집 시간
  final DateTime collectTime;

  /// 수집 디바이스 시리얼 번호
  final String collectDevSerial;

  /// 위험 유형 코드 (DB 원본값 보존, 의미 미정의)
  final int dangerTypeCode;

  /// 위도
  final double latitude;

  /// 경도
  final double longitude;

  /// 위험 감지 이미지 URL
  final String imageUrl;

  /// 문서 생성 시간
  final DateTime createdAt;

  const RoadConditionModel({
    required this.id,
    required this.collectTime,
    required this.collectDevSerial,
    required this.dangerTypeCode,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.createdAt,
  });

  /// Firestore 문서에서 모델 생성
  factory RoadConditionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // collect_tm 파싱 (Timestamp)
    final collectTm = data['collect_tm'] as Timestamp?;
    final collectTime = collectTm?.toDate() ?? DateTime.now();

    // created_at 파싱 (Timestamp)
    final createdAtTm = data['created_at'] as Timestamp?;
    final createdAt = createdAtTm?.toDate() ?? DateTime.now();

    // danger_obj_type 파싱 (int 원본값 보존)
    final dangerTypeCode = data['danger_obj_type'] as int? ?? 0;

    return RoadConditionModel(
      id: doc.id,
      collectTime: collectTime,
      collectDevSerial: data['collect_dev_serial'] as String? ?? '',
      dangerTypeCode: dangerTypeCode,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['url_path'] as String? ?? '',
      createdAt: createdAt,
    );
  }

  /// 수집 시간을 포맷팅된 문자열로 반환
  String get formattedCollectTime {
    return '${collectTime.year}.${collectTime.month.toString().padLeft(2, '0')}.${collectTime.day.toString().padLeft(2, '0')} '
        '${collectTime.hour.toString().padLeft(2, '0')}:${collectTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'RoadConditionModel(id: $id, dangerTypeCode: $dangerTypeCode, '
        'lat: $latitude, lng: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoadConditionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
