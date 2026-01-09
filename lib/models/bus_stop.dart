// lib/models/bus_stop.dart

class BusStop {
  final int id;
  final String stopCode;
  final String stopName;
  final double lat;
  final double lon;
  final String? mobileCode;
  final String cityName;
  
  // 추가 계산 필드
  final double? distanceKm;
  
  BusStop({
    required this.id,
    required this.stopCode,
    required this.stopName,
    required this.lat,
    required this.lon,
    this.mobileCode,
    required this.cityName,
    this.distanceKm,
  });
  
  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['id'] as int? ?? 0,
      stopCode: json['stop_code'] as String? ?? '',
      stopName: json['stop_name'] as String? ?? '',
      lat: _parseDouble(json['lat']),
      lon: _parseDouble(json['lon']),
      mobileCode: json['mobile_code'] as String?,
      cityName: json['city_name'] as String? ?? '',
      distanceKm: json['distance_km'] != null ? _parseDouble(json['distance_km']) : null,
    );
  }
  
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stop_code': stopCode,
      'stop_name': stopName,
      'lat': lat,
      'lon': lon,
      'mobile_code': mobileCode,
      'city_name': cityName,
      'distance_km': distanceKm,
    };
  }
  
  String getDistanceText() {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) {
      return '${(distanceKm! * 1000).toStringAsFixed(0)}m';
    } else {
      return '${distanceKm!.toStringAsFixed(1)}km';
    }
  }
}