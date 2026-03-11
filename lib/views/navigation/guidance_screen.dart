import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../view_models/navigation/navigation_viewmodel.dart';
import '../../models/navigation/maneuver_model.dart';
import '../../models/location_model.dart';
import '../../models/navigation/route_model.dart';
import '../../widgets/navigation/guidance_top_card.dart';
import '../../widgets/navigation/guidance_bottom_bar.dart';
import '../../utils/naver_map_utils.dart';

/// 길안내 화면
/// 실시간 Turn-by-Turn 네비게이션 제공
class GuidanceScreen extends StatefulWidget {
  const GuidanceScreen({super.key});

  @override
  State<GuidanceScreen> createState() => _GuidanceScreenState();
}

class _GuidanceScreenState extends State<GuidanceScreen>
    with TickerProviderStateMixin {
  NaverMapController? _mapController;
  late final NavigationViewModel _viewModel;
  bool _isMapReady = false;
  NLocationTrackingMode? _lastTrackingMode;
  NLatLng? _initialCenter;

  @override
  void initState() {
    super.initState();

    // 뒤로가기 시 안내 중지 처리를 위한 리스너
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel = context.read<NavigationViewModel>();

      // 길안내가 활성화되어 있는지 확인
      if (!_viewModel.isGuidanceActive) {
        // 비활성화 상태면 바로 시작
        _viewModel.startGuidance();
      }

      // 위치 추적 리스너 추가 (자동 지도 이동용)
      _viewModel.addListener(_onLocationChanged);
    });
  }

  /// 위치 변경 시 자동 지도 이동 처리
  void _onLocationChanged() {
    // 추적 모드이고, 길안내가 활성화되어 있고, 현재 위치가 있을 때만 지도 이동
    if (_viewModel.isFollowingLocation &&
        _viewModel.isGuidanceActive &&
        _viewModel.currentLocation != null) {
      _moveCameraTo(_viewModel.currentLocation!.coordinates);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onLocationChanged);
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // 뒤로가기 시 종료 확인 바텀시트 표시
        if (!didPop) {
          _showExitConfirmationBottomSheet(context);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 지도
            _buildMap(),

            // 네이버 지도 오버레이 동기화
            Selector<NavigationViewModel, _GuidanceOverlayData>(
              selector: (context, vm) => _GuidanceOverlayData(
                currentLocation: vm.currentLocation,
                selectedRoute: vm.state.route.selectedRoute,
                destination: vm.state.locations.destination?.coordinates,
              ),
              builder: (context, state, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _syncGuidanceOverlays(state);
                });
                return const SizedBox.shrink();
              },
            ),

            // 상단 안내 카드 (내부에서 Positioned 사용)
            _buildTopGuidanceCard(),

            // 하단 정보 바
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Selector<NavigationViewModel, _MapState>(
      selector: (context, vm) => _MapState(
        currentLocation: vm.currentLocation,
        selectedRoute: vm.state.route.selectedRoute,
      ),
      builder: (context, state, _) {
        if (state.currentLocation == null) {
          return const Center(child: CircularProgressIndicator());
        }

        _initialCenter ??= NLatLng(
          state.currentLocation!.latitude,
          state.currentLocation!.longitude,
        );

        return Stack(
          children: [
            NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: _initialCenter!,
                  zoom: 16,
                ),
                indoorEnable: true,
                // 한국어 주석: locationButtonEnable 제거 (1.4.0 Breaking Change)
                // 바텀 바(~100px)만큼 하단 패딩을 추가하여 GPS 버튼이 가려지지 않게 함
                contentPadding: const EdgeInsets.only(bottom: 120),
              ),
              onMapReady: (controller) async {
                if (!mounted) return;

                setState(() {
                  _mapController = controller;
                  _isMapReady = true;
                });

                // 한국어 주석: 진입 시 위치 추적 + 진행 방향 회전 모드를 자동 활성화
                // face 모드: 현재 위치 추적 + 이동 방향에 따라 지도 자동 회전
                controller.setLocationTrackingMode(NLocationTrackingMode.face);
                _lastTrackingMode = NLocationTrackingMode.face;

                await _syncGuidanceOverlays(_readOverlayData());
              },
              onCameraChange: (reason, animated) {
                // 사용자가 직접 드래그한 경우 추적 모드 비활성화
                if (reason == NCameraUpdateReason.gesture) {
                  context.read<NavigationViewModel>().setFollowingLocation(
                    false,
                  );
                }
              },
            ),

            // 한국어 주석: GPS 버튼 위젯 (1.4.0 신규 방식) - 좌측 하단
            if (_isMapReady && _mapController != null)
              Positioned(
                left: 14,
                bottom: 160, // 바텀 바(120) + 여유(40)
                child: NMyLocationButtonWidget(mapController: _mapController!),
              ),

            // 한국어 주석: 추적 모드 변경 시 지도 컨트롤러와 GPS 버튼 상태 동기화
            Selector<NavigationViewModel, _TrackingState>(
              selector: (context, vm) => _TrackingState(
                isTracking: vm.isTracking,
                isFollowingLocation: vm.isFollowingLocation,
              ),
              builder: (context, trackingState, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _syncTrackingMode(
                    isTracking: trackingState.isTracking,
                    isFollowingLocation: trackingState.isFollowingLocation,
                  );
                });
                return const SizedBox.shrink();
              },
            ),
          ],
        );
      },
    );
  }

  /// 뷰모델 상태를 오버레이 동기화용 데이터로 변환
  _GuidanceOverlayData _readOverlayData() {
    final vm = context.read<NavigationViewModel>();
    return _GuidanceOverlayData(
      currentLocation: vm.currentLocation,
      selectedRoute: vm.state.route.selectedRoute,
      destination: vm.state.locations.destination?.coordinates,
    );
  }

  /// 지도 오버레이를 최신 상태로 재구성
  Future<void> _syncGuidanceOverlays(_GuidanceOverlayData data) async {
    if (!_isMapReady || _mapController == null) return;

    await _mapController!.clearOverlays();
    final colorScheme = Theme.of(context).colorScheme;

    if (data.selectedRoute != null &&
        data.selectedRoute!.routePoints.isNotEmpty) {
      final routeLine = buildPolylineOverlay(
        'guidance_route',
        points: data.selectedRoute!.routePoints,
        color: colorScheme.primary,
        width: 6.0,
      );
      await _mapController!.addOverlay(routeLine);
    }

    if (data.destination != null) {
      final destMarker = await buildAssetMarkerOverlay(
        'guidance_destination',
        position: data.destination!,
        assetPath: 'assets/icons/ic_ar.png',
        size: const Size(48, 60),
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

  void _syncTrackingMode({
    required bool isTracking,
    required bool isFollowingLocation,
  }) {
    if (!mounted || !_isMapReady || _mapController == null) return;

    NLocationTrackingMode targetMode;
    if (!isTracking) {
      targetMode = NLocationTrackingMode.none;
    } else if (!isFollowingLocation) {
      targetMode = NLocationTrackingMode.noFollow;
    } else {
      targetMode = NLocationTrackingMode.face;
    }

    if (_lastTrackingMode == targetMode) return;

    _mapController!.setLocationTrackingMode(targetMode);
    _lastTrackingMode = targetMode;
  }

  /// 네이버 지도 카메라를 지정 좌표로 이동
  Future<void> _moveCameraTo(LatLng target, {double zoom = 16.0}) async {
    if (_mapController == null) return;

    final update = NCameraUpdate.scrollAndZoomTo(
      target: toNLatLng(target),
      zoom: zoom,
    );
    update.setAnimation(
      animation: NCameraAnimation.easing,
      duration: const Duration(milliseconds: 400),
    );
    await _mapController!.updateCamera(update);
  }

  Widget _buildTopGuidanceCard() {
    return Selector<NavigationViewModel, _TopCardState>(
      selector: (context, vm) => _TopCardState(
        currentManeuver: vm.currentManeuver,
        nextManeuver: vm.nextManeuver,
        distanceToCurrentManeuverMeters: vm.distanceToCurrentManeuverMeters,
        distanceToNextManeuverMeters: vm.distanceToNextManeuverMeters,
        pureInstructionText: vm.pureInstructionText,
        isRecalculating: vm.guidance.isRecalculating,
      ),
      builder: (context, state, _) {
        return GuidanceTopCard(
          currentManeuver: state.currentManeuver,
          nextManeuver: state.nextManeuver,
          distanceToCurrentManeuverMeters:
              state.distanceToCurrentManeuverMeters,
          distanceToNextManeuverMeters: state.distanceToNextManeuverMeters,
          pureInstructionText: state.pureInstructionText,
          isRecalculating: state.isRecalculating,
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Selector<NavigationViewModel, _BottomBarState>(
      selector: (context, vm) => _BottomBarState(
        remainingDistanceKm: vm.guidance.remainingDistanceKm,
        remainingMinutes: vm.guidance.remainingMinutes,
        currentSpeedKmh: vm.guidance.currentSpeedKmh,
      ),
      builder: (context, state, _) {
        return GuidanceBottomBar(
          remainingDistanceKm: state.remainingDistanceKm,
          remainingMinutes: state.remainingMinutes,
          currentSpeedKmh: state.currentSpeedKmh,
        );
      },
    );
  }

  /// 안내 종료 확인 바텀시트 (10초 카운트다운)
  void _showExitConfirmationBottomSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isDismissible: false, // 바깥 영역 터치로 닫기 방지
      enableDrag: false, // 드래그로 닫기 방지
      useSafeArea: true, // 시스템 UI 영역 고려 (노치, 홈 인디케이터 등)
      builder: (context) {
        return _ExitConfirmationBottomSheetContent(
          colorScheme: colorScheme,
          onExit: () {
            // 1. 길안내 중지
            context.read<NavigationViewModel>().stopGuidance();

            // 2. 바텀시트 닫기
            Navigator.pop(context);

            // 3. guidance_screen 닫기 (navigation_screen으로 돌아감)
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

// ==================== Selector용 상태 클래스들 ====================

class _MapState extends Equatable {
  final LocationModel? currentLocation;
  final RouteModel? selectedRoute;

  const _MapState({required this.currentLocation, required this.selectedRoute});

  @override
  List<Object?> get props => [currentLocation, selectedRoute];
}

class _GuidanceOverlayData extends Equatable {
  final LocationModel? currentLocation;
  final RouteModel? selectedRoute;
  final LatLng? destination;

  const _GuidanceOverlayData({
    required this.currentLocation,
    required this.selectedRoute,
    required this.destination,
  });

  @override
  List<Object?> get props => [currentLocation, selectedRoute, destination];
}

class _TopCardState extends Equatable {
  final ManeuverModel? currentManeuver;
  final ManeuverModel? nextManeuver;
  final double distanceToCurrentManeuverMeters;
  final double? distanceToNextManeuverMeters;
  final String pureInstructionText;
  final bool isRecalculating;

  const _TopCardState({
    required this.currentManeuver,
    required this.nextManeuver,
    required this.distanceToCurrentManeuverMeters,
    required this.distanceToNextManeuverMeters,
    required this.pureInstructionText,
    required this.isRecalculating,
  });

  @override
  List<Object?> get props => [
    currentManeuver,
    nextManeuver,
    distanceToCurrentManeuverMeters,
    distanceToNextManeuverMeters,
    pureInstructionText,
    isRecalculating,
  ];
}

class _BottomBarState extends Equatable {
  final double remainingDistanceKm;
  final int remainingMinutes;
  final double currentSpeedKmh;

  const _BottomBarState({
    required this.remainingDistanceKm,
    required this.remainingMinutes,
    required this.currentSpeedKmh,
  });

  @override
  List<Object?> get props => [
    remainingDistanceKm,
    remainingMinutes,
    currentSpeedKmh,
  ];
}

class _TrackingState extends Equatable {
  final bool isTracking;
  final bool isFollowingLocation;

  const _TrackingState({
    required this.isTracking,
    required this.isFollowingLocation,
  });

  @override
  List<Object?> get props => [isTracking, isFollowingLocation];
}

// ==================== 바텀시트 위젯 ====================

/// 안내 종료 확인 바텀시트 콘텐츠 (10초 카운트다운)
class _ExitConfirmationBottomSheetContent extends StatefulWidget {
  final ColorScheme colorScheme;
  final VoidCallback onExit;

  const _ExitConfirmationBottomSheetContent({
    required this.colorScheme,
    required this.onExit,
  });

  @override
  State<_ExitConfirmationBottomSheetContent> createState() =>
      _ExitConfirmationBottomSheetContentState();
}

class _ExitConfirmationBottomSheetContentState
    extends State<_ExitConfirmationBottomSheetContent>
    with SingleTickerProviderStateMixin {
  late int _countdown;
  Timer? _timer;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _countdown = 10; // 초기값 10초

    // 애니메이션 컨트롤러 (10초)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    // 1.0에서 0.0으로 애니메이션 (원형 프로그레스용)
    _animationController.forward(from: 0.0);

    // 1초마다 카운트다운
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      }

      // 0이 되면 자동 종료
      if (_countdown == 0) {
        timer.cancel();
        widget.onExit();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 타이머 메모리 누수 방지
    _animationController.dispose(); // 애니메이션 컨트롤러 정리
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 시스템 UI 영역 (노치, 홈 인디케이터 등)을 고려한 여백 계산
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomPadding, // 하단 시스템 UI 영역만큼 추가 여백
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더: 제목 + 닫기 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '경로 안내를 종료하시겠습니까?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: widget.colorScheme.onSurface),
                onPressed: () {
                  _timer?.cancel(); // 타이머 취소
                  _animationController.stop(); // 애니메이션 정지
                  Navigator.pop(context); // 바텀시트만 닫기
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 안내 종료 버튼 (카운트다운 표시)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                _timer?.cancel(); // 타이머 취소
                _animationController.stop(); // 애니메이션 정지
                widget.onExit(); // 즉시 종료
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.colorScheme.primary,
                foregroundColor: widget.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '안내 종료',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: widget.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 원형 프로그레스 + 카운트다운 숫자
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 원형 프로그레스 애니메이션
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return CircularProgressIndicator(
                              value: _animationController.value,
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.colorScheme.onPrimary,
                              ),
                              backgroundColor: widget.colorScheme.onPrimary
                                  .withValues(alpha: 0.2),
                            );
                          },
                        ),
                        // 카운트다운 숫자 (애니메이션 전환)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            '$_countdown',
                            key: ValueKey<int>(_countdown),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: widget.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
