import 'dart:async';
import 'dart:collection';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:equatable/equatable.dart';
import '../../models/location_model.dart';
import '../../models/place_model.dart';
import '../../models/region_info_state.dart';
import '../../view_models/region_info/region_info_viewmodel.dart';
import '../../services/permission/permission_service.dart';
import '../../widgets/common/common_app_bar.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/shimmer_wrapper.dart';
import '../../widgets/region_info/category_island_button.dart';
import '../../widgets/region_info/place_list_bottom_sheet.dart';
import '../../widgets/home/voice_command_fab.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';
import '../../utils/naver_map_utils.dart';

/// 지역 정보 화면 UI
/// 사용자의 현재 위치를 지도에 표시
class RegionInfoScreen extends StatefulWidget {
  const RegionInfoScreen({super.key});

  @override
  State<RegionInfoScreen> createState() => _RegionInfoScreenState();
}

class _RegionInfoScreenState extends State<RegionInfoScreen>
    with TickerProviderStateMixin {
  NaverMapController? _mapController;
  String? _previousSelectedPlaceId;
  // 한국어 주석: 지도 초기 중심을 한 번만 계산해 고정하기 위한 필드
  LatLng? _initialCenter;
  // 한국어 주석: 바텀시트 열림/닫힘 전환 감지를 위한 상태
  bool _wasBottomSheetOpen = false;
  // 한국어 주석: 지도 위젯의 실제 높이를 측정하기 위한 GlobalKey
  final GlobalKey _mapContainerKey = GlobalKey();
  // 한국어 주석: 지도 높이와 바텀시트 점유 비율(0.0~1.0)
  double _mapHeight = 0;
  double _bottomSheetFraction = 0.0;
  double _mapContentPaddingBottom = 0.0;
  double _desiredContentPaddingBottom = 0.0;
  bool _mapPaddingUpdateScheduled = false;
  // 한국어 주석: 바텀시트 오프셋 기반 지도 보정 값 캐싱 (미세 움직임 스킵)
  double _lastOffsetForRecenter = 0.0;
  // 한국어 주석: Debounce & Throttle 제어 (성능 최적화)
  Timer? _recenterDebounceTimer;
  DateTime _lastRecenterTime = DateTime.now();
  static const double _kMapPaddingEpsilon = 1.0;
  static const double _kGpsButtonGap = 8.0;
  static const double _kLocationButtonSpacing = 12.0;
  static const double _kLogoHeight = 17.0;
  static const double _kLogoMarginBottom = 16.0;
  static const double _kRecenterOffsetEpsilon = 3.0;
  static const double _kVisibleOffsetRatio = 0;
  // 한국어 주석: 성능 최적화 임계값 (드래그 중 throttle, 완료 시 debounce)
  static const Duration _kRecenterThrottle = Duration(milliseconds: 100);
  static const Duration _kRecenterDebounce = Duration(milliseconds: 200);
  // 한국어 주석: 지도 리센터 작업을 프레임당 한 번만 처리하기 위한 스케줄링 상태
  bool _recenterFrameScheduled = false;
  bool _pendingAnimatedRecenter = false;
  NCameraPosition? _lastCameraPosition;
  bool _isMapReady = false;
  NLocationTrackingMode? _lastTrackingMode;
  // 한국어 주석: fromWidget 마커 이미지 캐시/직렬화를 통해 ImageReader 버퍼 초과를 완화
  static const Duration _kPlaceMarkerIconBuildDelay = Duration(
    milliseconds: 80,
  );
  static const int _kPlaceMarkerIconCacheLimit = 200;
  final LinkedHashMap<_PlaceMarkerIconCacheKey, NOverlayImage>
  _placeMarkerIconCache =
      LinkedHashMap<_PlaceMarkerIconCacheKey, NOverlayImage>();
  final Map<_PlaceMarkerIconCacheKey, Future<NOverlayImage>>
  _placeMarkerIconPending = {};
  Future<void> _placeMarkerIconBuildQueue = Future.value();
  int? _cachedMarkerSurfaceColorValue;
  int? _cachedMarkerPrimaryColorValue;
  final Map<String, _ActivePlaceMarker> _placeMarkers = {};
  _PlaceMarkerState? _pendingPlaceMarkerState;
  bool _isSyncingPlaceMarkers = false;
  bool _placeMarkerSyncScheduled = false;
  bool _needsPlaceMarkerResync = false;
  bool _forcePlaceMarkerIconRefresh = false;

  @override
  void initState() {
    super.initState();

    // 화면 진입 시 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 위치 권한 요청 (지역 정보 필수 기능)
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

      context.read<RegionInfoViewModel>().initialize(force: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceValue = colorScheme.surface.toARGB32();
    final primaryValue = colorScheme.primary.toARGB32();

    final shouldClearCache =
        (_cachedMarkerSurfaceColorValue != null &&
            _cachedMarkerSurfaceColorValue != surfaceValue) ||
        (_cachedMarkerPrimaryColorValue != null &&
            _cachedMarkerPrimaryColorValue != primaryValue);

    if (shouldClearCache) {
      _placeMarkerIconCache.clear();
      _placeMarkerIconPending.clear();
      _placeMarkerIconBuildQueue = Future.value();
      _forcePlaceMarkerIconRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _schedulePlaceMarkerSync();
        }
      });
    }

    _cachedMarkerSurfaceColorValue = surfaceValue;
    _cachedMarkerPrimaryColorValue = primaryValue;
  }

  @override
  void dispose() {
    // 한국어 주석: 리스너/컨트롤러 해제
    _recenterDebounceTimer?.cancel();
    _placeMarkerIconCache.clear();
    _placeMarkerIconPending.clear();
    _placeMarkerIconBuildQueue = Future.value();
    _pendingPlaceMarkerState = null;
    _placeMarkers.clear();
    if (_mapController != null && _lastTrackingMode != null) {
      _mapController!.setLocationTrackingMode(NLocationTrackingMode.none);
    }
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: const CommonAppBar(title: '지역정보'),
        drawer: AppDrawer(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 지도 프레임은 고정, 마커/바텀시트 데이터만 변경되도록 구성
            // hasLocation 변동(초기 null → 값 존재) 시에만 지도 위젯을 생성/교체
            Selector<RegionInfoViewModel, bool>(
              selector: (context, vm) => vm.hasLocation,
              builder: (context, hasLocation, _) {
                if (!hasLocation) {
                  return _buildEmptyState();
                }
                // hasLocation이 true로 변했을 때 한 번만 초기 중심을 사용
                final location = context
                    .read<RegionInfoViewModel>()
                    .currentLocation!;
                // 한국어 주석: 이미 초기 중심이 설정되어 있으면 갱신하지 않음 (지도 프레임 재초기화 방지)
                _initialCenter ??= LatLng(
                  location.latitude,
                  location.longitude,
                );
                return _buildPersistentMap(_initialCenter!);
              },
            ),

            // 한국어 주석: 선택된 장소 변경만 카메라 이동을 깨우도록 범위를 최소화합니다.
            Selector<RegionInfoViewModel, _SelectedPlaceCameraState>(
              selector: (context, vm) => _SelectedPlaceCameraState(
                selectedPlaceId: vm.selectedPlaceId,
                isLoading: vm.isLoading,
              ),
              builder: (context, state, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _handleSelectedPlaceCameraState(state);
                });
                return const SizedBox.shrink();
              },
            ),

            // 현재 위치 오버레이는 별도 경로로 가볍게 갱신
            Selector<RegionInfoViewModel, LocationModel?>(
              selector: (context, vm) => vm.currentLocation,
              builder: (context, state, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _syncLocationOverlay(state);
                });
                return const SizedBox.shrink();
              },
            ),

            // 장소 마커는 카메라 idle 또는 선택/목록 변경 시에만 증분 동기화
            Selector<RegionInfoViewModel, _PlaceMarkerState>(
              selector: (context, vm) => _PlaceMarkerState(
                selectedPlaces: vm.selectedPlaces,
                selectedPlaceId: vm.selectedPlaceId,
              ),
              builder: (context, state, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _schedulePlaceMarkerSync(state);
                });
                return const SizedBox.shrink();
              },
            ),

            // 한국어 주석: 음성 명령 FAB 버튼 (우측 하단)
            // - 지도 콘텐츠 위에 표시하되, 로딩/에러/바텀시트 오버레이보다 아래 레이어에 위치
            Positioned(
              right: 16,
              bottom: 16,
              child: VoiceCommandFAB(
                onGetQueryPrefix: () async {
                  final regionViewModel = context.read<RegionInfoViewModel>();
                  final location = regionViewModel.currentLocation;

                  if (location == null) {
                    return null; // 에러는 FAB 내부에서 처리
                  }

                  return '현재위치 ${location.latitude},${location.longitude}에서';
                },
                // 한국어 주석: 음성 응답 완료 시 지도에 마커 자동 표시
                onVoiceResponseComplete:
                    (metadata, {toolsUsed, originalQuery}) {
                      final regionViewModel = context
                          .read<RegionInfoViewModel>();
                      regionViewModel.showVoiceSearchResult(
                        metadata,
                        toolsUsed: toolsUsed,
                        originalQuery: originalQuery,
                      );
                    },
                // 한국어 주석: 바텀시트 닫힐 때 음성 검색 마커 초기화
                onBottomSheetClosed: () {
                  final regionViewModel = context.read<RegionInfoViewModel>();
                  regionViewModel.clearVoiceSearchMarker();
                },
              ),
            ),

            // 로딩/에러 오버레이 (LoadingErrorSelector)
            Selector<RegionInfoViewModel, LoadingErrorState>(
              selector: (context, viewModel) => LoadingErrorState(
                isLoading: viewModel.isLoading,
                hasLocation: viewModel.hasLocation,
                errorMessage: viewModel.errorMessage,
              ),
              builder: (context, state, child) {
                // 한국어 주석: 위치 초기 로딩 단계에서만 전체 스켈레톤 오버레이를 사용합니다.
                // 카테고리 조회 로딩 중에는 바텀시트 내부에서만 로딩 인디케이터를 보여,
                // 지도가 가려지지 않도록 합니다.
                if (state.isLoading && !state.hasLocation) {
                  return _buildLoadingSkeleton();
                }
                if (!state.isLoading && state.errorMessage != null) {
                  return _buildErrorOverlayWithState(context, state);
                }
                return const SizedBox.shrink();
              },
            ),

            // 카테고리 버튼 리스트 (CategorySelector)
            Selector<RegionInfoViewModel, _CategoryButtonsState>(
              // 한국어 주석: 버튼은 선택된 카테고리/위치 유무에만 의존하도록 선택 범위를 최소화
              selector: (context, viewModel) => _CategoryButtonsState(
                selectedCategoryId: viewModel.selectedCategoryId,
                hasLocation: viewModel.hasLocation,
              ),
              builder: (context, state, child) {
                if (state.hasLocation) {
                  return _buildCategoryButtons(
                    context,
                    state.selectedCategoryId,
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // GPS 버튼 (RefreshButtonSelector)
            // 장소 리스트 바텀시트 (BottomSheetSelector)
            // 한국어 주석: 시각적으로 바텀시트가 GPS 버튼을 덮을 수 있도록
            // 스택의 마지막(상단)에 위치시킵니다.
            Selector<RegionInfoViewModel, BottomSheetState>(
              selector: (context, viewModel) => BottomSheetState(
                showPlaceList: viewModel.showPlaceList,
                selectedCategoryId: viewModel.selectedCategoryId,
                selectedPlaces: viewModel.selectedPlaces,
                selectedPlaceId: viewModel.selectedPlaceId,
                shouldScrollToSelectedPlace:
                    viewModel.shouldScrollToSelectedPlace,
              ),
              builder: (context, state, child) {
                if (state.showPlaceList &&
                    state.selectedPlaces != null &&
                    state.selectedCategoryId != null) {
                  return _buildPlaceBottomSheetWithState(context, state);
                }
                return const SizedBox.shrink();
              },
            ),

            // 한국어 주석: 바텀시트 전환 감지 (카메라 자동 이동 없음)
            _listenBottomSheetToggle(),
          ],
        ),
      ),
    );
  }

  double get _mapUiBaseOffset =>
      _kLogoMarginBottom + _kLogoHeight + _kLocationButtonSpacing;

  // 한국어 주석: 바텀시트 전환 감지 (열릴 때 오프셋 정렬)
  Widget _listenBottomSheetToggle() {
    return Selector<RegionInfoViewModel, bool>(
      selector: (context, vm) => vm.showPlaceList,
      builder: (context, isOpen, _) {
        // 한국어 주석: 바텀시트가 '열릴 때' 현재 기준 위치를 남은 지도 영역 중앙에 배치
        final hasSelectedPlace =
            context.read<RegionInfoViewModel>().selectedPlaceId != null;

        if (!_wasBottomSheetOpen && isOpen && hasSelectedPlace) {
          _scheduleRecenterUpdate(animated: true);
        } else if (_wasBottomSheetOpen && !isOpen) {
          _bottomSheetFraction = 0.0;
          if (hasSelectedPlace) {
            _scheduleRecenterUpdate(animated: true);
          }
          _lastOffsetForRecenter = 0.0;
        }

        _updateMapContentPadding();
        _wasBottomSheetOpen = isOpen;
        return const SizedBox.shrink();
      },
    );
  }

  /// 바텀시트를 고려한 지도 중심 좌표 계산
  ///
  /// 바텀시트의 현재 점유 비율(fraction)에 따라 남은 지도 영역(상단)의
  /// 중앙에 마커가 오도록 오프셋을 적용합니다.
  Future<LatLng> _calculateOffsetCenter(LatLng target) async {
    if (_mapController == null) return target;

    // 바텀시트 표시 여부로 판단 (_bottomSheetFraction 타이밍 이슈 방지)
    final viewModel = context.read<RegionInfoViewModel>();
    if (_mapHeight <= 0 || !viewModel.showPlaceList) {
      return target;
    }

    // 한국어 주석: 지도 가시 영역(패딩 적용 영역)의 정중앙에 오도록,
    // 현재 적용된 패딩 기준 오프셋을 사용합니다.
    final offsetPixels = _currentOffsetPixels();
    if (offsetPixels <= 0) return target;

    try {
      return await offsetCenterByPixels(
        controller: _mapController!,
        target: target,
        offsetPixels: offsetPixels,
      );
    } catch (_) {
      return target;
    }
  }

  // 한국어 주석: 동일 프레임 안에서는 한 번만 지도 재배치를 수행해 불필요한 연속 이동을 방지
  void _scheduleRecenterUpdate({required bool animated}) {
    if (animated) {
      _pendingAnimatedRecenter = true;
    }

    if (_recenterFrameScheduled) return;
    _recenterFrameScheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _recenterFrameScheduled = false;
      if (!mounted) {
        _pendingAnimatedRecenter = false;
        return;
      }

      final bool shouldAnimate = _pendingAnimatedRecenter;
      _pendingAnimatedRecenter = false;
      await _recenterMapForBottomSheet(animated: shouldAnimate);
    });
  }

  // 한국어 주석: 현재 선택된 장소 혹은 사용자 위치를 기준으로 지도 중심을 보정
  Future<void> _recenterMapForBottomSheet({required bool animated}) async {
    if (_currentOffsetPixels() <= 0) return;

    final anchor = _resolveCurrentAnchor();
    if (anchor == null) return;

    final adjusted = await _calculateOffsetCenter(anchor);
    final currentZoom =
        _lastCameraPosition?.zoom ?? AppConstants.mapDefaultZoom;
    await _moveCamera(adjusted, zoom: currentZoom, animated: animated);
  }

  /// 네이버 지도 카메라 이동 공통 함수
  Future<void> _moveCamera(
    LatLng target, {
    double? zoom,
    bool animated = true,
  }) async {
    if (_mapController == null) return;

    await _prepareForAppOwnedCameraMove();

    final update = NCameraUpdate.scrollAndZoomTo(
      target: toNLatLng(target),
      zoom: zoom ?? _lastCameraPosition?.zoom ?? AppConstants.mapDefaultZoom,
    );
    update.setAnimation(
      animation: animated ? NCameraAnimation.easing : NCameraAnimation.none,
      duration: Duration(milliseconds: animated ? 400 : 0),
    );

    await _mapController!.updateCamera(update);
    _lastCameraPosition = _mapController!.nowCameraPosition;
  }

  Future<void> _prepareForAppOwnedCameraMove() async {
    if (!mounted || !_isMapReady || _mapController == null) return;

    final controller = _mapController!;
    await controller.cancelTransitions(reason: NCameraUpdateReason.developer);
    if (controller.locationTrackingMode != NLocationTrackingMode.noFollow) {
      controller.setLocationTrackingMode(NLocationTrackingMode.noFollow);
    }
    _lastTrackingMode = NLocationTrackingMode.noFollow;
  }

  void _normalizeGpsTrackingModeAfterTap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isMapReady || _mapController == null) return;

      final controller = _mapController!;
      final currentMode = controller.locationTrackingMode;
      if (currentMode == NLocationTrackingMode.face) {
        controller.setLocationTrackingMode(NLocationTrackingMode.follow);
        _lastTrackingMode = NLocationTrackingMode.follow;
      } else {
        _lastTrackingMode = currentMode;
      }
    });
  }

  // 한국어 주석: 선택된 장소가 있을 때만 해당 좌표를 기준으로 사용
  LatLng? _resolveCurrentAnchor() {
    final viewModel = context.read<RegionInfoViewModel>();

    if (viewModel.selectedPlaceId != null) {
      final List<PlaceModel>? places = viewModel.selectedPlaces;
      if (places != null && places.isNotEmpty) {
        for (final place in places) {
          if (place.id == viewModel.selectedPlaceId) {
            return LatLng(place.latitude, place.longitude);
          }
        }
      }
      // 한국어 주석: 선택된 장소 ID는 있으나 목록에서 찾지 못한 경우에는
      // 현재 위치가 있으면 이를 사용합니다.
    }

    final currentLocation = viewModel.currentLocation;
    if (currentLocation != null && viewModel.isTracking) {
      return LatLng(currentLocation.latitude, currentLocation.longitude);
    }

    return null;
  }

  // 한국어 주석: 바텀시트 기반 재센터링 목표가 있는지 여부를 빠르게 판단
  bool _hasRecenterAnchor() {
    final viewModel = context.read<RegionInfoViewModel>();
    if (viewModel.selectedPlaceId != null) {
      return true;
    }
    return viewModel.currentLocation != null && viewModel.isTracking;
  }

  void _handleSelectedPlaceCameraState(_SelectedPlaceCameraState state) {
    final selectedPlaceChanged =
        _previousSelectedPlaceId != state.selectedPlaceId;
    if (!selectedPlaceChanged) return;

    _previousSelectedPlaceId = state.selectedPlaceId;

    if (!state.isLoading && state.selectedPlaceId != null) {
      _moveToSelectedPlace(state.selectedPlaceId!);
    }
  }

  void _moveToSelectedPlace(String selectedPlaceId) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        final places = context.read<RegionInfoViewModel>().selectedPlaces;
        if (places == null) return;

        final selectedPlace = places.firstWhere(
          (place) => place.id == selectedPlaceId,
        );
        final currentZoom = _lastCameraPosition?.zoom ?? 15.0;
        final targetLatLng = LatLng(
          selectedPlace.latitude,
          selectedPlace.longitude,
        );
        final offsetLatLng = await _calculateOffsetCenter(targetLatLng);

        await _moveCamera(offsetLatLng, zoom: currentZoom, animated: true);
      } catch (_) {
        // 선택된 장소를 찾을 수 없습니다
      }
    });
  }

  /// 최신 상태를 반영한 장소 마커 스냅샷 생성
  _PlaceMarkerState _readPlaceMarkerState() {
    final vm = context.read<RegionInfoViewModel>();
    return _PlaceMarkerState(
      selectedPlaces: vm.selectedPlaces,
      selectedPlaceId: vm.selectedPlaceId,
    );
  }

  Future<void> _syncLocationOverlay(LocationModel? location) async {
    if (!_isMapReady || _mapController == null || location == null) return;

    final locationOverlay = _mapController!.getLocationOverlay();
    locationOverlay.setPosition(
      toNLatLng(LatLng(location.latitude, location.longitude)),
    );
  }

  void _schedulePlaceMarkerSync([_PlaceMarkerState? state]) {
    if (state != null) {
      _pendingPlaceMarkerState = state;
    }
    if (!_isMapReady || _mapController == null) return;

    if (_isSyncingPlaceMarkers) {
      _needsPlaceMarkerResync = true;
      return;
    }
    if (_placeMarkerSyncScheduled) return;

    _placeMarkerSyncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _placeMarkerSyncScheduled = false;
      if (!mounted) return;

      final nextState = _pendingPlaceMarkerState ?? _readPlaceMarkerState();
      _pendingPlaceMarkerState = null;
      await _syncPlaceMarkers(nextState);

      if (_needsPlaceMarkerResync) {
        _needsPlaceMarkerResync = false;
        _schedulePlaceMarkerSync();
      }
    });
  }

  /// 네이버 지도 장소 마커를 현재 상태에 맞게 증분 동기화
  Future<void> _syncPlaceMarkers(_PlaceMarkerState state) async {
    if (!_isMapReady || _mapController == null) return;
    _isSyncingPlaceMarkers = true;

    final places = state.selectedPlaces;
    final shouldForceIconRefresh = _forcePlaceMarkerIconRefresh;
    final colorScheme = Theme.of(context).colorScheme;

    try {
      if (places == null || places.isEmpty) {
        await _clearPlaceMarkers();
        _forcePlaceMarkerIconRefresh = false;
        return;
      }

      final visibleBounds = await _getVisibleBounds();
      final visiblePlaces = _filterPlacesByVisibleBounds(
        places,
        visibleBounds,
        state.selectedPlaceId,
      ).toList(growable: false);

      final nextSnapshots = <String, _PlaceMarkerSnapshot>{};
      for (final place in visiblePlaces) {
        nextSnapshots[place.id] = _PlaceMarkerSnapshot.fromPlace(
          place,
          isSelected: place.id == state.selectedPlaceId,
        );
      }

      final staleMarkerIds = _placeMarkers.keys
          .where((id) => !nextSnapshots.containsKey(id))
          .toList(growable: false);
      for (final markerId in staleMarkerIds) {
        final activeMarker = _placeMarkers.remove(markerId);
        if (activeMarker == null) continue;
        await _mapController!.deleteOverlay(activeMarker.marker.info);
      }

      for (final snapshot in nextSnapshots.values) {
        if (!mounted) return;

        final activeMarker = _placeMarkers[snapshot.placeId];
        if (activeMarker == null) {
          final marker = await _buildPlaceMarker(snapshot, colorScheme);
          await _mapController!.addOverlay(marker);
          _placeMarkers[snapshot.placeId] = _ActivePlaceMarker(
            marker: marker,
            snapshot: snapshot,
          );
          continue;
        }

        await _updatePlaceMarker(
          activeMarker,
          snapshot,
          colorScheme,
          forceIconRefresh: shouldForceIconRefresh,
        );
      }

      _forcePlaceMarkerIconRefresh = false;
    } finally {
      _isSyncingPlaceMarkers = false;
    }
  }

  Future<void> _clearPlaceMarkers() async {
    if (_mapController == null) return;

    final activeMarkers = _placeMarkers.values.toList(growable: false);
    _placeMarkers.clear();
    for (final activeMarker in activeMarkers) {
      await _mapController!.deleteOverlay(activeMarker.marker.info);
    }
  }

  Future<NMarker> _buildPlaceMarker(
    _PlaceMarkerSnapshot snapshot,
    ColorScheme colorScheme,
  ) async {
    final icon = await _getOrBuildPlaceMarkerIcon(
      snapshot.place,
      snapshot.isSelected,
      colorScheme,
    );
    final marker = NMarker(
      id: 'region_place_${snapshot.placeId}',
      position: toNLatLng(snapshot.coordinates),
      icon: icon,
      size: snapshot.size,
      anchor: NMarker.defaultAnchor,
    );
    marker.setGlobalZIndex(snapshot.isSelected ? 200001 : 200000);
    marker.setOnTapListener((_) {
      final vm = context.read<RegionInfoViewModel>();
      if (vm.selectedPlaceId == snapshot.placeId) {
        vm.clearSelectedPlace();
      } else {
        vm.selectPlace(snapshot.placeId, fromMap: true);
      }
    });
    return marker;
  }

  Future<void> _updatePlaceMarker(
    _ActivePlaceMarker activeMarker,
    _PlaceMarkerSnapshot nextSnapshot,
    ColorScheme colorScheme, {
    required bool forceIconRefresh,
  }) async {
    final previousSnapshot = activeMarker.snapshot;
    if (!forceIconRefresh && previousSnapshot == nextSnapshot) {
      return;
    }

    final marker = activeMarker.marker;
    if (previousSnapshot.latitude != nextSnapshot.latitude ||
        previousSnapshot.longitude != nextSnapshot.longitude) {
      marker.setPosition(toNLatLng(nextSnapshot.coordinates));
    }

    if (forceIconRefresh || !previousSnapshot.hasSameVisual(nextSnapshot)) {
      final icon = await _getOrBuildPlaceMarkerIcon(
        nextSnapshot.place,
        nextSnapshot.isSelected,
        colorScheme,
      );
      marker.setIcon(icon);
      marker.setSize(nextSnapshot.size);
    }

    if (previousSnapshot.isSelected != nextSnapshot.isSelected) {
      marker.setGlobalZIndex(nextSnapshot.isSelected ? 200001 : 200000);
    }

    _placeMarkers[nextSnapshot.placeId] = _ActivePlaceMarker(
      marker: marker,
      snapshot: nextSnapshot,
    );
  }

  Future<NOverlayImage> _getOrBuildPlaceMarkerIcon(
    PlaceModel place,
    bool isSelected,
    ColorScheme colorScheme,
  ) {
    final isVoiceMarker = place.id.startsWith('voice_');
    final markerHeight = isVoiceMarker ? 40.0 : (isSelected ? 70.0 : 60.0);
    final key = _PlaceMarkerIconCacheKey(
      placeId: place.id,
      placeName: place.name,
      categoryId: place.category,
      isSelected: isSelected,
      isVoiceMarker: isVoiceMarker,
      surfaceColorValue: colorScheme.surface.toARGB32(),
      primaryColorValue: colorScheme.primary.toARGB32(),
    );

    final cached = _placeMarkerIconCache.remove(key);
    if (cached != null) {
      _placeMarkerIconCache[key] = cached;
      return Future.value(cached);
    }

    final pending = _placeMarkerIconPending[key];
    if (pending != null) {
      return pending;
    }

    final buildFuture = _placeMarkerIconBuildQueue.then((_) async {
      if (!mounted) {
        throw StateError(
          'RegionInfoScreen disposed while marker icon building',
        );
      }

      final markerWidget = _buildPlaceMarkerWidget(
        place,
        isSelected,
        colorScheme,
      );
      final icon = await NOverlayImage.fromWidget(
        widget: markerWidget,
        size: Size(80, markerHeight),
        context: context,
      );

      _placeMarkerIconCache[key] = icon;
      _trimPlaceMarkerIconCache();
      await Future.delayed(_kPlaceMarkerIconBuildDelay);
      return icon;
    });

    _placeMarkerIconBuildQueue = buildFuture.then<void>(
      (_) {},
      onError: (error, stackTrace) {},
    );

    final tracked = buildFuture.whenComplete(() {
      _placeMarkerIconPending.remove(key);
    });
    _placeMarkerIconPending[key] = tracked;
    return tracked;
  }

  void _trimPlaceMarkerIconCache() {
    while (_placeMarkerIconCache.length > _kPlaceMarkerIconCacheLimit) {
      final oldestKey = _placeMarkerIconCache.keys.first;
      _placeMarkerIconCache.remove(oldestKey);
    }
  }

  // 한국어 주석: 현재 지도의 가시 영역(NLatLngBounds) 조회
  Future<NLatLngBounds?> _getVisibleBounds() async {
    if (_mapController == null) return null;
    try {
      return await _mapController!.getContentBounds(withPadding: true);
    } catch (_) {
      return null;
    }
  }

  // 한국어 주석: 선택된 장소는 항상 표시하고, 나머지는 가시 영역 내로 제한
  Iterable<PlaceModel> _filterPlacesByVisibleBounds(
    Iterable<PlaceModel> places,
    NLatLngBounds? bounds,
    String? selectedPlaceId,
  ) {
    if (bounds == null) return places;

    final sw = bounds.southWest;
    final ne = bounds.northEast;

    bool isInBounds(PlaceModel place) {
      final lat = place.latitude;
      final lon = place.longitude;
      return lat >= sw.latitude &&
          lat <= ne.latitude &&
          lon >= sw.longitude &&
          lon <= ne.longitude;
    }

    return places.where((place) {
      if (selectedPlaceId != null && place.id == selectedPlaceId) {
        return true;
      }
      return isInBounds(place);
    });
  }

  /// 장소 마커 위젯 생성 (기존 디자인 유지)
  Widget _buildPlaceMarkerWidget(
    PlaceModel place,
    bool isSelected,
    ColorScheme colorScheme,
  ) {
    // 한국어 주석: 음성 검색 마커 여부 (voice_로 시작하는 ID)
    final isVoiceMarker = place.id.startsWith('voice_');
    final markerSize = isSelected ? 40.0 : 30.0;
    final iconSize = isSelected ? 24.0 : 18.0;
    final borderWidth = isSelected ? 3.0 : 2.0;
    final textSize = isSelected ? 11.0 : 10.0;
    // 한국어 주석: 음성 검색 마커는 라벨을 숨기므로 전체 높이를 줄임
    final markerHeight = isVoiceMarker ? 40.0 : (isSelected ? 70.0 : 60.0);

    return SizedBox(
      width: 80,
      height: markerHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: markerSize,
            height: markerSize,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary,
                width: borderWidth,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              _getMarkerIconByCategory(place.category),
              color: colorScheme.primary,
              size: iconSize,
            ),
          ),
          // 한국어 주석: 음성 검색 마커는 메타데이터에 정확한 장소명이 없으므로 라벨 숨김
          if (!isVoiceMarker) ...[
            const SizedBox(height: 4),
            Text(
              place.name,
              style: TextStyle(
                fontSize: textSize,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontFamily: AppConstants.fontFamilySmall,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getMarkerIconByCategory(String categoryId) {
    final category = AppConstants.placeCategories.firstWhere(
      (cat) => cat['id'] == categoryId,
      orElse: () => {'id': '', 'icon': Icons.place},
    );
    return category['icon'] as IconData;
  }

  // 한국어 주석: fitBounds 기능은 제거했습니다. 필요 시 별도 버튼/동작으로 제공하세요.

  /// 지도 표시 (지도의 프레임은 고정, 내부 레이어만 상태에 반응)
  Widget _buildPersistentMap(LatLng center) {
    // 한국어 주석: 지도 컨테이너의 실제 크기를 측정하여 바텀시트 오프셋 계산에 사용
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _mapContainerKey.currentContext;
      if (ctx != null) {
        final renderBox = ctx.findRenderObject();
        if (renderBox is RenderBox) {
          final newHeight = renderBox.size.height;
          if (newHeight > 0 && newHeight != _mapHeight) {
            setState(() {
              _mapHeight = newHeight;
            });
            _updateMapContentPadding();
          }
        }
      }
    });

    final contentPadding = EdgeInsets.only(bottom: _mapContentPaddingBottom);

    return Container(
      key: _mapContainerKey,
      // 한국어 주석: 지도는 자체 레이어로 분리하여 바텀시트 드래그 중 불필요한 리페인트를 방지
      child: RepaintBoundary(
        child: Stack(
          children: [
            NaverMap(
              // Android에서 Texture 기반 PlatformView 사용 시 ImageReader 버퍼 경고가
              // 반복되는 단말이 있어 Hybrid Composition을 강제합니다.
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: toNLatLng(center),
                  zoom: AppConstants.mapDefaultZoom,
                ),
                indoorEnable: true,
                // 한국어 주석: 지도 하단 패딩은 바텀시트 최종 높이에 맞춰서만 조정합니다.
                contentPadding: contentPadding,
              ),
              onMapReady: (controller) async {
                if (!mounted) return;

                setState(() {
                  _mapController = controller;
                  _isMapReady = true;
                  _lastCameraPosition = controller.nowCameraPosition;
                });
                controller.setLocationTrackingMode(
                  NLocationTrackingMode.noFollow,
                );
                _lastTrackingMode = NLocationTrackingMode.noFollow;

                await _syncLocationOverlay(
                  context.read<RegionInfoViewModel>().currentLocation,
                );
                _schedulePlaceMarkerSync(_readPlaceMarkerState());
              },
              onCameraIdle: () async {
                if (!mounted || _mapController == null) return;

                _lastCameraPosition = await _mapController!.getCameraPosition();
                _schedulePlaceMarkerSync();
              },
            ),

            if (_isMapReady && _mapController != null)
              Positioned(
                left: 14,
                bottom: 44 + _mapContentPaddingBottom,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerUp: (_) => _normalizeGpsTrackingModeAfterTap(),
                  child: NMyLocationButtonWidget(
                    mapController: _mapController!,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

  /// 카테고리 버튼 리스트 (버튼은 카테고리 선택 상태만 반응)
  Widget _buildCategoryButtons(
    BuildContext context,
    String? selectedCategoryId,
  ) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: AppConstants.placeCategories.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = AppConstants.placeCategories[index];
            final categoryId = category['id'] as String;
            final categoryName = category['name'] as String;
            final categoryIcon = category['icon'] as IconData;
            final isSelected = selectedCategoryId == categoryId;

            return CategoryIslandButton(
              categoryId: categoryId,
              categoryName: categoryName,
              categoryIcon: categoryIcon,
              isSelected: isSelected,
              onTap: () {
                context.read<RegionInfoViewModel>().selectCategory(categoryId);
              },
            );
          },
        ),
      ),
    );
  }

  /// 장소 바텀시트 빌더 (BottomSheetState 사용)
  Widget _buildPlaceBottomSheetWithState(
    BuildContext context,
    BottomSheetState state,
  ) {
    // 카테고리명 가져오기
    final category = AppConstants.placeCategories.firstWhere(
      (cat) => cat['id'] == state.selectedCategoryId,
    );
    final categoryName = category['name'] as String;

    // 한국어 주석: 페이지네이션 상태를 ViewModel에서 가져옴
    final viewModel = context.read<RegionInfoViewModel>();

    return PlaceListBottomSheet(
      categoryName: categoryName,
      places: state.selectedPlaces!,
      shouldScrollToSelectedPlace: state.shouldScrollToSelectedPlace,
      // 한국어 주석: 바텀시트 점유 비율을 수신하여 지도 오프셋 계산에 사용
      selectedPlaceId: state.selectedPlaceId,
      onExtentChanged: _handleBottomSheetExtentChanged,
      // 페이지네이션 상태
      hasMore: viewModel.hasMorePlaces,
      isLoadingMore: viewModel.isLoadingMore,
    );
  }

  // 한국어 주석: 바텀시트 확장 비율 변경 시 지도 중앙 보정을 처리
  // 성능 최적화: Throttle (드래그 중) + Debounce (완료 시)
  void _handleBottomSheetExtentChanged(double fraction, bool isFinalExtent) {
    _bottomSheetFraction = fraction;
    if (isFinalExtent) {
      _updateMapContentPadding();
    }

    if (_kVisibleOffsetRatio <= 0) {
      _lastOffsetForRecenter = _currentOffsetPixels();
      return;
    }

    final nextOffset = _currentOffsetPixels();
    final offsetChanged =
        (nextOffset - _lastOffsetForRecenter).abs() >= _kRecenterOffsetEpsilon;

    // 한국어 주석: 재센터링 조건 검사 (앵커 존재 & 오프셋 변경)
    if (!_hasRecenterAnchor() || !offsetChanged) {
      _lastOffsetForRecenter = nextOffset;
      return;
    }

    if (isFinalExtent) {
      // 한국어 주석: 드래그 완료 시 - Debounce 적용
      // 200ms 대기 후 최종 위치로 부드럽게 이동 (정확도 우선)
      _recenterDebounceTimer?.cancel();
      _recenterDebounceTimer = Timer(_kRecenterDebounce, () {
        if (!mounted) return;
        _scheduleRecenterUpdate(animated: true);
      });
    } else {
      // 한국어 주석: 드래그 중 - Throttle 적용
      // 100ms 간격으로만 업데이트하여 성능 향상 (실시간성 유지)
      final now = DateTime.now();
      if (now.difference(_lastRecenterTime) >= _kRecenterThrottle) {
        _scheduleRecenterUpdate(animated: false); // 애니메이션 비활성화
        _lastRecenterTime = now;
      }
    }

    _lastOffsetForRecenter = nextOffset;
  }

  // 한국어 주석: 지도 UI 패딩을 바텀시트 높이에 맞춰 갱신
  void _updateMapContentPadding() {
    if (!mounted) return;

    final nextPadding = _calculateMapContentPadding();
    _desiredContentPaddingBottom = nextPadding;

    if (_mapPaddingUpdateScheduled) {
      return;
    }
    _mapPaddingUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapPaddingUpdateScheduled = false;
      if (!mounted) return;
      if ((_desiredContentPaddingBottom - _mapContentPaddingBottom).abs() <
          _kMapPaddingEpsilon) {
        return;
      }
      setState(() {
        _mapContentPaddingBottom = _desiredContentPaddingBottom;
      });
    });
  }

  // 한국어 주석: GPS 버튼/스케일바가 바텀시트 위에 머물도록 패딩 계산
  double _calculateMapContentPadding() {
    if (_mapHeight <= 0) return 0.0;

    final viewModel = context.read<RegionInfoViewModel>();
    if (!viewModel.showPlaceList) {
      return 0.0;
    }

    final bottomSheetHeight = _effectiveBottomSheetHeight();
    final targetOffset = bottomSheetHeight + _kGpsButtonGap;
    final padding = targetOffset - _mapUiBaseOffset;

    if (padding <= 0) return 0.0;
    if (padding >= _mapHeight) return _mapHeight;
    return padding;
  }

  // 한국어 주석: 현재 바텀시트 점유 높이 계산 (초기 크기 폴백 포함)
  double _effectiveBottomSheetHeight() {
    final fraction = (_bottomSheetFraction > 0)
        ? _bottomSheetFraction
        : kPlaceListInitialChildSize;
    return _mapHeight * fraction;
  }

  // 한국어 주석: 지도 가시 영역 중앙을 맞추기 위한 현재 오프셋 픽셀값
  double _currentOffsetPixels() {
    if (_mapHeight <= 0) return 0.0;

    final paddingBasedOffset =
        (_mapContentPaddingBottom / 2.0) * _kVisibleOffsetRatio;
    if (paddingBasedOffset > 0) {
      return paddingBasedOffset;
    }

    final bottomSheetHeight = _effectiveBottomSheetHeight();
    if (bottomSheetHeight <= 0) return 0.0;

    return (bottomSheetHeight / 2.0) * _kVisibleOffsetRatio;
  }

  /// 에러 오버레이 (LoadingErrorState 사용)
  Widget _buildErrorOverlayWithState(
    BuildContext context,
    LoadingErrorState state,
  ) {
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
                        context.read<RegionInfoViewModel>().initialize(
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
}

/// 장소 마커 동기화 상태
class _PlaceMarkerState extends Equatable {
  final List<PlaceModel>? selectedPlaces;
  final String? selectedPlaceId;

  const _PlaceMarkerState({
    required this.selectedPlaces,
    required this.selectedPlaceId,
  });

  @override
  List<Object?> get props => [selectedPlaces, selectedPlaceId];
}

class _SelectedPlaceCameraState extends Equatable {
  final String? selectedPlaceId;
  final bool isLoading;

  const _SelectedPlaceCameraState({
    required this.selectedPlaceId,
    required this.isLoading,
  });

  @override
  List<Object?> get props => [selectedPlaceId, isLoading];
}

class _ActivePlaceMarker {
  final NMarker marker;
  final _PlaceMarkerSnapshot snapshot;

  const _ActivePlaceMarker({required this.marker, required this.snapshot});
}

class _PlaceMarkerSnapshot extends Equatable {
  final PlaceModel place;
  final String placeId;
  final String placeName;
  final String categoryId;
  final double latitude;
  final double longitude;
  final bool isSelected;
  final bool isVoiceMarker;

  const _PlaceMarkerSnapshot({
    required this.place,
    required this.placeId,
    required this.placeName,
    required this.categoryId,
    required this.latitude,
    required this.longitude,
    required this.isSelected,
    required this.isVoiceMarker,
  });

  factory _PlaceMarkerSnapshot.fromPlace(
    PlaceModel place, {
    required bool isSelected,
  }) {
    return _PlaceMarkerSnapshot(
      place: place,
      placeId: place.id,
      placeName: place.name,
      categoryId: place.category,
      latitude: place.latitude,
      longitude: place.longitude,
      isSelected: isSelected,
      isVoiceMarker: place.id.startsWith('voice_'),
    );
  }

  LatLng get coordinates => LatLng(latitude, longitude);
  double get markerHeight => isVoiceMarker ? 40.0 : (isSelected ? 70.0 : 60.0);
  Size get size => Size(80, markerHeight);

  bool hasSameVisual(_PlaceMarkerSnapshot other) {
    return placeName == other.placeName &&
        categoryId == other.categoryId &&
        isSelected == other.isSelected &&
        isVoiceMarker == other.isVoiceMarker;
  }

  @override
  List<Object?> get props => [
    placeId,
    placeName,
    categoryId,
    latitude,
    longitude,
    isSelected,
    isVoiceMarker,
  ];
}

class _PlaceMarkerIconCacheKey extends Equatable {
  final String placeId;
  final String placeName;
  final String categoryId;
  final bool isSelected;
  final bool isVoiceMarker;
  final int surfaceColorValue;
  final int primaryColorValue;

  const _PlaceMarkerIconCacheKey({
    required this.placeId,
    required this.placeName,
    required this.categoryId,
    required this.isSelected,
    required this.isVoiceMarker,
    required this.surfaceColorValue,
    required this.primaryColorValue,
  });

  @override
  List<Object?> get props => [
    placeId,
    placeName,
    categoryId,
    isSelected,
    isVoiceMarker,
    surfaceColorValue,
    primaryColorValue,
  ];
}

/// 한국어 주석: 카테고리 버튼 전용 상태 (불필요한 빌드를 막기 위해 최소 필드만 포함)
class _CategoryButtonsState extends Equatable {
  final String? selectedCategoryId;
  final bool hasLocation;

  const _CategoryButtonsState({
    required this.selectedCategoryId,
    required this.hasLocation,
  });

  @override
  List<Object?> get props => [selectedCategoryId, hasLocation];
}
