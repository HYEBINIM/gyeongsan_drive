import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:equatable/equatable.dart';
import '../../models/navigation/navigation_state.dart';
import '../../models/navigation/route_model.dart';
import '../../models/navigation/route_type.dart';
import '../../view_models/navigation/navigation_viewmodel.dart';
import '../../services/permission/permission_service.dart';
import '../../widgets/navigation/location_input_card.dart';
import '../../widgets/navigation/route_info_bottom_card.dart';
import '../../routes/app_routes.dart';
import '../../utils/constants.dart';
import '../../utils/naver_map_utils.dart';
import '../../utils/snackbar_utils.dart';

/// 길안내 화면
/// 이미지와 동일한 디자인의 UI 구현
class NavigationScreen extends StatefulWidget {
  final LocationInfo? start; // 출발지 (null이면 현재 위치 사용)
  final LocationInfo destination; // 도착지 (필수)

  const NavigationScreen({super.key, this.start, required this.destination});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  // 네이버 지도 컨트롤러
  NaverMapController? _mapController;

  // 초기 지도 중심 (한 번만 설정)
  NLatLng? _initialCenter;

  // 경로 fit 중복 방지용 서명 캐시
  // 동일한 경로 경계(bounds)로 반복 호출되는 것을 방지
  String? _lastFitSignature;

  // 경로 fit 시 화면 여백(상단 패널/하단 카드 고려)
  static const EdgeInsets _fitPadding = EdgeInsets.fromLTRB(24, 120, 24, 260);

  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();

    // ViewModel 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 위치 권한 요청 (길안내 필수 기능)
      try {
        final granted = await PermissionService().requestLocationPermission();
        if (!granted && mounted) {
          SnackBarUtils.showWarning(
            context,
            '위치 권한이 필요합니다. 설정에서 위치 권한을 허용해주세요.',
          );
        }
      } catch (e) {
        // 위치 권한 요청 실패
      }

      if (!mounted) return;

      final viewModel = context.read<NavigationViewModel>();

      // 교통수단을 car로 명시적 설정
      viewModel.setTransportMode(TransportMode.car);

      // 선택된 경로 타입을 추천경로로 리셋
      viewModel.selectRouteType(RouteType.recommended);

      // 출발지 설정 방식 결정
      if (widget.start != null) {
        // 1) 사용자가 직접 지정한 출발지가 있는 경우
        // 현재 위치 초기화 (실시간 추적용)
        viewModel.initializeLocation();

        // 출발지/도착지 설정
        viewModel.initialize(
          start: widget.start!,
          destination: widget.destination,
        );
      } else {
        // 2) 출발지가 없는 경우: GPS 기반 출발지 + 주소 자동 로딩
        viewModel.initializeWithCurrentLocation(
          destination: widget.destination,
        );
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // 뒤로가기 시 네비게이션 상태 초기화
          context.read<NavigationViewModel>().resetNavigation();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // 배경: 네이버 지도
              Selector<NavigationViewModel, _MapState>(
                selector: (context, vm) => _MapState(
                  hasCurrentLocation: vm.hasCurrentLocation,
                  currentLocation: vm.currentLocation,
                  hasRoute: vm.state.hasRoute,
                ),
                builder: (context, mapState, _) {
                  // 현재 위치가 없으면 로딩 표시
                  if (!mapState.hasCurrentLocation) {
                    return _buildLoadingState();
                  }

                  // 초기 중심 설정 (한 번만)
                  _initialCenter ??= NLatLng(
                    mapState.currentLocation!.latitude,
                    mapState.currentLocation!.longitude,
                  );

                  return _buildPersistentMap(_initialCenter!);
                },
              ),

              // 경로 탐색 완료 시, 경로 전체가 보이도록 자동 줌/이동
              Selector<NavigationViewModel, _RouteFitState>(
                selector: (context, vm) => _RouteFitState(
                  isCalculating: vm.isCalculating,
                  selectedRoute: vm.routes[vm.selectedRouteType],
                ),
                builder: (context, state, _) {
                  _fitToSelectedRouteIfNeeded(context, state);
                  return const SizedBox.shrink();
                },
              ),

              // 지도 오버레이 동기화 (경로/마커/현재 위치)
              Selector<NavigationViewModel, _NavOverlayData>(
                selector: (context, vm) => _NavOverlayData(
                  routes: vm.routes,
                  selectedRouteType: vm.selectedRouteType,
                  start: vm.locations.start,
                  destination: vm.locations.destination,
                  currentLocation: vm.currentLocation,
                ),
                builder: (context, state, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _syncNavigationOverlays(state);
                  });
                  return const SizedBox.shrink();
                },
              ),

              // 상단: 파란 패널(교통수단 + 입력 카드 통합)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Selector<NavigationViewModel, _LocationPanelState>(
                  selector: (context, vm) => _LocationPanelState(
                    startAddress: vm.locations.start?.displayName ?? '',
                    destinationName:
                        vm.locations.destination?.displayName ?? '',
                    transportMode: vm.transportMode,
                  ),
                  builder: (context, state, _) {
                    return LocationInputCard(
                      startAddress: state.startAddress,
                      destinationName: state.destinationName,
                      selectedMode: state.transportMode,
                      onModeChanged: (newMode) => context
                          .read<NavigationViewModel>()
                          .setTransportMode(newMode),
                      onSwap: () =>
                          context.read<NavigationViewModel>().swapLocations(),
                      onClose: () {
                        // 네비게이션 상태 초기화 후 화면 닫기
                        context.read<NavigationViewModel>().resetNavigation();
                        Navigator.pop(context);
                      },
                      onMoreOptions: () {}, // 선택: 동작 미정(레이아웃 전용)
                    );
                  },
                ),
              ),

              // 하단: 경로 정보 카드
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Selector<NavigationViewModel, _RouteInfoState>(
                  selector: (context, vm) => _RouteInfoState(
                    routes: vm.routes,
                    selectedRouteType: vm.selectedRouteType,
                    transportMode: vm.transportMode,
                    isCalculating: vm.isCalculating,
                  ),
                  builder: (context, state, _) {
                    return RouteInfoBottomCard(
                      routes: state.routes,
                      selectedRouteType: state.selectedRouteType,
                      transportMode: state.transportMode,
                      isCalculating: state.isCalculating,
                      onRouteTypeSelected: (routeType) {
                        context.read<NavigationViewModel>().selectRouteType(
                          routeType,
                        );
                      },
                      onStartGuidance: () {
                        // 길안내 화면으로 이동
                        Navigator.pushNamed(context, AppRoutes.guidance);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 지도 빌더 메서드 ====================

  /// 경로가 준비되면 화면에 전체 루트가 들어오도록 카메라를 맞춤
  void _fitToSelectedRouteIfNeeded(BuildContext context, _RouteFitState state) {
    // 경로가 없으면 동작 안 함
    final route = state.selectedRoute;
    if (route == null || route.routePoints.length < 2) {
      return;
    }

    // 경계 계산용 포인트: 경로 포인트 + (선택) 출발/도착 좌표
    final points = <LatLng>[...route.routePoints];
    final navVm = context.read<NavigationViewModel>();
    final start = navVm.locations.start?.coordinates;
    final dest = navVm.locations.destination?.coordinates;
    if (start != null) points.add(start);
    if (dest != null) points.add(dest);
    if (points.isEmpty) return;

    final bounds = buildBoundsFromPoints(points);
    final sw = bounds.southWest;
    final ne = bounds.northEast;
    final signature =
        '${sw.latitude.toStringAsFixed(6)},${sw.longitude.toStringAsFixed(6)}|'
        '${ne.latitude.toStringAsFixed(6)},${ne.longitude.toStringAsFixed(6)}|'
        '${points.length}';

    if (_lastFitSignature == signature) return; // 중복 fit 방지

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_mapController == null) return;
      try {
        final cameraUpdate = NCameraUpdate.fitBounds(
          bounds,
          padding: _fitPadding,
        );
        cameraUpdate.setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 500),
        );
        await _mapController!.updateCamera(cameraUpdate);
        _lastFitSignature = signature;
      } catch (e) {
        // 경로 fit 실패
      }
    });
  }

  /// 지속적인 지도 프레임 (재생성 방지)
  Widget _buildPersistentMap(NLatLng center) {
    return Stack(
      children: [
        NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: center,
              zoom: AppConstants.mapDefaultZoom,
            ),
            indoorEnable: true,
            // 한국어 주석: locationButtonEnable 제거 (1.4.0 Breaking Change)
            contentPadding: EdgeInsets.zero,
          ),
          onMapReady: (controller) async {
            _mapController = controller;
            _isMapReady = true;
            // 한국어 주석: 진입 시 위치 추적 모드를 바로 활성화해 기본 GPS 버튼이 켜진 상태로 시작
            _mapController?.setLocationTrackingMode(
              NLocationTrackingMode.follow,
            );
            await _syncNavigationOverlays(_readCurrentOverlayData());
          },
          onCameraChange: (reason, animated) {
            // 사용자가 직접 드래그한 경우 추적 모드 비활성화
            if (reason == NCameraUpdateReason.gesture) {
              context.read<NavigationViewModel>().setFollowingLocation(false);
            }
          },
        ),

        // 한국어 주석: GPS 버튼 위젯 (1.4.0 신규 방식) - 좌측 하단
        if (_mapController != null)
          Positioned(
            left: 14,
            bottom: 44,
            child: NMyLocationButtonWidget(mapController: _mapController!),
          ),
      ],
    );
  }

  /// 로딩 상태 표시
  Widget _buildLoadingState() {
    return Container(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '현재 위치를 가져오는 중...',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 현재 뷰모델 스냅샷을 통해 지도 오버레이 동기화에 필요한 데이터를 수집
  _NavOverlayData _readCurrentOverlayData() {
    final vm = context.read<NavigationViewModel>();
    return _NavOverlayData(
      routes: vm.routes,
      selectedRouteType: vm.selectedRouteType,
      start: vm.locations.start,
      destination: vm.locations.destination,
      currentLocation: vm.currentLocation,
    );
  }

  /// 네이버 지도 오버레이를 현재 상태에 맞게 재구성
  Future<void> _syncNavigationOverlays(_NavOverlayData data) async {
    if (!_isMapReady || _mapController == null) return;

    await _mapController!.clearOverlays();
    final colorScheme = Theme.of(context).colorScheme;

    // 미선택 경로를 먼저 렌더링
    for (final entry in data.routes.entries) {
      final routeType = entry.key;
      final route = entry.value;
      if (route == null ||
          route.routePoints.isEmpty ||
          routeType == data.selectedRouteType)
        continue;

      final polyline = buildPolylineOverlay(
        'nav_route_${routeType.name}',
        points: route.routePoints,
        color: colorScheme.onSurface.withValues(alpha: 0.5),
        width: 5.0,
      );
      await _mapController!.addOverlay(polyline);
    }

    // 선택된 경로를 위에 렌더링
    final selectedRoute = data.routes[data.selectedRouteType];
    if (selectedRoute != null && selectedRoute.routePoints.isNotEmpty) {
      final polyline = buildPolylineOverlay(
        'nav_route_selected',
        points: selectedRoute.routePoints,
        color: colorScheme.primary,
        width: 5.0,
      );
      await _mapController!.addOverlay(polyline);
    }

    // 출발지/도착지 마커
    if (data.start != null) {
      final startMarker = await buildAssetMarkerOverlay(
        'nav_start',
        position: data.start!.coordinates,
        assetPath: 'assets/icons/ic_st.png',
      );
      await _mapController!.addOverlay(startMarker);
    }

    if (data.destination != null) {
      final destMarker = await buildAssetMarkerOverlay(
        'nav_destination',
        position: data.destination!.coordinates,
        assetPath: 'assets/icons/ic_ar.png',
      );
      await _mapController!.addOverlay(destMarker);
    }

    // 네이버 기본 현재 위치 오버레이 사용
    final locationOverlay = _mapController!.getLocationOverlay();
    if (data.currentLocation != null) {
      locationOverlay.setPosition(
        toNLatLng(
          LatLng(
            data.currentLocation!.latitude,
            data.currentLocation!.longitude,
          ),
        ),
      );
    }
  }
}

// ==================== Selector용 상태 클래스 ====================

/// 지도 상태 (Selector 최적화용)
class _MapState {
  final bool hasCurrentLocation;
  final dynamic currentLocation; // LocationModel?
  final bool hasRoute;

  _MapState({
    required this.hasCurrentLocation,
    required this.currentLocation,
    required this.hasRoute,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MapState &&
          runtimeType == other.runtimeType &&
          hasCurrentLocation == other.hasCurrentLocation &&
          currentLocation == other.currentLocation &&
          hasRoute == other.hasRoute;

  @override
  int get hashCode =>
      hasCurrentLocation.hashCode ^
      currentLocation.hashCode ^
      hasRoute.hashCode;
}

/// 상단 패널 상태 (Selector 최적화용)
class _LocationPanelState {
  final String startAddress;
  final String destinationName;
  final TransportMode transportMode;

  _LocationPanelState({
    required this.startAddress,
    required this.destinationName,
    required this.transportMode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LocationPanelState &&
          runtimeType == other.runtimeType &&
          startAddress == other.startAddress &&
          destinationName == other.destinationName &&
          transportMode == other.transportMode;

  @override
  int get hashCode =>
      startAddress.hashCode ^ destinationName.hashCode ^ transportMode.hashCode;
}

/// 경로 정보 상태 (Selector 최적화용)
class _RouteInfoState {
  final Map<RouteType, RouteModel?> routes;
  final RouteType selectedRouteType;
  final TransportMode transportMode;
  final bool isCalculating;

  _RouteInfoState({
    required this.routes,
    required this.selectedRouteType,
    required this.transportMode,
    required this.isCalculating,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RouteInfoState &&
          runtimeType == other.runtimeType &&
          routes == other.routes &&
          selectedRouteType == other.selectedRouteType &&
          transportMode == other.transportMode &&
          isCalculating == other.isCalculating;

  @override
  int get hashCode =>
      routes.hashCode ^
      selectedRouteType.hashCode ^
      transportMode.hashCode ^
      isCalculating.hashCode;
}

/// 경로 fit 트리거 상태 (Selector 최적화용)
class _RouteFitState {
  final bool isCalculating;
  final RouteModel? selectedRoute;

  _RouteFitState({required this.isCalculating, required this.selectedRoute});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RouteFitState &&
          runtimeType == other.runtimeType &&
          isCalculating == other.isCalculating &&
          selectedRoute == other.selectedRoute;

  @override
  int get hashCode => isCalculating.hashCode ^ selectedRoute.hashCode;
}

/// 지도 오버레이 상태 (경로/마커/현재 위치)
/// 한국어 주석: currentLocation은 props에서 제외하여 GPS 업데이트마다
/// 오버레이가 재생성되는 것을 방지합니다. 현재 위치는 네이버 기본
/// locationOverlay로 관리되므로 Selector 재실행이 불필요합니다.
class _NavOverlayData extends Equatable {
  final Map<RouteType, RouteModel?> routes;
  final RouteType selectedRouteType;
  final LocationInfo? start;
  final LocationInfo? destination;
  final dynamic currentLocation; // LocationModel? (props에서 제외됨)

  const _NavOverlayData({
    required this.routes,
    required this.selectedRouteType,
    required this.start,
    required this.destination,
    required this.currentLocation,
  });

  @override
  List<Object?> get props => [
    routes,
    selectedRouteType,
    start,
    destination,
    // currentLocation 제외: GPS 업데이트마다 오버레이 재생성 방지
  ];
}
