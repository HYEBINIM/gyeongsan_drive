// UTF-8 인코딩 파일
// 한국어 주석: 안전귀가 화면 UI 및 모니터 이벤트 처리
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/location_model.dart';
import '../../models/safe_home_state.dart';
import '../../view_models/safe_home/safe_home_viewmodel.dart';
import '../../services/location/location_service.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/common_app_bar.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/shimmer_wrapper.dart';
import '../../widgets/common/glow_border_container.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';
// 한국어 주석: 안전귀가 설정을 읽어 자동 경로 계산 트리거
import '../../view_models/safe_home/safe_home_settings_viewmodel.dart';
import '../../view_models/navigation/navigation_viewmodel.dart';
import '../../models/navigation/route_model.dart' show LocationInfo, RouteModel;
import '../../models/navigation/route_type.dart';
import '../../view_models/safe_home/safe_home_monitor_viewmodel.dart';
import '../../models/safe_home_event.dart';
import '../../services/permission/permission_service.dart';
import '../../widgets/safe_home/security_verification_bottom_sheet.dart';
import '../../utils/emergency_utils.dart';
import '../../utils/safe_home_constants.dart';
import 'package:equatable/equatable.dart';
import '../../utils/naver_map_utils.dart';

/// 안전귀가 화면 UI
/// 사용자의 현재 위치를 지도에 표시하고 실시간 추적
class SafeHomeScreen extends StatefulWidget {
  const SafeHomeScreen({super.key});

  @override
  State<SafeHomeScreen> createState() => _SafeHomeScreenState();
}

class _SafeHomeScreenState extends State<SafeHomeScreen>
    with TickerProviderStateMixin {
  NaverMapController? _mapController;
  // 한국어 주석: 마지막으로 적용된 위치 추적 모드 캐시 (맵 재생성 시 동기화)
  NLocationTrackingMode? _lastTrackingMode;
  LocationModel? _previousLocation;
  // 지도 초기 중심을 한 번만 계산해 고정하기 위한 필드
  NLatLng? _initialCenter;
  // 한국어 주석: 경로 fit 중복 방지용 서명
  String? _lastRouteFitSignature;
  // 한국어 주석: 경로 fit 시 화면 여백 (상/우/하/좌)
  static const EdgeInsets _routeFitPadding = EdgeInsets.fromLTRB(
    24,
    24,
    24,
    160,
  );
  // 한국어 주석: 모드 활성/비활성 변경 감지를 위한 이전 상태 저장
  bool _wasModeActive = false;
  // 한국어 주석: 마지막으로 표시한 이벤트 시각 (중복 스낵바 방지)
  DateTime? _lastShownEventAt;
  // 한국어 주석: 모니터 VM의 리스너 해제를 위해 참조 보관
  VoidCallback? _monitorVmListener;
  // 한국어 주석: dispose 시점에 안전하게 리스너를 제거하기 위한 VM 참조
  SafeHomeMonitorViewModel? _monitorVm;
  // 한국어 주석: 전화 중복 발송 방지 플래그
  bool _callMade = false;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();

    // 화면 진입 시 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 한국어 주석: 1. 위치 권한 요청 (안전귀가 핵심 기능)
      try {
        final locationGranted = await PermissionService()
            .requestLocationPermission();
        if (!locationGranted && mounted) {
          SnackBarUtils.showError(context, '위치 권한이 필요합니다. 설정에서 위치 권한을 허용해주세요.');
        }
      } catch (e) {
        // 위치 권한 요청 실패
      }

      if (!mounted) return;

      // 한국어 주석: 2. 알림 권한 요청 (안전귀가 알림용)
      try {
        final notificationGranted = await PermissionService()
            .requestNotificationPermission();
        if (!notificationGranted && mounted) {
          SnackBarUtils.showWarning(
            context,
            '알림 권한이 거부되었습니다. 안전귀가 알림을 받을 수 없습니다.',
          );
        }
      } catch (e) {
        // 알림 권한 요청 실패
      }

      // 한국어 주석: async 작업 후 mounted 체크 (위젯이 아직 트리에 있는지 확인)
      if (!mounted) return;

      context.read<SafeHomeViewModel>().initialize(force: true);
      // 한국어 주석: 설정에 목적지가 있으면 자동으로 도보·최단 경로 계산
      _attemptAutoRouteFromSettings();
      // 한국어 주석: 모니터 VM 이벤트 구독을 위한 초기 설정
      _subscribeToMonitorEvents();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _lastTrackingMode = null;
    // 한국어 주석: 모니터 VM 리스너 해제 (저장된 참조 사용으로 dispose 시점 크래시 방지)
    if (_monitorVmListener != null && _monitorVm != null) {
      _monitorVm!.removeListener(_monitorVmListener!);
      _monitorVmListener = null;
    }
    super.dispose();
  }

  /// 설정의 목적지가 있는 경우 자동으로 경로 탐색 실행
  Future<void> _attemptAutoRouteFromSettings() async {
    try {
      final settingsVm = context.read<SafeHomeSettingsViewModel>();
      // 설정이 아직 로드되지 않았다면 로드 시도
      if (settingsVm.settings == null) {
        await settingsVm.initialize();
        if (!mounted) return;
      }

      final s = settingsVm.settings;
      if (s?.destination != null &&
          s?.destinationLat != null &&
          s?.destinationLng != null) {
        final navVm = context.read<NavigationViewModel>();
        final route = await navVm.calculateShortestWalkingForSafeHome(
          destination: LocationInfo(
            address: s!.destination!, // 주소가 없으므로 표시용으로 목적지명 사용
            placeName: s.destination!,
            coordinates: LatLng(s.destinationLat!, s.destinationLng!),
          ),
        );
        if (!mounted) return;

        // 한국어 주석: 경로 탐색 후 도착 시간(ETA) 자동 업데이트
        if (route != null) {
          final eta = DateTime.now().add(
            Duration(minutes: route.estimatedMinutes),
          );
          await settingsVm.setArrivalTime(TimeOfDay.fromDateTime(eta));
          if (!mounted) return;
        }
      }
    } catch (e) {
      // 한국어 주석: 자동 경로 탐색 실패는 UI를 막지 않음
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: CommonAppBar(
          title: '안전귀가',
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.safeHomeSettings);
              },
            ),
          ],
        ),
        drawer: AppDrawer(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Selector<SafeHomeSettingsViewModel, bool>(
          selector: (context, vm) => vm.isModeActive,
          builder: (context, isModeActive, _) {
            // 한국어 주석: 모드 상태 변경 시 모니터링 시작/중지
            if (isModeActive != _wasModeActive) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleModeChange(isModeActive);
              });
              _wasModeActive = isModeActive;
            }
            return GlowBorderContainer(
              isActive: isModeActive,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 지도 프레임은 고정, 마커 데이터만 변경되도록 구성
                  Selector<SafeHomeViewModel, bool>(
                    selector: (context, vm) => vm.hasLocation,
                    builder: (context, hasLocation, _) {
                      if (!hasLocation) {
                        return _buildEmptyState();
                      }
                      // hasLocation이 true로 변했을 때 한 번만 초기 중심을 사용
                      final location = context
                          .read<SafeHomeViewModel>()
                          .currentLocation!;
                      // 이미 초기 중심이 설정되어 있으면 갱신하지 않음 (지도 프레임 재초기화 방지)
                      _initialCenter ??= NLatLng(
                        location.latitude,
                        location.longitude,
                      );
                      return _buildPersistentMap(_initialCenter!);
                    },
                  ),

                  // 카메라 이동/트래킹은 별도 ValueListenableBuilder에서 사이드이펙트만 수행
                  ValueListenableBuilder<BasicMapState>(
                    valueListenable: context
                        .select<
                          SafeHomeViewModel,
                          ValueNotifier<BasicMapState>
                        >((viewModel) => viewModel.mapStateNotifier),
                    builder: (context, mapState, _) {
                      _handleLocationEvent(mapState);
                      return const SizedBox.shrink();
                    },
                  ),

                  // 한국어 주석: 경로 준비 완료 시, 전체 경로가 보이도록 자동 fit
                  Selector<NavigationViewModel, _SafeHomeRouteFitState>(
                    selector: (context, vm) => _SafeHomeRouteFitState(
                      isCalculating: vm.isCalculating,
                      selectedRoute: vm.routes[vm.selectedRouteType],
                      start: vm.locations.start?.coordinates,
                      destination: vm.locations.destination?.coordinates,
                    ),
                    builder: (context, state, _) {
                      _fitToSelectedRouteIfNeeded(context, state);
                      return const SizedBox.shrink();
                    },
                  ),

                  // 네이버 지도 오버레이 동기화 (경로/마커/현재 위치)
                  Selector2<
                    NavigationViewModel,
                    SafeHomeViewModel,
                    _SafeHomeOverlayState
                  >(
                    selector: (context, navVm, safeVm) => _SafeHomeOverlayState(
                      routes: navVm.routes,
                      selectedRouteType: navVm.selectedRouteType,
                      start: navVm.locations.start?.coordinates,
                      destination: navVm.locations.destination?.coordinates,
                      currentLocation: safeVm.currentLocation,
                    ),
                    builder: (context, state, _) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _syncSafeHomeOverlays(state);
                      });
                      return const SizedBox.shrink();
                    },
                  ),

                  // 한국어 주석: 설정 변경 시 모니터 서비스에 동기화 (모드 활성 상태에서만)
                  Selector<SafeHomeSettingsViewModel, _MonitorSettingsSnapshot>(
                    selector: (context, vm) => _MonitorSettingsSnapshot(
                      arrivalTime: vm.arrivalTime,
                      noMovementMinutes: vm.noMovementDetectionMinutes,
                      overlayMinutes: vm.arrivalTimeOverlayMinutes,
                      isModeActive: vm.isModeActive,
                    ),
                    builder: (context, snap, _) {
                      if (snap.isModeActive) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final settings = context
                              .read<SafeHomeSettingsViewModel>()
                              .settings;
                          if (settings != null) {
                            context
                                .read<SafeHomeMonitorViewModel>()
                                .updateSettings(settings);
                          }
                        });
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // 로딩/에러 오버레이
                  Selector<SafeHomeViewModel, LoadingErrorState>(
                    selector: (context, viewModel) => LoadingErrorState(
                      isLoading: viewModel.isLoading,
                      hasLocation: viewModel.hasLocation,
                      errorMessage: viewModel.errorMessage,
                    ),
                    builder: (context, state, child) {
                      // 위치 초기 로딩 단계에서만 전체 스켈레톤 오버레이를 사용
                      if (state.isLoading && !state.hasLocation) {
                        return _buildLoadingSkeleton();
                      }
                      if (!state.isLoading && state.errorMessage != null) {
                        return _buildErrorOverlay(context, state);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  // 네이버 기본 GPS 버튼 사용 (추가 버튼 없음)
                ],
              ),
            );
          },
        ),
        // 한국어 주석: 에러 상태일 때는 FAB 숨김 (위치 권한 거부 등)
        floatingActionButton: Selector<SafeHomeViewModel, String?>(
          selector: (context, vm) => vm.errorMessage,
          builder: (context, errorMessage, _) {
            // 에러가 있으면 FAB를 표시하지 않음
            if (errorMessage != null) {
              return const SizedBox.shrink();
            }
            return _buildSafeHomeFAB(context);
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  /// 한국어 주석: 모드 상태 변경 시 모니터링 시작/중지 처리
  Future<void> _handleModeChange(bool isActive) async {
    final monitorVm = context.read<SafeHomeMonitorViewModel>();
    final settingsVm = context.read<SafeHomeSettingsViewModel>();
    if (isActive) {
      final settings = settingsVm.settings;
      final startedAt = settingsVm.modeStartedAt;
      if (settings != null && startedAt != null) {
        await monitorVm.start(settings: settings, modeStartedAt: startedAt);
      }
      // 한국어 주석: 안전 귀가 모드 활성화 시 위치 추적 + 진행 방향 회전 모드로 전환
      _applyTrackingModeForState(isModeActive: true, force: true);
    } else {
      monitorVm.stop();
      // 한국어 주석: 안전 귀가 모드 종료 시 기본 위치 추적 모드로 복원
      _applyTrackingModeForState(isModeActive: false, force: true);
    }
  }

  /// 한국어 주석: 모니터 VM 이벤트 구독 → 보안 암호 입력 다이얼로그 표시
  void _subscribeToMonitorEvents() {
    // 빌드 이후 Provider 접근 보장 및 dispose 시 안전한 해제를 위한 참조 저장
    _monitorVm = context.read<SafeHomeMonitorViewModel>();
    _monitorVmListener = () {
      final event = _monitorVm!.lastEvent;
      if (event == null) return;

      // 한국어 주석: 이미 활성화된 경고가 있으면 무시 (다이얼로그 재표시 방지)
      if (_monitorVm!.isAlertActive) return;

      // 중복 다이얼로그 방지 (500ms 이내 동일 타임스탬프 무시)
      if (_lastShownEventAt != null) {
        final diff = event.timestamp.difference(_lastShownEventAt!);
        if (diff.inMilliseconds.abs() < 500) return;
      }
      _lastShownEventAt = event.timestamp;

      // 한국어 주석: 경고 알림 횟수 한도 초과 시 자동 비상 신고 처리
      final settingsVm = context.read<SafeHomeSettingsViewModel>();
      final settings = settingsVm.settings;
      final warningLimit = settings?.warningAlertCount ?? 3;

      // 한국어 주석: 이미 허용된 경고 횟수를 모두 소진한 상태에서
      // 새로운 이상 이벤트가 들어오면 즉시 비상연락처로 신고를 시도합니다.
      if (_monitorVm!.alertCount >= warningLimit && !_callMade) {
        unawaited(
          EmergencyUtils.makeEmergencyCall(settingsVm.emergencyContacts),
        );
        _callMade = true;

        if (mounted) {
          SnackBarUtils.showWarning(
            context,
            '여러 차례 이상이 감지되어 비상연락처로 자동 신고를 시도했어요.',
          );
        }
        return;
      }

      // 한국어 주석: 경고 활성화 (중복 방지는 activateAlert 내부에서 처리)
      _monitorVm!.activateAlert(event);
      // 한국어 주석: 이번 이상 이벤트를 경고 발생으로 카운트
      _monitorVm!.incrementAlertCount();

      if (!mounted) return;

      // 한국어 주석: 보안 암호 입력 다이얼로그 표시
      _showSecurityVerificationDialog(event);
    };
    _monitorVm!.addListener(_monitorVmListener!);
  }

  /// 한국어 주석: 보안 암호 입력 Bottom Sheet 표시
  void _showSecurityVerificationDialog(SafeHomeEvent event) {
    // 이미 Bottom Sheet가 떠있으면 무시 (중복 방지)
    if (_monitorVm!.isAlertActive &&
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }

    // 한국어 주석: 진동으로 긴급성 강조
    HapticFeedback.heavyImpact();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // 한국어 주석: 높이 자유 조절 (키보드 대응)
      isDismissible: false, // 한국어 주석: 닫기 불가 (강제 입력)
      enableDrag: false, // 한국어 주석: 드래그 비활성화
      backgroundColor: Colors.transparent, // 한국어 주석: 커스텀 배경
      builder: (context) => SecurityVerificationBottomSheet(
        event: event,
        failCount: _monitorVm!.verificationFailCount,
        // 한국어 주석: 검증 콜백은 비동기 함수를 그대로 전달
        onVerify: _handlePasswordVerification,
      ),
    );
  }

  /// 한국어 주석: 암호 검증 핸들러 (DRY: SafeHomeSettingsViewModel.verifyPassword 재사용)
  Future<void> _handlePasswordVerification(String pin) async {
    final settingsVm = context.read<SafeHomeSettingsViewModel>();
    final monitorVm = context.read<SafeHomeMonitorViewModel>();

    // 한국어 주석: 암호 검증 (기존 verifyPassword 재사용)
    if (settingsVm.verifyPassword(pin)) {
      // 성공: 경고 해제
      monitorVm.dismissAlert();
      // 한국어 주석: 암호 검증 성공 시 설정된 쿨다운 시간 동안 새 이벤트를 무시
      monitorVm.applyCooldown(
        Duration(minutes: SafeHomeConstants.alertCooldownMinutes),
      );
      _callMade = false; // 한국어 주석: 전화 걸기 플래그 리셋
      Navigator.of(context).pop(); // 다이얼로그 닫기

      if (!mounted) return;
      SnackBarUtils.showSuccess(context, '안전이 확인되었습니다.');
    } else {
      // 실패: 횟수 증가
      monitorVm.incrementFailCount();
      HapticFeedback.heavyImpact();

      // 한국어 주석: 3회 초과 OR 경고 알림 횟수 초과 시 비상연락처에 전화
      // 한국어 주석: 비상 전화 트리거는 PIN 시도 제한(고정 3회)과 분리
      final shouldMakeCall =
          monitorVm.verificationFailCount >= SafeHomeConstants.pinMaxAttempts;

      if (shouldMakeCall && !_callMade) {
        // 한국어 주석: 첫 번째 비상연락처에게 전화 걸기
        await EmergencyUtils.makeEmergencyCall(settingsVm.emergencyContacts);

        _callMade = true; // 한국어 주석: 전화 걸기 완료 표시 (중복 방지)
      }

      // 한국어 주석: 다이얼로그는 유지 (계속 입력 가능)
      // setState는 다이얼로그 내부에서 처리
    }
  }

  /// 지도 표시 (지도의 프레임은 고정, 내부 레이어만 상태에 반응)
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
          ),
          onMapReady: (controller) async {
            if (!mounted) return;

            setState(() {
              _mapController = controller;
              _isMapReady = true;
            });

            _lastTrackingMode = null; // 한국어 주석: 새 컨트롤러 생성 시 모드 재동기화 필요
            // 한국어 주석: 현재 모드 상태에 맞춰 위치 추적 모드 동기화
            _applyTrackingModeForState(force: true);
            await _syncSafeHomeOverlays(_readSafeHomeOverlayData());
          },
          onCameraChange: (reason, animated) {
            // 사용자가 직접 드래그한 경우 추적 모드 비활성화
            if (reason == NCameraUpdateReason.gesture) {
              context.read<SafeHomeViewModel>().setFollowingLocation(false);
            }
          },
        ),

        // 한국어 주석: GPS 버튼 위젯 (1.4.0 신규 방식) - 좌측 하단
        if (_isMapReady && _mapController != null)
          Positioned(
            left: 14,
            bottom: 44,
            child: NMyLocationButtonWidget(mapController: _mapController!),
          ),
      ],
    );
  }

  /// 한국어 주석: 위치 이벤트를 단일 지점에서 처리 (센터 이동 + 줌 + face 유지)
  void _handleLocationEvent(BasicMapState mapState) {
    final isLoading = context.read<SafeHomeViewModel>().isLoading;
    if (isLoading) return;

    // 한국어 주석: 추적 상태(isFollowingLocation) 변경 시 버튼/모드 동기화
    _setTrackingMode(
      isTracking: mapState.isTracking,
      isFollowingLocation: mapState.isFollowingLocation,
    );

    final location = mapState.currentLocation;
    if (location == null || !mapState.isTracking) return;

    if (_previousLocation == location) return;

    _previousLocation = location;

    // GPS 버튼 클릭 시 카메라 줌/센터 이동을 제거하고, 추적 모드만 일관되게 유지
    if (context.read<SafeHomeSettingsViewModel>().isModeActive) {
      _applyTrackingModeForState(force: true);
    }
  }

  /// 한국어 주석: 안전귀가 모드 상태에 맞춰 위치 추적 모드를 일관되게 설정
  void _applyTrackingModeForState({bool? isModeActive, bool force = false}) {
    _setTrackingMode(
      isTracking: true,
      isFollowingLocation: true,
      isModeActiveOverride: isModeActive,
      force: force,
    );
  }

  void _setTrackingMode({
    required bool isTracking,
    required bool isFollowingLocation,
    bool? isModeActiveOverride,
    bool force = false,
  }) {
    if (!mounted || !_isMapReady || _mapController == null) return;

    final safeHomeActive =
        isModeActiveOverride ??
        context.read<SafeHomeSettingsViewModel>().isModeActive;

    NLocationTrackingMode targetMode;
    if (!isTracking) {
      targetMode = NLocationTrackingMode.none;
    } else if (!isFollowingLocation) {
      targetMode = NLocationTrackingMode.noFollow;
    } else {
      targetMode = safeHomeActive
          ? NLocationTrackingMode.face
          : NLocationTrackingMode.follow;
    }

    if (!force && _lastTrackingMode == targetMode) return;

    _mapController!.setLocationTrackingMode(targetMode);
    _lastTrackingMode = targetMode;
  }

  /// 최신 상태를 반영한 오버레이 데이터 스냅샷 생성
  _SafeHomeOverlayState _readSafeHomeOverlayData() {
    final navVm = context.read<NavigationViewModel>();
    final safeVm = context.read<SafeHomeViewModel>();
    return _SafeHomeOverlayState(
      routes: navVm.routes,
      selectedRouteType: navVm.selectedRouteType,
      start: navVm.locations.start?.coordinates,
      destination: navVm.locations.destination?.coordinates,
      currentLocation: safeVm.currentLocation,
    );
  }

  /// 네이버 지도 오버레이를 경로/마커/현재 위치 기준으로 재구성
  Future<void> _syncSafeHomeOverlays(_SafeHomeOverlayState state) async {
    if (!_isMapReady || _mapController == null) return;

    await _mapController!.clearOverlays();
    final colorScheme = Theme.of(context).colorScheme;

    // 미선택 경로 먼저 렌더링
    for (final entry in state.routes.entries) {
      final routeType = entry.key;
      final route = entry.value;
      if (route == null ||
          route.routePoints.isEmpty ||
          routeType == state.selectedRouteType)
        continue;

      final polyline = buildPolylineOverlay(
        'safe_home_route_${routeType.name}',
        points: route.routePoints,
        color: colorScheme.onSurface.withValues(alpha: 0.5),
        width: 5.0,
      );
      await _mapController!.addOverlay(polyline);
    }

    // 선택된 경로를 위에 렌더링
    final selectedRoute = state.routes[state.selectedRouteType];
    if (selectedRoute != null && selectedRoute.routePoints.isNotEmpty) {
      final polyline = buildPolylineOverlay(
        'safe_home_route_selected',
        points: selectedRoute.routePoints,
        color: colorScheme.primary,
        width: 5.0,
      );
      await _mapController!.addOverlay(polyline);
    }

    // 출발/도착 마커
    if (state.start != null) {
      final startMarker = await buildAssetMarkerOverlay(
        'safe_home_start',
        position: state.start!,
        assetPath: 'assets/icons/ic_st.png',
      );
      await _mapController!.addOverlay(startMarker);
    }

    if (state.destination != null) {
      final destMarker = await buildAssetMarkerOverlay(
        'safe_home_destination',
        position: state.destination!,
        assetPath: 'assets/icons/ic_ar.png',
      );
      await _mapController!.addOverlay(destMarker);
    }

    // 한국어 주석: 모드 상태에 맞춰 추적 모드가 유지되도록 재적용
    _applyTrackingModeForState(
      force: context.read<SafeHomeSettingsViewModel>().isModeActive,
    );

    // 네이버 기본 현재 위치 오버레이 사용
    final locationOverlay = _mapController!.getLocationOverlay();
    if (state.currentLocation != null) {
      locationOverlay.setPosition(
        toNLatLng(
          LatLng(
            state.currentLocation!.latitude,
            state.currentLocation!.longitude,
          ),
        ),
      );
    }
  }

  /// 한국어 주석: 경로가 준비되면 화면에 전체 루트가 들어오도록 카메라를 맞춤
  void _fitToSelectedRouteIfNeeded(
    BuildContext context,
    _SafeHomeRouteFitState state,
  ) {
    final route = state.selectedRoute;
    if (state.isCalculating || route == null || route.routePoints.length < 2) {
      return;
    }

    // 경계 계산용 포인트: 경로 포인트 + (선택) 출발/도착 좌표
    final points = <LatLng>[...route.routePoints];
    if (state.start != null) points.add(state.start!);
    if (state.destination != null) points.add(state.destination!);
    if (points.isEmpty) return;

    final bounds = buildBoundsFromPoints(points);
    final sw = bounds.southWest;
    final ne = bounds.northEast;
    final signature =
        '${sw.latitude.toStringAsFixed(6)},${sw.longitude.toStringAsFixed(6)}|'
        '${ne.latitude.toStringAsFixed(6)},${ne.longitude.toStringAsFixed(6)}|'
        '${points.length}';

    if (_lastRouteFitSignature == signature) return; // 중복 fit 방지

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_mapController == null) return;
      try {
        final cameraUpdate = NCameraUpdate.fitBounds(
          bounds,
          padding: _routeFitPadding,
        );
        cameraUpdate.setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 500),
        );
        await _mapController!.updateCamera(cameraUpdate);
        _lastRouteFitSignature = signature;
      } catch (e) {
        // 안전귀가 경로 fit 실패
      }
    });
  }

  /// 로딩 스켈레톤
  Widget _buildLoadingSkeleton() {
    final colorScheme = Theme.of(context).colorScheme;
    return ShimmerWrapper(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  /// 빈 상태
  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '위치 정보를 가져올 수 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 오버레이
  Widget _buildErrorOverlay(BuildContext context, LoadingErrorState state) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Stack(
        children: [
          // 배경 흐림 효과
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: colorScheme.scrim.withValues(alpha: 0.3)),
            ),
          ),

          // 중앙 카드
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.scrim.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage ?? '알 수 없는 오류',
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // 재시도 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<SafeHomeViewModel>().initialize(
                          force: true,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('다시 시도'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 설정으로 이동 버튼 (권한 거부된 경우)
                  if (state.errorMessage?.contains('권한') == true)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => openAppSettings(),
                        child: Text(
                          '설정으로 이동',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontFamily: AppConstants.fontFamilySmall,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 안전귀가 모드 FAB 버튼
  Widget _buildSafeHomeFAB(BuildContext context) {
    return Selector<SafeHomeSettingsViewModel, bool>(
      selector: (context, vm) => vm.isModeActive,
      builder: (context, isModeActive, _) {
        final colorScheme = Theme.of(context).colorScheme;

        return SizedBox(
          width: 200,
          height: 56,
          child: FloatingActionButton.extended(
            onPressed: () => _toggleSafeHomeMode(context),
            backgroundColor: isModeActive
                ? colorScheme.error
                : colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 8,
            icon: Icon(
              isModeActive ? Icons.stop_circle : Icons.play_circle,
              size: 28,
            ),
            label: Text(
              isModeActive ? '안전귀가 종료' : '안전귀가 시작',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  /// 안전귀가 모드 토글
  Future<void> _toggleSafeHomeMode(BuildContext context) async {
    final settingsVm = context.read<SafeHomeSettingsViewModel>();

    if (settingsVm.isModeActive) {
      // 종료 확인 다이얼로그
      final confirmed = await _showStopConfirmationDialog(context);
      if (!confirmed) return;

      try {
        await settingsVm.stopSafeHomeMode();
      } catch (e) {
        // 한국어 주석: 안전귀가 모드 종료 실패 시 사용자에게 에러 표시
        if (context.mounted) {
          SnackBarUtils.showError(context, '안전귀가 모드 종료에 실패했습니다: $e');
        }
      }
    } else {
      // 시작 전 검증 (필수 항목 충족 여부 확인)
      if (!settingsVm.canStartSafeHomeMode()) {
        final missing = settingsVm.getMissingRequirements();
        if (!context.mounted) return;
        await _showMissingRequirementsDialog(context, missing);
        return;
      }

      // 사용자 안내 (Foreground Service 사용)
      if (context.mounted) {
        SnackBarUtils.showInfo(context, '안전귀가 모드가 시작됩니다.');
      }

      try {
        await settingsVm.startSafeHomeMode();
      } catch (e) {
        // 한국어 주석: 안전귀가 모드 시작 실패 시 사용자에게 에러 표시
        if (context.mounted) {
          SnackBarUtils.showError(context, '안전귀가 모드 시작에 실패했습니다: $e');
        }
      }
    }
  }

  /// 필수 설정 미완료 다이얼로그
  Future<void> _showMissingRequirementsDialog(
    BuildContext context,
    List<String> missing,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.error,
            size: 48,
          ),
          title: Text(
            '필수 설정 미완료',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '안전귀가 모드를 시작하려면 다음 항목을 설정해주세요:',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 12),
              ...missing.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        item,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: TextStyle(color: colorScheme.onSurface)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.safeHomeSettings);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('설정하기'),
            ),
          ],
        );
      },
    );
  }

  /// 종료 확인 다이얼로그
  Future<bool> _showStopConfirmationDialog(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '안전귀가 모드 종료',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '안전귀가 모드를 종료하시겠습니까?',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소', style: TextStyle(color: colorScheme.onSurface)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('종료'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

/// SafeHomeScreen을 Provider로 감싸는 래퍼
/// ViewModel을 제공하고 화면을 빌드
class SafeHomeScreenWithProvider extends StatelessWidget {
  const SafeHomeScreenWithProvider({super.key});

  @override
  Widget build(BuildContext context) {
    // 한국어 주석: SafeHomeSettingsViewModel은 앱 루트(MyApp)에서 이미 제공됩니다.
    // 여기서 새 인스턴스를 만들면 설정 화면과 서로 다른 인스턴스를 참조하여
    // 실시간 반영이 끊기고 "필수 설정 미완료" 다이얼로그가 계속 뜨는 문제가 발생합니다.
    // 따라서 Settings VM은 재제공하지 않고 상위 Provider 인스턴스를 그대로 사용합니다.
    return MultiProvider(
      providers: [
        // 위치 추적 및 지도 상태 관리 ViewModel
        ChangeNotifierProvider(
          create: (_) => SafeHomeViewModel(locationService: LocationService()),
        ),
        // 한국어 주석: 모니터 VM은 MyApp에서 전역 제공 → 이 화면에서는 재제공하지 않음
      ],
      child: const SafeHomeScreen(),
    );
  }
}

/// 지도 오버레이 동기화 상태
/// 한국어 주석: currentLocation은 props에서 제외하여 GPS 업데이트마다
/// 오버레이가 재생성되는 것을 방지합니다. 현재 위치는 네이버 기본
/// locationOverlay로 관리되므로 Selector 재실행이 불필요합니다.
class _SafeHomeOverlayState extends Equatable {
  final Map<RouteType, RouteModel?> routes;
  final RouteType selectedRouteType;
  final LatLng? start;
  final LatLng? destination;
  final LocationModel? currentLocation;

  const _SafeHomeOverlayState({
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

/// Selector용 상태 (경로 fit)
class _SafeHomeRouteFitState {
  final bool isCalculating;
  final RouteModel? selectedRoute;
  final LatLng? start;
  final LatLng? destination;

  _SafeHomeRouteFitState({
    required this.isCalculating,
    required this.selectedRoute,
    required this.start,
    required this.destination,
  });
}

/// 한국어 주석: 모니터 설정 동기화용 스냅샷 (Selector 최소 변경)
// 한국어 주석: Selector 비교 최적화
// 동일한 값이면 빌더가 재호출되지 않도록 Equatable 적용
class _MonitorSettingsSnapshot extends Equatable {
  final String? arrivalTime; // 도착 시간
  final int noMovementMinutes; // 움직임 없음 감지 분
  final int overlayMinutes; // 도착 시간 초과 허용 분
  final bool isModeActive; // 모드 활성 여부

  const _MonitorSettingsSnapshot({
    required this.arrivalTime,
    required this.noMovementMinutes,
    required this.overlayMinutes,
    required this.isModeActive,
  });

  @override
  List<Object?> get props => <Object?>[
    arrivalTime,
    noMovementMinutes,
    overlayMinutes,
    isModeActive,
  ];
}
