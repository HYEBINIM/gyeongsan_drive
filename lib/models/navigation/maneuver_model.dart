import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Valhalla API의 maneuver 데이터 모델
/// 각 경로의 회전 지점 및 안내 정보를 포함
class ManeuverModel extends Equatable {
  /// Valhalla maneuver type (1-42)
  /// 예: 0=출발, 1=직진, 7=좌회전, 15=우회전, 6=유턴, 4=도착
  final int type;

  /// 안내 문구 (예: "북쪽 방면으로 출발하세요")
  final String instruction;

  /// 이 구간의 거리 (km)
  final double lengthKm;

  /// 이 구간의 예상 시간 (초)
  final int timeSeconds;

  /// 이 maneuver의 시작 좌표 (경로 이탈 감지에 사용)
  final LatLng? beginLocation;

  /// 도로명 목록 (예: ["소공로", "31"])
  final List<String>? streetNames;

  const ManeuverModel({
    required this.type,
    required this.instruction,
    required this.lengthKm,
    required this.timeSeconds,
    this.beginLocation,
    this.streetNames,
  });

  /// JSON에서 ManeuverModel 생성
  factory ManeuverModel.fromJson(Map<String, dynamic> json, LatLng? location) {
    return ManeuverModel(
      // Valhalla 숫자 필드는 double일 수 있으므로 num으로 안전 변환
      type: (json['type'] as num?)?.toInt() ?? 0,
      instruction: json['instruction'] as String? ?? '',
      lengthKm: (json['length'] as num?)?.toDouble() ?? 0.0,
      timeSeconds: (json['time'] as num?)?.toInt() ?? 0,
      beginLocation: location,
      streetNames: (json['street_names'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  /// copyWith 패턴으로 일부 필드만 변경한 새 인스턴스 생성
  ManeuverModel copyWith({
    int? type,
    String? instruction,
    double? lengthKm,
    int? timeSeconds,
    LatLng? beginLocation,
    List<String>? streetNames,
  }) {
    return ManeuverModel(
      type: type ?? this.type,
      instruction: instruction ?? this.instruction,
      lengthKm: lengthKm ?? this.lengthKm,
      timeSeconds: timeSeconds ?? this.timeSeconds,
      beginLocation: beginLocation ?? this.beginLocation,
      streetNames: streetNames ?? this.streetNames,
    );
  }

  @override
  List<Object?> get props => [
    type,
    instruction,
    lengthKm,
    timeSeconds,
    beginLocation,
    streetNames,
  ];
}
