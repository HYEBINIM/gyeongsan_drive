import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import 'maneuver_model.dart';

/// 경로 정보 모델
class RouteModel extends Equatable {
  final List<LatLng> routePoints; // 경로 좌표 목록
  final double totalDistanceKm; // 총 거리 (km)
  final int estimatedMinutes; // 예상 소요 시간 (분)
  final int estimatedTaxiFare; // 예상 택시비 (원)
  final String routeType; // 경로 타입 (추천, 최단거리, 무료도로 등)
  final String? summary; // 경로 요약 정보 (예: "10.5km, 15분")
  final List<ManeuverModel>? maneuvers; // turn-by-turn 안내 정보

  const RouteModel({
    required this.routePoints,
    required this.totalDistanceKm,
    required this.estimatedMinutes,
    required this.estimatedTaxiFare,
    required this.routeType,
    this.summary,
    this.maneuvers,
  });

  /// 복사본 생성 (불변성 유지)
  RouteModel copyWith({
    List<LatLng>? routePoints,
    double? totalDistanceKm,
    int? estimatedMinutes,
    int? estimatedTaxiFare,
    String? routeType,
    String? summary,
    List<ManeuverModel>? maneuvers,
  }) {
    return RouteModel(
      routePoints: routePoints ?? this.routePoints,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      estimatedTaxiFare: estimatedTaxiFare ?? this.estimatedTaxiFare,
      routeType: routeType ?? this.routeType,
      summary: summary ?? this.summary,
      maneuvers: maneuvers ?? this.maneuvers,
    );
  }

  @override
  List<Object?> get props => [
    routePoints,
    totalDistanceKm,
    estimatedMinutes,
    estimatedTaxiFare,
    routeType,
    summary,
    maneuvers,
  ];
}

/// 위치 정보 모델 (출발지/도착지)
class LocationInfo {
  /// 현재 위치를 나타내는 플레이스홀더
  static const String currentLocationPlaceholder = '현재위치';

  final String address; // 주소
  final String placeName; // 장소명
  final LatLng coordinates; // 좌표

  const LocationInfo({
    required this.address,
    required this.placeName,
    required this.coordinates,
  });

  /// 표시용 이름 (현재 위치는 주소, 그 외는 장소명 우선)
  String get displayName {
    // 현재 위치인 경우 무조건 실제 주소 반환
    if (placeName == currentLocationPlaceholder) {
      return address;
    }
    // 일반 장소는 장소명 우선, 없으면 주소
    return placeName.isNotEmpty ? placeName : address;
  }

  LocationInfo copyWith({
    String? address,
    String? placeName,
    LatLng? coordinates,
  }) {
    return LocationInfo(
      address: address ?? this.address,
      placeName: placeName ?? this.placeName,
      coordinates: coordinates ?? this.coordinates,
    );
  }
}
