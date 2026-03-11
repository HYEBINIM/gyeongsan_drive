import 'package:equatable/equatable.dart';
import '../location_model.dart';
import 'route_model.dart';
import 'route_type.dart';

/// 교통수단 열거형
enum TransportMode {
  car, // 자동차
  walk, // 도보
  bike, // 자전거
}

/// 길안내 상태
/// 실시간 Turn-by-Turn 네비게이션 상태 관리
class GuidanceState extends Equatable {
  /// 안내 활성화 여부
  final bool isActive;

  /// 현재 진행 중인 maneuver 인덱스
  final int currentManeuverIndex;

  /// 남은 총 거리 (km)
  final double remainingDistanceKm;

  /// 남은 예상 시간 (분)
  final int remainingMinutes;

  /// 현재 GPS 속도 (km/h)
  final double currentSpeedKmh;

  /// 경로 이탈 여부
  final bool isOffRoute;

  /// 재경로 계산 중 여부
  final bool isRecalculating;

  /// 지도가 현재 위치를 추적 중인지 여부 (사용자 드래그 시 false)
  final bool isFollowingLocation;

  const GuidanceState({
    required this.isActive,
    required this.currentManeuverIndex,
    required this.remainingDistanceKm,
    required this.remainingMinutes,
    required this.currentSpeedKmh,
    required this.isOffRoute,
    required this.isRecalculating,
    required this.isFollowingLocation,
  });

  const GuidanceState.initial()
    : isActive = false,
      currentManeuverIndex = 0,
      remainingDistanceKm = 0.0,
      remainingMinutes = 0,
      currentSpeedKmh = 0.0,
      isOffRoute = false,
      isRecalculating = false,
      isFollowingLocation = true;

  GuidanceState copyWith({
    bool? isActive,
    int? currentManeuverIndex,
    double? remainingDistanceKm,
    int? remainingMinutes,
    double? currentSpeedKmh,
    bool? isOffRoute,
    bool? isRecalculating,
    bool? isFollowingLocation,
  }) {
    return GuidanceState(
      isActive: isActive ?? this.isActive,
      currentManeuverIndex: currentManeuverIndex ?? this.currentManeuverIndex,
      remainingDistanceKm: remainingDistanceKm ?? this.remainingDistanceKm,
      remainingMinutes: remainingMinutes ?? this.remainingMinutes,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      isRecalculating: isRecalculating ?? this.isRecalculating,
      isFollowingLocation: isFollowingLocation ?? this.isFollowingLocation,
    );
  }

  @override
  List<Object?> get props => [
    isActive,
    currentManeuverIndex,
    remainingDistanceKm,
    remainingMinutes,
    currentSpeedKmh,
    isOffRoute,
    isRecalculating,
    isFollowingLocation,
  ];
}

/// 경로 옵션
class RouteOptions extends Equatable {
  final bool avoidTollRoads; // 무료도로 사용
  final bool avoidHighways; // 자동차전용도로 제외
  final bool childSafe; // 어린이안심

  const RouteOptions({
    this.avoidTollRoads = false,
    this.avoidHighways = false,
    this.childSafe = false,
  });

  const RouteOptions.initial()
    : avoidTollRoads = false,
      avoidHighways = false,
      childSafe = false;

  RouteOptions copyWith({
    bool? avoidTollRoads,
    bool? avoidHighways,
    bool? childSafe,
  }) {
    return RouteOptions(
      avoidTollRoads: avoidTollRoads ?? this.avoidTollRoads,
      avoidHighways: avoidHighways ?? this.avoidHighways,
      childSafe: childSafe ?? this.childSafe,
    );
  }

  @override
  List<Object?> get props => [avoidTollRoads, avoidHighways, childSafe];
}

/// 경로 상태
class RouteState extends Equatable {
  final Map<RouteType, RouteModel?> routes; // 경로 타입별 계산된 경로 맵
  final RouteType selectedRouteType; // 현재 선택된 경로 타입
  final bool isCalculating; // 경로 계산 중
  final String? errorMessage; // 에러 메시지

  const RouteState({
    required this.routes,
    required this.selectedRouteType,
    this.isCalculating = false,
    this.errorMessage,
  });

  const RouteState.initial()
    : routes = const {},
      selectedRouteType = RouteType.recommended,
      isCalculating = false,
      errorMessage = null;

  RouteState copyWith({
    Map<RouteType, RouteModel?>? routes,
    RouteType? selectedRouteType,
    bool? isCalculating,
    String? errorMessage,
  }) {
    return RouteState(
      routes: routes ?? this.routes,
      selectedRouteType: selectedRouteType ?? this.selectedRouteType,
      isCalculating: isCalculating ?? this.isCalculating,
      errorMessage: errorMessage,
    );
  }

  /// 현재 선택된 경로
  RouteModel? get selectedRoute => routes[selectedRouteType];

  @override
  List<Object?> get props => [
    routes,
    selectedRouteType,
    isCalculating,
    errorMessage,
  ];
}

/// 위치 상태 (출발지/도착지)
class LocationsState extends Equatable {
  final LocationInfo? start; // 출발지
  final LocationInfo? destination; // 도착지

  const LocationsState({this.start, this.destination});

  const LocationsState.initial() : start = null, destination = null;

  LocationsState copyWith({LocationInfo? start, LocationInfo? destination}) {
    return LocationsState(
      start: start ?? this.start,
      destination: destination ?? this.destination,
    );
  }

  @override
  List<Object?> get props => [start, destination];
}

/// 현재 위치 상태 (실시간 GPS 위치)
class CurrentLocationState extends Equatable {
  final LocationModel? currentLocation; // 현재 GPS 위치
  final bool isTracking; // 실시간 추적 중 여부

  const CurrentLocationState({
    required this.currentLocation,
    required this.isTracking,
  });

  const CurrentLocationState.initial()
    : currentLocation = null,
      isTracking = false;

  CurrentLocationState copyWith({
    LocationModel? currentLocation,
    bool? isTracking,
  }) {
    return CurrentLocationState(
      currentLocation: currentLocation ?? this.currentLocation,
      isTracking: isTracking ?? this.isTracking,
    );
  }

  @override
  List<Object?> get props => [currentLocation, isTracking];
}

/// 로딩 상태
class LoadingState extends Equatable {
  final bool isLoading; // 로딩 중 여부
  final bool isInitialized; // 초기화 완료 여부

  const LoadingState({required this.isLoading, required this.isInitialized});

  const LoadingState.initial() : isLoading = false, isInitialized = false;

  LoadingState copyWith({bool? isLoading, bool? isInitialized}) {
    return LoadingState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  @override
  List<Object?> get props => [isLoading, isInitialized];
}

/// 길안내 통합 상태 (RegionInfoState 패턴 참고)
class NavigationState extends Equatable {
  final LocationsState locations; // 출발지/도착지 상태
  final CurrentLocationState currentLocation; // 현재 위치 상태
  final TransportMode transportMode; // 교통수단
  final RouteOptions options; // 경로 옵션
  final RouteState route; // 경로 상태
  final LoadingState loading; // 로딩 상태
  final GuidanceState guidance; // 길안내 상태

  const NavigationState({
    required this.locations,
    required this.currentLocation,
    required this.transportMode,
    required this.options,
    required this.route,
    required this.loading,
    required this.guidance,
  });

  const NavigationState.initial()
    : locations = const LocationsState.initial(),
      currentLocation = const CurrentLocationState.initial(),
      transportMode = TransportMode.car,
      options = const RouteOptions.initial(),
      route = const RouteState.initial(),
      loading = const LoadingState.initial(),
      guidance = const GuidanceState.initial();

  NavigationState copyWith({
    LocationsState? locations,
    CurrentLocationState? currentLocation,
    TransportMode? transportMode,
    RouteOptions? options,
    RouteState? route,
    LoadingState? loading,
    GuidanceState? guidance,
  }) {
    return NavigationState(
      locations: locations ?? this.locations,
      currentLocation: currentLocation ?? this.currentLocation,
      transportMode: transportMode ?? this.transportMode,
      options: options ?? this.options,
      route: route ?? this.route,
      loading: loading ?? this.loading,
      guidance: guidance ?? this.guidance,
    );
  }

  /// 현재 위치가 있는지 여부
  bool get hasCurrentLocation => currentLocation.currentLocation != null;

  /// 출발지/도착지가 모두 설정되었는지 여부
  bool get hasRoute => locations.start != null && locations.destination != null;

  @override
  List<Object?> get props => [
    locations,
    currentLocation,
    transportMode,
    options,
    route,
    loading,
    guidance,
  ];
}

/// 지도 전용 간단한 상태 (ValueNotifier용)
/// 성능 최적화를 위해 지도 관련 상태만 별도 관리
class BasicMapState extends Equatable {
  final LocationModel? currentLocation;
  final LocationInfo? start;
  final LocationInfo? destination;
  final bool isTracking;
  final int revision; // 강제 업데이트용 리비전

  const BasicMapState({
    required this.currentLocation,
    required this.start,
    required this.destination,
    required this.isTracking,
    required this.revision,
  });

  @override
  List<Object?> get props => [
    currentLocation,
    start,
    destination,
    isTracking,
    revision,
  ];
}
