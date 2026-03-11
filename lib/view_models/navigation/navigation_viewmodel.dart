import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/location_model.dart';
import '../../models/navigation/navigation_state.dart';
import '../../models/navigation/route_model.dart';
import '../../models/navigation/route_type.dart';
import '../../models/navigation/maneuver_model.dart';
import '../../services/geocoding/geocoding_service.dart';
import '../../services/location/location_service.dart';
import '../../services/navigation/navigation_service.dart';
import '../../services/navigation/guidance_service.dart';

/// 길안내 ViewModel
/// RegionInfoViewModel 패턴 참고: 통합 상태 객체 + Equatable
class NavigationViewModel extends ChangeNotifier {
  // 서비스 의존성 주입
  final NavigationService _navigationService;
  final LocationService _locationService;
  final GeocodingService _geocodingService;
  final GuidanceService _guidanceService;

  // 통합 상태 관리
  NavigationState _state = const NavigationState.initial();

  // 위치 추적 스트림 구독
  StreamSubscription<LocationModel>? _locationSubscription;

  // 재경로 탐색 타이머
  Timer? _recalculationTimer;

  // 지도 전용 ValueNotifier (성능 최적화)
  final ValueNotifier<BasicMapState> _mapStateNotifier = ValueNotifier(
    const BasicMapState(
      currentLocation: null,
      start: null,
      destination: null,
      isTracking: false,
      revision: 0,
    ),
  );

  // 생성자
  NavigationViewModel({
    required NavigationService navigationService,
    required LocationService locationService,
    required GeocodingService geocodingService,
    required GuidanceService guidanceService,
  }) : _navigationService = navigationService,
       _locationService = locationService,
       _geocodingService = geocodingService,
       _guidanceService = guidanceService;

  // ==================== Getters ====================

  /// 전체 상태
  NavigationState get state => _state;

  /// 출발지/도착지 상태
  LocationsState get locations => _state.locations;

  /// 현재 위치 상태
  CurrentLocationState get currentLocationState => _state.currentLocation;

  /// 현재 위치
  LocationModel? get currentLocation => _state.currentLocation.currentLocation;

  /// 실시간 추적 중 여부
  bool get isTracking => _state.currentLocation.isTracking;

  /// 현재 위치가 있는지 여부
  bool get hasCurrentLocation => _state.hasCurrentLocation;

  /// 로딩 상태
  LoadingState get loading => _state.loading;

  /// 로딩 중 여부
  bool get isLoading => _state.loading.isLoading;

  /// 초기화 완료 여부
  bool get isInitialized => _state.loading.isInitialized;

  /// 교통수단
  TransportMode get transportMode => _state.transportMode;

  /// 경로 옵션
  RouteOptions get options => _state.options;

  /// 경로 상태
  RouteState get routeState => _state.route;

  /// 모든 경로 (경로 타입별 Map)
  Map<RouteType, RouteModel?> get routes => _state.route.routes;

  /// 선택된 경로 타입
  RouteType get selectedRouteType => _state.route.selectedRouteType;

  /// 현재 선택된 경로 정보
  RouteModel? get selectedRoute => _state.route.selectedRoute;

  /// 경로 계산 중 여부
  bool get isCalculating => _state.route.isCalculating;

  /// 에러 메시지
  String? get errorMessage => _state.route.errorMessage;

  /// 지도 전용 ValueNotifier
  ValueNotifier<BasicMapState> get mapStateNotifier => _mapStateNotifier;

  // ==================== Guidance 관련 Getters ====================

  /// 길안내 상태
  GuidanceState get guidance => _state.guidance;

  /// 길안내 활성화 여부
  bool get isGuidanceActive => _state.guidance.isActive;

  /// 지도 추적 모드 여부 (사용자 드래그 시 false)
  bool get isFollowingLocation => _state.guidance.isFollowingLocation;

  /// 현재 maneuver
  ManeuverModel? get currentManeuver {
    final route = _state.route.selectedRoute;
    if (route == null || route.maneuvers == null) return null;

    final index = _state.guidance.currentManeuverIndex;
    if (index >= route.maneuvers!.length) return null;

    return route.maneuvers![index];
  }

  /// 다음 maneuver (다다음 안내)
  ManeuverModel? get nextManeuver {
    final route = _state.route.selectedRoute;
    if (route == null || route.maneuvers == null) return null;

    final nextIndex = _state.guidance.currentManeuverIndex + 1;
    if (nextIndex >= route.maneuvers!.length) return null;

    return route.maneuvers![nextIndex];
  }

  /// 다음 안내 문구 생성
  String get nextInstructionText {
    final route = _state.route.selectedRoute;
    final currentLoc = _state.currentLocation.currentLocation;

    if (route == null || route.maneuvers == null || currentLoc == null) {
      return '';
    }

    final maneuver = currentManeuver;
    if (maneuver == null) return '목적지에 도착했습니다';

    final distance = _guidanceService.calculateDistanceToNextManeuver(
      currentLocation: currentLoc.coordinates,
      nextManeuver: maneuver,
    );

    return _guidanceService.getNextInstruction(
      currentManeuverIndex: _state.guidance.currentManeuverIndex,
      maneuvers: route.maneuvers!,
      distanceToNextManeuverMeters: distance,
    );
  }

  /// 현재 maneuver까지의 거리 (미터)
  double get distanceToCurrentManeuverMeters {
    final maneuver = currentManeuver;
    final currentLoc = _state.currentLocation.currentLocation;

    if (maneuver == null || currentLoc == null) return 0.0;

    return _guidanceService.calculateDistanceToNextManeuver(
      currentLocation: currentLoc.coordinates,
      nextManeuver: maneuver,
    );
  }

  /// 다음 maneuver까지의 거리 (미터)
  double? get distanceToNextManeuverMeters {
    final maneuver = nextManeuver;
    final currentLoc = _state.currentLocation.currentLocation;

    if (maneuver == null || currentLoc == null) return null;

    return _guidanceService.calculateDistanceToNextManeuver(
      currentLocation: currentLoc.coordinates,
      nextManeuver: maneuver,
    );
  }

  /// 순수 안내 문구 (도로명 기반, 네이버 지도 스타일)
  String get pureInstructionText {
    final maneuver = currentManeuver;
    if (maneuver == null) return '목적지에 도착했습니다';

    // 1순위: street_names 배열을 공백으로 join (예: "소공로 31")
    if (maneuver.streetNames != null && maneuver.streetNames!.isNotEmpty) {
      final streetText = maneuver.streetNames!.join(' ');
      return streetText;
    }

    // 2순위: 기존 instruction fallback
    return maneuver.instruction;
  }

  // ==================== 상태 업데이트 ====================

  /// 상태 업데이트 헬퍼 (copyWith 패턴)
  void _updateState(
    NavigationState Function(NavigationState) updater, {
    bool syncMap = true,
  }) {
    _state = updater(_state);
    if (syncMap) {
      _syncMapState();
    }
    notifyListeners();
  }

  /// 지도 상태 동기화 (ValueNotifier 업데이트)
  void _syncMapState({bool force = false}) {
    final nextState = BasicMapState(
      currentLocation: _state.currentLocation.currentLocation,
      start: _state.locations.start,
      destination: _state.locations.destination,
      isTracking: _state.currentLocation.isTracking,
      revision: force
          ? _mapStateNotifier.value.revision + 1
          : _mapStateNotifier.value.revision,
    );

    // Equatable 비교로 동일하면 알림 안 함
    if (!force && _mapStateNotifier.value == nextState) {
      return;
    }

    _mapStateNotifier.value = nextState;
  }

  // ==================== 비즈니스 로직 ====================

  /// 초기화 (출발지/도착지 설정)
  void initialize({
    required LocationInfo start,
    required LocationInfo destination,
  }) {
    _updateState(
      (state) => state.copyWith(
        locations: LocationsState(start: start, destination: destination),
      ),
    );

    // 자동으로 경로 계산 시작
    calculateRoute();
  }

  /// 출발지 설정
  void setStart(LocationInfo start) {
    _updateState(
      (state) =>
          state.copyWith(locations: state.locations.copyWith(start: start)),
    );

    // 출발지와 도착지가 모두 있으면 경로 재계산
    if (_state.locations.destination != null) {
      calculateRoute();
    }
  }

  /// 도착지 설정
  void setDestination(LocationInfo destination) {
    _updateState(
      (state) => state.copyWith(
        locations: state.locations.copyWith(destination: destination),
      ),
    );

    // 출발지와 도착지가 모두 있으면 경로 재계산
    if (_state.locations.start != null) {
      calculateRoute();
    }
  }

  /// 출발지/도착지 교환
  void swapLocations() {
    final currentStart = _state.locations.start;
    final currentDestination = _state.locations.destination;

    if (currentStart != null && currentDestination != null) {
      _updateState(
        (state) => state.copyWith(
          locations: LocationsState(
            start: currentDestination,
            destination: currentStart,
          ),
        ),
      );

      // 경로 재계산
      calculateRoute();
    }
  }

  /// 교통수단 변경
  void setTransportMode(TransportMode mode) {
    _updateState((state) => state.copyWith(transportMode: mode));

    // 경로 재계산
    if (_state.locations.start != null &&
        _state.locations.destination != null) {
      calculateRoute();
    }
  }

  /// 안전귀가 전용: 도보 + 거리우선(최단거리) 경로만 계산
  ///
  /// - 현재 위치를 출발지로 설정 (주소는 역지오코딩)
  /// - 도착지는 인자로 전달된 LocationInfo
  /// - TransportMode.walk 강제 적용
  /// - RouteType.shortest 하나만 계산하여 상태 갱신
  Future<RouteModel?> calculateShortestWalkingForSafeHome({
    required LocationInfo destination,
  }) async {
    try {
      // 교통수단 도보로 고정
      _updateState((s) => s.copyWith(transportMode: TransportMode.walk));

      // 현재 위치 확보 (없으면 초기화)
      if (_state.currentLocation.currentLocation == null) {
        await initializeLocation();
      }

      final currentLoc = _state.currentLocation.currentLocation;
      if (currentLoc == null) {
        return null;
      }

      // 역지오코딩으로 주소 조회
      final address = await _geocodingService.getAddressFromCoordinates(
        latitude: currentLoc.latitude,
        longitude: currentLoc.longitude,
      );

      // 출발지/도착지 상태 설정
      final start = LocationInfo(
        address: address,
        placeName: LocationInfo.currentLocationPlaceholder,
        coordinates: LatLng(currentLoc.latitude, currentLoc.longitude),
      );

      _updateState(
        (s) => s.copyWith(
          locations: LocationsState(start: start, destination: destination),
          route: s.route.copyWith(isCalculating: true, errorMessage: null),
        ),
      );

      // 단일 타입(최단거리)만 계산
      final route = await _navigationService.calculateRouteByType(
        start: start.coordinates,
        destination: destination.coordinates,
        mode: TransportMode.walk,
        options: _state.options,
        routeType: RouteType.shortest,
      );

      // 상태 갱신: 해당 타입만 보유
      _updateState(
        (s) => s.copyWith(
          route: s.route.copyWith(
            routes: {RouteType.shortest: route},
            selectedRouteType: RouteType.shortest,
            isCalculating: false,
            errorMessage: null,
          ),
        ),
      );

      return route;
    } catch (e) {
      _updateState(
        (s) => s.copyWith(
          route: s.route.copyWith(
            routes: const {},
            isCalculating: false,
            errorMessage: '경로 계산 실패: $e',
          ),
        ),
      );
      return null;
    }
  }

  /// 경로 옵션 변경
  void setRouteOptions(RouteOptions options) {
    _updateState((state) => state.copyWith(options: options));

    // 경로 재계산
    if (_state.locations.start != null &&
        _state.locations.destination != null) {
      calculateRoute();
    }
  }

  /// 무료도로 옵션 토글
  void toggleAvoidTollRoads() {
    final newOptions = _state.options.copyWith(
      avoidTollRoads: !_state.options.avoidTollRoads,
    );
    setRouteOptions(newOptions);
  }

  /// 자동차전용도로 제외 옵션 토글
  void toggleAvoidHighways() {
    final newOptions = _state.options.copyWith(
      avoidHighways: !_state.options.avoidHighways,
    );
    setRouteOptions(newOptions);
  }

  /// 어린이안심 옵션 토글
  void toggleChildSafe() {
    final newOptions = _state.options.copyWith(
      childSafe: !_state.options.childSafe,
    );
    setRouteOptions(newOptions);
  }

  /// 경로 계산 (각 경로 완료 시마다 즉시 UI 업데이트)
  Future<void> calculateRoute() async {
    final start = _state.locations.start;
    final destination = _state.locations.destination;

    // 출발지 또는 도착지가 없으면 중단
    if (start == null || destination == null) {
      return;
    }

    // 로딩 시작 + 기존 경로 초기화
    _updateState(
      (state) => state.copyWith(
        route: state.route.copyWith(
          isCalculating: true,
          errorMessage: null,
          routes: {}, // 기존 경로 초기화
        ),
      ),
    );

    try {
      // 각 경로가 완료되는 즉시 UI 업데이트
      await _navigationService.calculateAllRoutes(
        start: start.coordinates,
        destination: destination.coordinates,
        mode: _state.transportMode,
        options: _state.options,
        onEachRouteCalculated: (type, route) {
          // 각 경로가 완료되는 즉시 UI에 추가
          _updateState(
            (state) => state.copyWith(
              route: state.route.copyWith(
                routes: {...state.route.routes, type: route},
                // recommended가 완료되면 자동 선택
                selectedRouteType: type == RouteType.recommended
                    ? RouteType.recommended
                    : state.route.selectedRouteType,
              ),
            ),
          );
        },
      );

      // 모든 계산 완료
      _updateState(
        (state) =>
            state.copyWith(route: state.route.copyWith(isCalculating: false)),
      );
    } catch (e) {
      // 실패: 에러 메시지 설정
      _updateState(
        (state) => state.copyWith(
          route: state.route.copyWith(
            isCalculating: false,
            errorMessage: '경로를 찾을 수 없습니다',
          ),
        ),
      );
    }
  }

  /// 경로 타입 선택
  void selectRouteType(RouteType routeType) {
    _updateState(
      (state) => state.copyWith(
        route: state.route.copyWith(selectedRouteType: routeType),
      ),
    );
  }

  /// 안내 시작
  void startGuidance() {
    final selectedRoute = _state.route.selectedRoute;

    if (selectedRoute == null) {
      return;
    }

    if (selectedRoute.maneuvers == null || selectedRoute.maneuvers!.isEmpty) {
      return;
    }

    _updateState(
      (state) => state.copyWith(
        guidance: state.guidance.copyWith(
          isActive: true,
          currentManeuverIndex: 0,
          remainingDistanceKm: selectedRoute.totalDistanceKm,
          remainingMinutes: selectedRoute.estimatedMinutes,
          currentSpeedKmh: 0.0,
          isOffRoute: false,
          isRecalculating: false,
        ),
      ),
    );

    // 위치 추적이 없으면 시작
    if (!_state.currentLocation.isTracking) {
      startLocationTracking();
    }
  }

  /// 길안내 중지
  void stopGuidance() {
    _recalculationTimer?.cancel();
    _recalculationTimer = null;

    _updateState(
      (state) => state.copyWith(guidance: const GuidanceState.initial()),
    );
  }

  /// 지도 추적 모드 설정
  void setFollowingLocation(bool following) {
    _updateState(
      (state) => state.copyWith(
        guidance: state.guidance.copyWith(isFollowingLocation: following),
      ),
      syncMap: false,
    );
  }

  /// 현재 위치로 지도 이동 (추적 모드 재활성화)
  void centerMapOnCurrentLocation() {
    setFollowingLocation(true);
  }

  /// 길안내 중 위치 업데이트 처리
  void _handleGuidanceUpdate(LocationModel location) {
    final selectedRoute = _state.route.selectedRoute;
    if (selectedRoute == null || selectedRoute.maneuvers == null) return;

    // 1. 현재 속도 업데이트 (m/s -> km/h)
    final speedKmh = (location.speed ?? 0.0) * 3.6;

    // 2. 경로 이탈 감지
    final isOffRoute = _guidanceService.isOffRoute(
      currentLocation: location.coordinates,
      routePoints: selectedRoute.routePoints,
    );

    // 3. 현재 maneuver 인덱스 업데이트
    final newIndex = _guidanceService.findCurrentManeuverIndex(
      currentLocation: location.coordinates,
      maneuvers: selectedRoute.maneuvers!,
    );

    // 4. 남은 거리/시간 계산
    final remainingKm = _guidanceService.calculateRemainingDistance(
      currentLocation: location.coordinates,
      routePoints: selectedRoute.routePoints,
      currentManeuverIndex: newIndex,
      maneuvers: selectedRoute.maneuvers!,
    );

    // 평균 속도 기반 남은 시간 계산 (최소 5km/h)
    final avgSpeed = speedKmh > 5 ? speedKmh : 40.0;
    final remainingMin = (remainingKm / avgSpeed * 60).round();

    // 5. 상태 업데이트
    _updateState(
      (state) => state.copyWith(
        guidance: state.guidance.copyWith(
          currentManeuverIndex: newIndex,
          currentSpeedKmh: speedKmh,
          isOffRoute: isOffRoute,
          remainingDistanceKm: remainingKm,
          remainingMinutes: remainingMin,
        ),
      ),
      syncMap: false, // 지도 동기화 안 함 (성능)
    );

    // 6. 경로 이탈 시 자동 재경로 탐색
    if (isOffRoute && !_state.guidance.isRecalculating) {
      _scheduleRecalculation();
    }
  }

  /// 재경로 탐색 예약 (debounce 5초)
  void _scheduleRecalculation() {
    _recalculationTimer?.cancel();

    _updateState(
      (state) => state.copyWith(
        guidance: state.guidance.copyWith(isRecalculating: true),
      ),
      syncMap: false,
    );

    _recalculationTimer = Timer(const Duration(seconds: 5), () {
      _recalculateRoute();
    });
  }

  /// 재경로 탐색 실행
  Future<void> _recalculateRoute() async {
    final currentLoc = _state.currentLocation.currentLocation;
    final destination = _state.locations.destination;

    if (currentLoc == null || destination == null) {
      _updateState(
        (state) => state.copyWith(
          guidance: state.guidance.copyWith(isRecalculating: false),
        ),
        syncMap: false,
      );
      return;
    }

    try {
      // 현재 위치를 새 출발지로 설정
      final currentAddress = await _geocodingService.getAddressFromCoordinates(
        latitude: currentLoc.latitude,
        longitude: currentLoc.longitude,
      );

      _updateState(
        (state) => state.copyWith(
          locations: state.locations.copyWith(
            start: LocationInfo(
              address: currentAddress,
              placeName: LocationInfo.currentLocationPlaceholder,
              coordinates: currentLoc.coordinates,
            ),
          ),
        ),
      );

      // 경로 재계산
      await calculateRoute();

      _updateState(
        (state) => state.copyWith(
          guidance: state.guidance.copyWith(
            isRecalculating: false,
            isOffRoute: false,
            currentManeuverIndex: 0,
          ),
        ),
      );
    } catch (e) {
      _updateState(
        (state) => state.copyWith(
          guidance: state.guidance.copyWith(isRecalculating: false),
        ),
        syncMap: false,
      );
    }
  }

  // ==================== 위치 관련 기능 ====================

  /// 현재 위치 초기화
  Future<void> initializeLocation({bool force = false}) async {
    // 중복 초기화 방지
    if (_state.loading.isInitialized && !force) {
      return;
    }

    // 로딩 시작
    _updateState(
      (s) => s.copyWith(loading: s.loading.copyWith(isLoading: true)),
    );

    try {
      // 1. 마지막 위치 먼저 가져오기 (빠른 응답)
      final lastKnownLocation = await _locationService.getLastKnownLocation();
      if (lastKnownLocation != null) {
        _updateState(
          (s) => s.copyWith(
            currentLocation: s.currentLocation.copyWith(
              currentLocation: lastKnownLocation,
            ),
          ),
        );
      }

      // 2. 정확한 현재 위치 가져오기
      final location = await _locationService.getCurrentLocation();

      // 3. 초기화 완료
      _updateState(
        (s) => s.copyWith(
          currentLocation: s.currentLocation.copyWith(
            currentLocation: location,
          ),
          loading: s.loading.copyWith(isLoading: false, isInitialized: true),
        ),
      );

      // 4. 실시간 위치 추적 시작
      startLocationTracking();
    } catch (e) {
      _updateState(
        (s) => s.copyWith(
          loading: s.loading.copyWith(isLoading: false),
          route: s.route.copyWith(errorMessage: '위치 가져오기 실패: $e'),
        ),
      );
    }
  }

  /// GPS 기반 출발지 초기화 (주소 자동 로딩)
  ///
  /// 현재 위치를 출발지로 설정하고, 역지오코딩으로 주소를 가져옵니다.
  /// 2단계 업데이트: 1) 임시 주소 → 2) 실제 주소
  ///
  /// [destination] 도착지 정보 (필수)
  Future<void> initializeWithCurrentLocation({
    required LocationInfo destination,
  }) async {
    // 이미 초기화된 경우: 현재 위치는 유지(or 최신 위치 반영)하고 목적지만 갱신 후 경로 재계산
    // - 사용자 시나리오: 새로운 장소로 길찾기 재요청 시 이전 결과가 보이는 문제 해결
    if (_state.loading.isInitialized) {
      _updateState((s) {
        // 추적 중이면 최신 현재 위치 좌표를 출발지에 반영(가능 시)
        final current = s.currentLocation.currentLocation;
        final updatedStart = current != null
            ? LocationInfo(
                address:
                    s.locations.start?.address ??
                    LocationInfo.currentLocationPlaceholder,
                placeName: LocationInfo.currentLocationPlaceholder,
                coordinates: LatLng(current.latitude, current.longitude),
              )
            : s.locations.start;

        return s.copyWith(
          locations: s.locations.copyWith(
            start: updatedStart,
            destination: destination,
          ),
        );
      });

      // 목적지만 바뀌어도 경로 재계산
      calculateRoute();
      return;
    }

    // 로딩 시작
    _updateState(
      (s) => s.copyWith(loading: s.loading.copyWith(isLoading: true)),
    );

    try {
      // 1단계: 마지막 위치로 빠르게 초기화 (빠른 응답)
      final lastKnownLocation = await _locationService.getLastKnownLocation();
      if (lastKnownLocation != null) {
        _updateState(
          (s) => s.copyWith(
            currentLocation: s.currentLocation.copyWith(
              currentLocation: lastKnownLocation,
            ),
            locations: s.locations.copyWith(
              start: LocationInfo(
                address: '위치 확인 중...', // 임시 주소
                placeName: LocationInfo.currentLocationPlaceholder,
                coordinates: LatLng(
                  lastKnownLocation.latitude,
                  lastKnownLocation.longitude,
                ),
              ),
              destination: destination,
            ),
          ),
        );
      }

      // 2단계: 정확한 GPS 위치 + 주소 변환
      final location = await _locationService.getCurrentLocation();

      // 3단계: 역지오코딩 (비동기)
      final address = await _geocodingService.getAddressFromCoordinates(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      // 4단계: 최종 상태 업데이트
      _updateState(
        (s) => s.copyWith(
          currentLocation: s.currentLocation.copyWith(
            currentLocation: location,
          ),
          locations: s.locations.copyWith(
            start: LocationInfo(
              address: address, // 실제 주소
              placeName: LocationInfo.currentLocationPlaceholder,
              coordinates: LatLng(location.latitude, location.longitude),
            ),
            destination: destination,
          ),
          loading: s.loading.copyWith(isLoading: false, isInitialized: true),
        ),
      );

      // 5단계: 실시간 위치 추적 시작
      startLocationTracking();

      // 6단계: 경로 계산 시작
      calculateRoute();
    } catch (e) {
      _updateState(
        (s) => s.copyWith(
          loading: s.loading.copyWith(isLoading: false),
          route: s.route.copyWith(errorMessage: 'GPS 기반 초기화 실패: $e'),
        ),
      );
    }
  }

  /// 실시간 위치 추적 시작
  void startLocationTracking() {
    // 이미 추적 중이면 중단
    if (_state.currentLocation.isTracking) {
      return;
    }

    // 추적 시작
    _updateState(
      (s) => s.copyWith(
        currentLocation: s.currentLocation.copyWith(isTracking: true),
      ),
    );

    // 위치 스트림 구독
    _locationSubscription = _locationService.getLocationStream().listen(
      (location) {
        // 기본 위치 업데이트
        _updateState(
          (s) => s.copyWith(
            currentLocation: s.currentLocation.copyWith(
              currentLocation: location,
            ),
          ),
        );

        // 길안내 활성화 시 추가 로직
        if (_state.guidance.isActive) {
          _handleGuidanceUpdate(location);
        }
      },
      onError: (error) {
        // 에러 처리
      },
    );
  }

  /// 실시간 위치 추적 중지
  void stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;

    _updateState(
      (s) => s.copyWith(
        currentLocation: s.currentLocation.copyWith(isTracking: false),
      ),
    );
  }

  /// 네비게이션 상태 초기화 (화면 종료 시 호출)
  void resetNavigation() {
    // 1. 타이머 정리
    _recalculationTimer?.cancel();
    _recalculationTimer = null;

    // 2. 상태 완전 초기화
    _updateState(
      (state) => state.copyWith(
        locations: const LocationsState.initial(), // 출발지/도착지 삭제
        route: const RouteState.initial(), // 경로 삭제
        guidance: const GuidanceState.initial(), // 안내 중지
        transportMode: TransportMode.car, // 기본값으로 리셋
        loading: state.loading.copyWith(isInitialized: false), // 재초기화 필요
        // currentLocation은 유지 (GPS는 앱 전체에서 공유)
      ),
      syncMap: false, // 수동 동기화
    );

    // 3. 지도 상태 강제 동기화
    _syncMapState(force: true);
  }

  /// 리소스 정리
  @override
  void dispose() {
    _recalculationTimer?.cancel();
    stopLocationTracking();
    _mapStateNotifier.dispose();
    super.dispose();
  }
}
