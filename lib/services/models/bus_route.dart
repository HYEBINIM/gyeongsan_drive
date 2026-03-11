// lib/models/bus_route.dart

class BusRoute {
  final int id;
  final String routeId;
  final String routeName;
  final String routeType;
  final String startStop;
  final String endStop;
  final String? companyName;
  final String cityName;
  
  BusRoute({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.routeType,
    required this.startStop,
    required this.endStop,
    this.companyName,
    required this.cityName,
  });
  
  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id'] as int? ?? 0,
      routeId: json['route_id'] as String? ?? '',
      routeName: json['route_name'] as String? ?? '',
      routeType: json['route_type'] as String? ?? '',
      startStop: json['start_stop'] as String? ?? '',
      endStop: json['end_stop'] as String? ?? '',
      companyName: json['company_name'] as String?,
      cityName: json['city_name'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_id': routeId,
      'route_name': routeName,
      'route_type': routeType,
      'start_stop': startStop,
      'end_stop': endStop,
      'company_name': companyName,
      'city_name': cityName,
    };
  }
  
  String getRouteTypeText() {
    switch (routeType) {
      case '1':
        return '시내버스';
      case '2':
        return '좌석버스';
      case '3':
        return '마을버스';
      case '4':
        return '직행좌석';
      case '5':
        return '공항버스';
      case '6':
        return '간선급행';
      default:
        return '일반버스';
    }
  }
  
  int getRouteTypeColor() {
    switch (routeType) {
      case '1':
        return 0xFF4CAF50; // 녹색
      case '2':
        return 0xFFFF5722; // 주황색
      case '3':
        return 0xFF2196F3; // 파란색
      case '4':
        return 0xFFF44336; // 빨간색
      case '5':
        return 0xFF9C27B0; // 보라색
      case '6':
        return 0xFFFF9800; // 주황색
      default:
        return 0xFF757575; // 회색
    }
  }
}

class BusRouteStop {
  final int sequence;
  final String stopName;
  final double lat;
  final double lon;
  
  BusRouteStop({
    required this.sequence,
    required this.stopName,
    required this.lat,
    required this.lon,
  });
  
  factory BusRouteStop.fromJson(Map<String, dynamic> json) {
    return BusRouteStop(
      sequence: json['sequence'] as int? ?? 0,
      stopName: json['stop_name'] as String? ?? '',
      lat: _parseDouble(json['lat']),
      lon: _parseDouble(json['lon']),
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
      'sequence': sequence,
      'stop_name': stopName,
      'lat': lat,
      'lon': lon,
    };
  }
}