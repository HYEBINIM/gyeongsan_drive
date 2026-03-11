import 'package:latlong2/latlong.dart';
import '../../models/navigation/route_model.dart';
import '../../models/navigation/navigation_state.dart';
import '../../models/navigation/route_type.dart';
import 'valhalla_api_service.dart';

/// 길안내 서비스
/// 경로 계산 및 관련 비즈니스 로직 처리
class NavigationService {
  // Valhalla API 서비스 의존성 주입
  final ValhallaApiService _valhallaApi;

  NavigationService({required ValhallaApiService valhallaApi})
    : _valhallaApi = valhallaApi;

  /// 모든 경로 타입 순차 계산
  /// TransportMode별로 사용 가능한 경로 옵션을 순차적으로 계산하여 Map으로 반환
  /// Rate Limit 방지를 위해 각 요청 사이에 300ms 딜레이 추가
  ///
  /// [onEachRouteCalculated]: 각 경로 계산 완료 시 호출되는 콜백 (즉시 UI 업데이트용)
  Future<Map<RouteType, RouteModel?>> calculateAllRoutes({
    required LatLng start,
    required LatLng destination,
    required TransportMode mode,
    required RouteOptions options,
    void Function(RouteType type, RouteModel route)? onEachRouteCalculated,
  }) async {
    // TransportMode에 따라 사용 가능한 경로 타입만 계산
    // - car: 5가지 (추천, 최소시간, 거리우선, 큰길우선, 고속도로우선)
    // - walk: 3가지 (최단거리, 큰길우선, 편안한길)
    // - bike: 3가지 (추천, 최소시간, 거리우선)
    final availableRouteTypes = RouteTypeExtension.availableTypes(mode);
    final routeMap = <RouteType, RouteModel?>{};

    for (var i = 0; i < availableRouteTypes.length; i++) {
      final routeType = availableRouteTypes[i];

      try {
        // 경로 계산
        final route = await _calculateRouteByType(
          start: start,
          destination: destination,
          mode: mode,
          options: options,
          routeType: routeType,
        );

        routeMap[routeType] = route;

        // 각 경로 계산 완료 시 콜백 호출 (즉시 UI 업데이트)
        onEachRouteCalculated?.call(routeType, route);
      } catch (e) {
        routeMap[routeType] = null;
      }

      // 마지막 요청이 아니면 300ms 대기 (Rate Limit 방지)
      if (i < availableRouteTypes.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    return routeMap;
  }

  /// 경로 타입별 계산 (내부 메서드)
  Future<RouteModel> _calculateRouteByType({
    required LatLng start,
    required LatLng destination,
    required TransportMode mode,
    required RouteOptions options,
    required RouteType routeType,
  }) async {
    try {
      // Valhalla API 호출
      final costing = ValhallaApiService.getCostingMode(mode);
      final costingOptions = ValhallaApiService.getCostingOptions(
        routeType,
        options,
        mode, // TransportMode 전달 (pedestrian일 때 별도 로직 적용)
      );

      final route = await _valhallaApi.getRoute(
        start: start,
        destination: destination,
        costing: costing,
        routeType: routeType,
        costingOptions: costingOptions,
      );

      return route;
    } catch (e) {
      // API 실패 시 fallback: mock 데이터 생성
      return _generateMockRoute(start, destination, mode, routeType);
    }
  }

  /// 단일 경로 타입 계산 (공개 메서드)
  ///
  /// 한국어 주석: 안전귀가 등 특정 시나리오에서 "거리우선" 등 단일 타입만 요청할 때 사용
  Future<RouteModel> calculateRouteByType({
    required LatLng start,
    required LatLng destination,
    required TransportMode mode,
    required RouteOptions options,
    required RouteType routeType,
  }) async {
    return _calculateRouteByType(
      start: start,
      destination: destination,
      mode: mode,
      options: options,
      routeType: routeType,
    );
  }

  /// Mock 경로 생성 (API 실패 시 fallback)
  RouteModel _generateMockRoute(
    LatLng start,
    LatLng destination,
    TransportMode mode,
    RouteType routeType,
  ) {
    // 간단한 직선 경로 생성
    final routePoints = _generateMockRoutePoints(start, destination);

    // 기본 거리 계산 (Haversine 공식 사용)
    final baseDistance =
        const Distance().distance(start, destination) / 1000; // km

    // 경로 타입별 거리 및 시간 조정
    double distance;
    int estimatedMinutes;

    switch (routeType) {
      case RouteType.recommended:
        // 추천경로: 균형잡힌 경로 (기본값)
        distance = baseDistance;
        estimatedMinutes = _calculateTime(distance, mode, speedMultiplier: 1.0);
        break;

      case RouteType.fastest:
        // 최소시간: 거리는 조금 길지만 시간이 짧음
        distance = baseDistance * 1.05;
        estimatedMinutes = _calculateTime(distance, mode, speedMultiplier: 1.3);
        break;

      case RouteType.shortest:
        // 거리우선: 거리가 가장 짧지만 시간은 조금 더 걸림
        distance = baseDistance * 0.95;
        estimatedMinutes = _calculateTime(distance, mode, speedMultiplier: 0.9);
        break;

      case RouteType.mainRoad:
        // 큰길우선: 큰 도로 위주로 가서 거리와 시간 모두 보통
        distance = baseDistance * 1.1;
        estimatedMinutes = _calculateTime(
          distance,
          mode,
          speedMultiplier: 1.15,
        );
        break;

      case RouteType.highway:
        // 고속도로우선: 거리는 길지만 속도가 빨라서 시간 짧음
        distance = baseDistance * 1.2;
        estimatedMinutes = _calculateTime(distance, mode, speedMultiplier: 1.5);
        break;
    }

    // 예상 택시비 계산 (기본요금 4,800원 + km당 1,000원)
    final taxiFare = mode == TransportMode.car
        ? (4800 + (distance * 1000)).round()
        : 0;

    return RouteModel(
      routePoints: routePoints,
      totalDistanceKm: distance,
      estimatedMinutes: estimatedMinutes,
      estimatedTaxiFare: taxiFare,
      routeType: routeType.label,
      summary: '${distance.toStringAsFixed(1)}km, $estimatedMinutes분 (Mock)',
    );
  }

  /// 시간 계산 헬퍼 메서드
  int _calculateTime(
    double distance,
    TransportMode mode, {
    required double speedMultiplier,
  }) {
    double baseSpeed;
    switch (mode) {
      case TransportMode.car:
        baseSpeed = 40.0; // 기본 40km/h
        break;
      case TransportMode.walk:
        baseSpeed = 4.0; // 도보 4km/h
        break;
      case TransportMode.bike:
        baseSpeed = 15.0; // 자전거 15km/h
        break;
    }

    final adjustedSpeed = baseSpeed * speedMultiplier;
    return ((distance / adjustedSpeed) * 60).round();
  }

  /// 경로 계산
  /// 현재는 mock 데이터 반환, 추후 실제 API 연동 가능
  Future<RouteModel> calculateRoute({
    required LatLng start,
    required LatLng destination,
    required TransportMode mode,
    required RouteOptions options,
  }) async {
    // API 호출 시뮬레이션
    await Future.delayed(const Duration(milliseconds: 800));

    // 간단한 직선 경로 생성 (mock)
    final routePoints = _generateMockRoutePoints(start, destination);

    // 거리 계산 (Haversine 공식 사용)
    final distance = const Distance().distance(start, destination) / 1000; // km

    // 예상 시간 계산 (자동차: 40km/h 평균 속도 가정)
    int estimatedMinutes;
    switch (mode) {
      case TransportMode.car:
        // 자동차: 평균 40km/h 가정
        estimatedMinutes = ((distance / 40) * 60).round();
        break;
      case TransportMode.walk:
        // 도보: 평균 4km/h 가정
        estimatedMinutes = ((distance / 4) * 60).round();
        break;
      case TransportMode.bike:
        // 자전거: 평균 15km/h 가정
        estimatedMinutes = ((distance / 15) * 60).round();
        break;
    }

    // 예상 택시비 계산 (기본요금 4,800원 + km당 1,000원)
    final taxiFare = mode == TransportMode.car
        ? (4800 + (distance * 1000)).round()
        : 0;

    return RouteModel(
      routePoints: routePoints,
      totalDistanceKm: distance,
      estimatedMinutes: estimatedMinutes,
      estimatedTaxiFare: taxiFare,
      routeType: '추천경로',
      summary: '${distance.toStringAsFixed(1)}km, $estimatedMinutes분',
    );
  }

  /// Mock 경로 포인트 생성 (시작점 -> 중간점 -> 도착점)
  List<LatLng> _generateMockRoutePoints(LatLng start, LatLng destination) {
    final points = <LatLng>[];

    // 시작점
    points.add(start);

    // 중간 지점 생성 (직선 경로를 3등분)
    for (var i = 1; i < 3; i++) {
      final ratio = i / 3;
      final lat =
          start.latitude + (destination.latitude - start.latitude) * ratio;
      final lng =
          start.longitude + (destination.longitude - start.longitude) * ratio;
      points.add(LatLng(lat, lng));
    }

    // 도착점
    points.add(destination);

    return points;
  }
}
