// lib/models/bus_route.dart

class BusRoute {
  final String routeId;
  final String routeName;
  final String? routeType;
  final String? startStop;
  final String? endStop;
  final String? firstBusTime;
  final String? lastBusTime;
  final String? intervalWeekday;
  final String? intervalSaturday;
  final String? intervalSunday;
  final String? companyName;
  final String? cityName;

  // ⭐ 방향 정보 추가
  final String? currentStopOrder;  // 현재 정류장 순서
  final String? directionCode;     // 방향 코드 (0=상행, 1=하행)
  final String? directionText;     // 방향 텍스트 (예: "경북대병원 방면")

  BusRoute({
    required this.routeId,
    required this.routeName,
    this.routeType,
    this.startStop,
    this.endStop,
    this.firstBusTime,
    this.lastBusTime,
    this.intervalWeekday,
    this.intervalSaturday,
    this.intervalSunday,
    this.companyName,
    this.cityName,
    this.currentStopOrder,
    this.directionCode,
    this.directionText,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      routeId: json['route_id'] as String? ?? '',
      routeName: json['route_name'] as String? ?? '',
      routeType: json['route_type'] as String?,
      startStop: json['start_stop'] as String?,
      endStop: json['end_stop'] as String?,
      firstBusTime: json['first_bus_time'] as String?,
      lastBusTime: json['last_bus_time'] as String?,
      intervalWeekday: json['interval_weekday'] as String?,
      intervalSaturday: json['interval_saturday'] as String?,
      intervalSunday: json['interval_sunday'] as String?,
      companyName: json['company_name'] as String?,
      cityName: json['city_name'] as String?,
      currentStopOrder: json['current_stop_order']?.toString(),
      directionCode: json['direction_code'] as String?,
      directionText: json['direction_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'route_name': routeName,
      'route_type': routeType,
      'start_stop': startStop,
      'end_stop': endStop,
      'first_bus_time': firstBusTime,
      'last_bus_time': lastBusTime,
      'interval_weekday': intervalWeekday,
      'interval_saturday': intervalSaturday,
      'interval_sunday': intervalSunday,
      'company_name': companyName,
      'city_name': cityName,
      'current_stop_order': currentStopOrder,
      'direction_code': directionCode,
      'direction_text': directionText,
    };
  }

  // ⭐ 노선 타입별 색상 (기존 유지)
  String getRouteTypeText() {
    switch (routeType) {
      case '1': return '공항';
      case '2': return '마을';
      case '3': return '간선';
      case '4': return '지선';
      case '5': return '순환';
      case '6': return '광역';
      case '7': return '인천';
      case '8': return '경기';
      case '9': return '폐지';
      default: return '일반';
    }
  }

  // ⭐ 방향 정보 포함된 표시명
  String getDisplayName() {
    if (directionText != null && directionText!.isNotEmpty) {
      return '$routeName ($directionText)';
    }
    return routeName;
  }

  // ⭐ 방향 아이콘
  String getDirectionIcon() {
    if (directionCode == '0') {
      return '↑'; // 상행
    } else if (directionCode == '1') {
      return '↓'; // 하행
    }
    return '↔'; // 방향 불명
  }
}

// ⭐ BusRouteStop은 기존 유지
class BusRouteStop {
  final String stopId;
  final String stopName;
  final String? stopCode;
  final int sequence;
  final double? lat;
  final double? lon;
  final String? direction;

  BusRouteStop({
    required this.stopId,
    required this.stopName,
    this.stopCode,
    required this.sequence,
    this.lat,
    this.lon,
    this.direction,
  });

  factory BusRouteStop.fromJson(Map<String, dynamic> json) {
    return BusRouteStop(
      stopId: json['stop_id'] as String? ?? '',
      stopName: json['stop_name'] as String? ?? '',
      stopCode: json['stop_code'] as String?,
      sequence: json['sequence'] as int? ?? 0,
      lat: json['lat'] as double?,
      lon: json['lon'] as double?,
      direction: json['direction'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stop_id': stopId,
      'stop_name': stopName,
      'stop_code': stopCode,
      'sequence': sequence,
      'lat': lat,
      'lon': lon,
      'direction': direction,
    };
  }
}

// ⭐ 버스 노선의 실제 운행 경로 데이터
class BusRoutePath {
  final String routeId;
  final List<RouteCoordinate> coordinates;

  BusRoutePath({
    required this.routeId,
    required this.coordinates,
  });

  factory BusRoutePath.fromJson(Map<String, dynamic> json) {
    final coordsList = json['coordinates'] as List? ?? [];
    final coordinates = coordsList
        .map((coord) => RouteCoordinate.fromJson(coord as Map<String, dynamic>))
        .toList();

    return BusRoutePath(
      routeId: json['route_id'] as String? ?? '',
      coordinates: coordinates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'coordinates': coordinates.map((c) => c.toJson()).toList(),
    };
  }
}

// ⭐ 경로 좌표
class RouteCoordinate {
  final double lat;
  final double lon;

  RouteCoordinate({
    required this.lat,
    required this.lon,
  });

  factory RouteCoordinate.fromJson(Map<String, dynamic> json) {
    return RouteCoordinate(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
    };
  }
}