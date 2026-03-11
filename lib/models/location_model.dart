import 'package:latlong2/latlong.dart';

/// 위치 정보 데이터 모델
class LocationModel {
  /// 위도
  final double latitude;

  /// 경도
  final double longitude;

  /// 정확도 (미터)
  final double? accuracy;

  /// 고도 (미터)
  final double? altitude;

  /// 방향 (0-360도, 북쪽이 0도)
  final double? heading;

  /// 속도 (m/s)
  final double? speed;

  /// 타임스탬프
  final DateTime timestamp;

  const LocationModel({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.heading,
    this.speed,
    required this.timestamp,
  });

  /// LatLng 좌표로 변환
  LatLng get coordinates => LatLng(latitude, longitude);

  /// Geolocator Position 객체로부터 LocationModel 생성
  factory LocationModel.fromPosition(dynamic position) {
    return LocationModel(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      heading: position.heading,
      speed: position.speed,
      timestamp: position.timestamp ?? DateTime.now(),
    );
  }

  /// 복사본 생성
  LocationModel copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? heading,
    double? speed,
    DateTime? timestamp,
  }) {
    return LocationModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'LocationModel(lat: $latitude, lng: $longitude, accuracy: $accuracy)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocationModel &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.accuracy == accuracy &&
        other.altitude == altitude &&
        other.heading == heading &&
        other.speed == speed;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^
        longitude.hashCode ^
        accuracy.hashCode ^
        altitude.hashCode ^
        heading.hashCode ^
        speed.hashCode;
  }
}
