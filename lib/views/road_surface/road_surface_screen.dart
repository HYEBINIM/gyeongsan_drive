import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/location_model.dart';
import '../../models/road_condition_model.dart';
import '../../view_models/road_surface/road_surface_viewmodel.dart';
import '../../widgets/common/common_app_bar.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/shimmer_wrapper.dart';
import '../../widgets/road_surface/road_condition_detail_sheet.dart';
import '../../utils/constants.dart';
import '../../utils/naver_map_utils.dart';

/// 노면 정보 화면
/// 네이버 지도에 도로 위험 상태 마커를 표시하고
/// 마커 클릭 시 상세 정보와 이미지를 표시
class RoadSurfaceScreen extends StatefulWidget {
  const RoadSurfaceScreen({super.key});

  @override
  State<RoadSurfaceScreen> createState() => _RoadSurfaceScreenState();
}

class _RoadSurfaceScreenState extends State<RoadSurfaceScreen> {
  NaverMapController? _mapController;
  bool _isMapReady = false;
  NLocationTrackingMode? _lastTrackingMode;
  // 한국어 주석: 마지막으로 동기화된 조건 목록의 길이를 추적하여 변경 감지
  int _lastSyncedConditionsCount = -1;
  // 한국어 주석: 마커 동기화의 중복/경쟁 상태를 방지하기 위한 플래그
  bool _isSyncingMarkers = false;
  bool _isMarkerSyncScheduled = false;
  bool _isPrefetchScheduled = false;
  // 한국어 주석: 프리패치 배치 크기 증가 (6 → 12) - 더 많은 이미지 선제 로딩
  static const int _prefetchBatchSize = 12;
  final Set<String> _prefetchedConditionIds = {};
  // 한국어 주석: 최초 1회, 마커가 화면에 보이도록 카메라를 보정했는지 여부
  bool _didEnsureMarkersVisible = false;
  // 한국어 주석: fromWidget 기반 마커 아이콘은 선택 상태/테마/크기만으로 결정되므로 캐싱하여 성능/안정성 개선
  final Map<_RoadConditionMarkerIconCacheKey, NOverlayImage> _markerIconCache =
      {};
  // 한국어 주석: ImageReader 버퍼 회수 시간을 확보하기 위한 최소 간격 (Android ImageReader maxImages 제한 대응)
  static const Duration _markerIconBuildDelay = Duration(milliseconds: 150);
  // 한국어 주석: 동시 마커 아이콘 빌드 방지를 위한 락
  static bool _isMarkerIconBuilding = false;
  // 한국어 주석: 배치당 처리할 마커 수 (ImageReader 버퍼 부담 완화)
  static const int _markerBuildBatchSize = 3;
  int? _cachedSurfaceColorValue;

  @override
  void initState() {
    super.initState();
    // ViewModel 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoadSurfaceViewModel>().initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final surfaceValue = Theme.of(context).colorScheme.surface.toARGB32();
    if (_cachedSurfaceColorValue != null &&
        _cachedSurfaceColorValue != surfaceValue) {
      _markerIconCache.clear();
    }
    _cachedSurfaceColorValue = surfaceValue;
  }

  @override
  void dispose() {
    // 위치 추적 모드를 먼저 비활성화하여 ImageReader 버퍼 누수 방지
    if (_mapController != null && _lastTrackingMode != null) {
      _mapController!.setLocationTrackingMode(NLocationTrackingMode.none);
    }
    _lastTrackingMode = null;
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: const CommonAppBar(title: '노면정보'),
        drawer: AppDrawer(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 한국어 주석: 로딩/에러/빈 상태 처리 (최소 상태만 구독)
            Selector<RoadSurfaceViewModel, _RoadSurfaceLoadingState>(
              selector: (context, vm) => _RoadSurfaceLoadingState(
                isLoading: vm.isLoading,
                hasLocation: vm.hasLocation,
                errorMessage: vm.errorMessage,
              ),
              builder: (context, state, _) {
                if (state.isLoading) {
                  return _buildLoadingSkeleton();
                }
                if (state.errorMessage != null) {
                  return _buildErrorStateFromMessage(state.errorMessage!);
                }
                if (!state.hasLocation) {
                  return _buildEmptyState();
                }
                return const SizedBox.shrink();
              },
            ),

            // 한국어 주석: 지도 위젯 (위치 정보가 있을 때만 표시)
            Selector<RoadSurfaceViewModel, bool>(
              selector: (context, vm) => vm.hasLocation,
              builder: (context, hasLocation, _) {
                if (!hasLocation) {
                  return const SizedBox.shrink();
                }
                final location = context
                    .read<RoadSurfaceViewModel>()
                    .currentLocation!;
                return _buildMap(location);
              },
            ),

            // 한국어 주석: 마커 동기화 (조건 목록 변경 시에만 반응)
            Selector<RoadSurfaceViewModel, List<RoadConditionModel>>(
              selector: (context, vm) => vm.roadConditions,
              builder: (context, conditions, _) {
                _scheduleMarkerSyncIfNeeded(conditions);
                return const SizedBox.shrink();
              },
            ),

            // 한국어 주석: 로딩 중 표시 (도로 상태 정보 로딩)
            Selector<RoadSurfaceViewModel, bool>(
              selector: (context, vm) => vm.isLoadingConditions,
              builder: (context, isLoadingConditions, _) {
                if (!isLoadingConditions) {
                  return const SizedBox.shrink();
                }
                return _buildLoadingIndicator();
              },
            ),

            // 한국어 주석: 마커 개수 표시
            Selector<RoadSurfaceViewModel, _RoadSurfaceConditionsState>(
              selector: (context, vm) => _RoadSurfaceConditionsState(
                isLoadingConditions: vm.isLoadingConditions,
                conditionsCount: vm.roadConditions.length,
              ),
              builder: (context, state, _) {
                if (state.isLoadingConditions || state.conditionsCount == 0) {
                  return const SizedBox.shrink();
                }
                return _buildConditionsCountBadge(state.conditionsCount);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 지도 표시 (위치 정보를 직접 받아 지도 프레임 재생성 최소화)
  Widget _buildMap(LocationModel location) {
    final center = LatLng(location.latitude, location.longitude);

    return RepaintBoundary(
      child: Stack(
        children: [
          NaverMap(
            // Android에서 Texture 기반 PlatformView는 ImageReader 버퍼 경고가 반복될 수 있어
            // Hybrid Composition을 강제로 사용해 로그/버퍼 문제를 완화합니다.
            // ignore: invalid_use_of_visible_for_testing_member
            forceHybridComposition: true,
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: toNLatLng(center),
                zoom: AppConstants.mapDefaultZoom,
              ),
              indoorEnable: true,
            ),
            onMapReady: (controller) async {
              if (!mounted) return;

              setState(() {
                _mapController = controller;
                _isMapReady = true;
              });

              // 위치 오버레이 표시 (카메라 자동 추적 비활성화 - 마커 영역 우선)
              controller.setLocationTrackingMode(
                NLocationTrackingMode.noFollow,
              );
              _lastTrackingMode = NLocationTrackingMode.noFollow;

              // 현재 위치 오버레이 설정
              final locationOverlay = controller.getLocationOverlay();
              locationOverlay.setPosition(toNLatLng(center));

              // 한국어 주석: 초기 데이터가 이미 로드된 경우 즉시 동기화 시도
              final conditions = context
                  .read<RoadSurfaceViewModel>()
                  .roadConditions;
              _scheduleMarkerSyncIfNeeded(conditions);
            },
            onCameraIdle: () {
              if (!mounted) return;
              final conditions = context
                  .read<RoadSurfaceViewModel>()
                  .roadConditions;
              _scheduleImagePrefetchIfNeeded(conditions);
            },
          ),

          // GPS 버튼
          if (_isMapReady && _mapController != null)
            Positioned(
              left: 14,
              bottom: 60,
              child: NMyLocationButtonWidget(mapController: _mapController!),
            ),
        ],
      ),
    );
  }

  /// 로딩 중 표시 위젯
  Widget _buildLoadingIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '노면 정보 로딩 중...',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 마커 개수 표시 위젯
  Widget _buildConditionsCountBadge(int count) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              '$count건',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleMarkerSyncIfNeeded(List<RoadConditionModel> conditions) {
    if (!_isMapReady || _mapController == null) return;
    if (_isSyncingMarkers || _isMarkerSyncScheduled) return;
    if (conditions.length == _lastSyncedConditionsCount) return;

    _isMarkerSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _isMarkerSyncScheduled = false;
      await _syncMarkers(conditions);
    });
  }

  /// 마커 동기화
  Future<void> _syncMarkers(List<RoadConditionModel> conditions) async {
    if (!_isMapReady || _mapController == null) return;
    if (_isSyncingMarkers) return;
    _isSyncingMarkers = true;

    try {
      // 기존 마커 제거
      await _mapController!.clearOverlays();

      // 새 마커 추가 (한국어 주석: 배치 처리로 ImageReader 버퍼 부담 완화)
      final overlays = <NAddableOverlay>{};

      // 한국어 주석: 배치 단위로 마커를 생성하고, 배치 사이에 딜레이를 줌
      for (var i = 0; i < conditions.length; i += _markerBuildBatchSize) {
        if (!mounted) return;

        final batchEnd = (i + _markerBuildBatchSize < conditions.length)
            ? i + _markerBuildBatchSize
            : conditions.length;
        final batch = conditions.sublist(i, batchEnd);

        for (final condition in batch) {
          final marker = await _buildConditionMarker(condition);
          overlays.add(marker);
        }

        // 한국어 주석: 배치 간 딜레이로 ImageReader 버퍼 회수 시간 확보
        if (batchEnd < conditions.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (overlays.isNotEmpty && mounted) {
        await _mapController!.addOverlayAll(overlays);
      }

      // 한국어 주석: 동기화 성공 시에만 마지막 동기화 카운트를 갱신
      _lastSyncedConditionsCount = conditions.length;

      // 한국어 주석: 최초 1회, 마커가 현재 화면에 하나도 없으면 자동으로 마커 영역으로 이동
      if (!_didEnsureMarkersVisible && conditions.isNotEmpty) {
        _didEnsureMarkersVisible = true;
        await _ensureMarkersVisible(conditions);
      }

      // 한국어 주석: 마커가 화면에 표시된 시점에 맞춰 가시 영역 우선으로 이미지 프리패치
      _scheduleImagePrefetchIfNeeded(conditions);
    } catch (_) {
      // 한국어 주석: 동기화 실패 시 다음 빌드에서 재시도할 수 있도록 카운트를 유지하지 않습니다.
      _lastSyncedConditionsCount = -1;
    } finally {
      _isSyncingMarkers = false;
    }
  }

  void _scheduleImagePrefetchIfNeeded(List<RoadConditionModel> conditions) {
    if (!_isMapReady || _mapController == null) return;
    if (_isPrefetchScheduled) return;
    if (conditions.isEmpty) return;

    _isPrefetchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _isPrefetchScheduled = false;
      await _prefetchVisibleConditions(conditions);
    });
  }

  Future<void> _prefetchVisibleConditions(
    List<RoadConditionModel> conditions,
  ) async {
    if (!mounted || _mapController == null || conditions.isEmpty) return;

    NLatLngBounds? bounds;
    try {
      bounds = await _mapController!.getContentBounds(withPadding: true);
    } catch (_) {
      bounds = null;
    }
    if (!mounted) return;

    List<RoadConditionModel> candidates;
    if (bounds == null) {
      candidates = conditions;
    } else {
      final sw = bounds.southWest;
      final ne = bounds.northEast;

      bool isInBounds(RoadConditionModel condition) {
        final lat = condition.latitude;
        final lon = condition.longitude;
        return lat >= sw.latitude &&
            lat <= ne.latitude &&
            lon >= sw.longitude &&
            lon <= ne.longitude;
      }

      candidates = conditions.where(isInBounds).toList();
      if (candidates.isEmpty) {
        candidates = conditions;
      }
    }

    // 한국어 주석: 아직 프리패치되지 않은 조건만 필터링
    final toPrefetch = <RoadConditionModel>[];
    for (final condition in candidates.take(_prefetchBatchSize)) {
      if (_prefetchedConditionIds.add(condition.id)) {
        toPrefetch.add(condition);
      }
    }

    // 한국어 주석: URL 해석을 병렬로 수행하여 프리패치 속도 향상
    if (toPrefetch.isNotEmpty) {
      RoadConditionDetailSheet.prefetchImagesBatch(context, toPrefetch);
    }
  }

  Future<void> _ensureMarkersVisible(
    List<RoadConditionModel> conditions,
  ) async {
    if (_mapController == null || conditions.isEmpty) return;

    late final NLatLngBounds visibleBounds;
    try {
      visibleBounds = await _mapController!.getContentBounds(withPadding: true);
    } catch (_) {
      return;
    }

    final sw = visibleBounds.southWest;
    final ne = visibleBounds.northEast;

    bool isInBounds(RoadConditionModel condition) {
      final lat = condition.latitude;
      final lon = condition.longitude;
      return lat >= sw.latitude &&
          lat <= ne.latitude &&
          lon >= sw.longitude &&
          lon <= ne.longitude;
    }

    final hasVisibleMarker = conditions.any(isInBounds);
    if (hasVisibleMarker) return;

    // 한국어 주석: 위치 추적 모드가 follow이면 카메라 이동이 즉시 되돌려질 수 있어 해제
    _mapController!.setLocationTrackingMode(NLocationTrackingMode.none);
    _lastTrackingMode = NLocationTrackingMode.none;

    final points = conditions
        .map((c) => LatLng(c.latitude, c.longitude))
        .toList();
    if (points.isEmpty) return;

    final bounds = buildBoundsFromPoints(points);
    final update = NCameraUpdate.fitBounds(
      bounds,
      padding: const EdgeInsets.all(64),
    );
    update.setAnimation(
      animation: NCameraAnimation.easing,
      duration: const Duration(milliseconds: 500),
    );
    await _mapController!.updateCamera(update);
  }

  /// 도로 상태 마커 생성
  Future<NMarker> _buildConditionMarker(RoadConditionModel condition) async {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected =
        context.read<RoadSurfaceViewModel>().selectedCondition?.id ==
        condition.id;

    final markerSize = isSelected ? 44.0 : 36.0;
    NOverlayImage? icon;
    try {
      icon = await _getMarkerIcon(
        isSelected: isSelected,
        colorScheme: colorScheme,
        markerSize: markerSize,
      );
    } catch (_) {
      icon = null;
    }

    final marker = NMarker(
      id: 'road_condition_${condition.id}',
      position: NLatLng(condition.latitude, condition.longitude),
      icon: icon,
      size: Size(markerSize, markerSize),
      anchor: const NPoint(0.5, 0.5),
    );

    // 한국어 주석: 커스텀 아이콘 생성 실패 시 기본 마커를 주황색으로 틴팅하여 가시성 확보
    if (icon == null) {
      marker.setIconTintColor(Colors.orange);
    }

    // 마커 탭 리스너
    marker.setOnTapListener((_) {
      _onMarkerTapped(condition);
      return true;
    });

    return marker;
  }

  Future<NOverlayImage> _getMarkerIcon({
    required bool isSelected,
    required ColorScheme colorScheme,
    required double markerSize,
  }) async {
    final key = _RoadConditionMarkerIconCacheKey(
      isSelected: isSelected,
      surfaceColorValue: colorScheme.surface.toARGB32(),
      markerSize: markerSize.round(),
    );
    final cached = _markerIconCache[key];
    if (cached != null) return cached;

    // 한국어 주석: 동시 호출 방지 - 다른 빌드가 완료될 때까지 대기
    while (_isMarkerIconBuilding) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    // 한국어 주석: 대기 후 캐시 재확인 (다른 호출이 같은 아이콘을 이미 빌드했을 수 있음)
    final cachedAfterWait = _markerIconCache[key];
    if (cachedAfterWait != null) return cachedAfterWait;

    _isMarkerIconBuilding = true;
    try {
      // 한국어 주석: async gap 이후 mounted 체크
      if (!mounted) {
        throw StateError('Widget disposed during marker icon build');
      }

      final markerWidget = _buildMarkerWidget(
        isSelected: isSelected,
        colorScheme: colorScheme,
      );

      final icon = await NOverlayImage.fromWidget(
        widget: markerWidget,
        size: Size(markerSize, markerSize),
        context: context,
      );
      _markerIconCache[key] = icon;
      // 한국어 주석: fromWidget 호출 후 ImageReader 버퍼 GC 시간 확보
      await Future.delayed(_markerIconBuildDelay);
      return icon;
    } finally {
      _isMarkerIconBuilding = false;
    }
  }

  /// 마커 위젯 생성
  /// 한국어 주석: 모든 노면 위험 마커를 동일한 디자인(주황색 경고 아이콘)으로 표시
  Widget _buildMarkerWidget({
    required bool isSelected,
    required ColorScheme colorScheme,
  }) {
    final size = isSelected ? 44.0 : 36.0;
    final iconSize = isSelected ? 24.0 : 20.0;
    final borderWidth = isSelected ? 3.0 : 2.0;
    const dangerColor = Colors.orange;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: dangerColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: dangerColor.withValues(alpha: isSelected ? 0.4 : 0.3),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.warning_amber_rounded,
        color: dangerColor,
        size: iconSize,
      ),
    );
  }

  /// 마커 탭 핸들러
  /// 한국어 주석: 전체 마커 재동기화를 피하고 개별 마커만 업데이트하여
  /// ImageReader 버퍼 초과 문제를 방지합니다.
  void _onMarkerTapped(RoadConditionModel condition) {
    final viewModel = context.read<RoadSurfaceViewModel>();
    final previousSelectedId = viewModel.selectedCondition?.id;

    // 한국어 주석: 선택 상태 변경 (notifyListeners 호출되지만 Selector로 인해 마커 재생성 안 함)
    viewModel.selectCondition(condition);

    // 한국어 주석: 개별 마커 스타일만 업데이트 (전체 재생성 대신)
    _updateMarkerSelectionStyle(
      previousSelectedId: previousSelectedId,
      newSelectedId: condition.id,
    );

    // 바텀시트 표시
    RoadConditionDetailSheet.show(
      context,
      condition: condition,
      onClose: () {
        final currentSelectedId = viewModel.selectedCondition?.id;
        viewModel.clearSelection();
        // 한국어 주석: 개별 마커만 선택 해제 스타일로 업데이트
        _updateMarkerSelectionStyle(
          previousSelectedId: currentSelectedId,
          newSelectedId: null,
        );
      },
    );

    // 선택된 마커로 카메라 이동
    if (_mapController != null) {
      final update = NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(condition.latitude, condition.longitude),
      );
      update.setAnimation(
        animation: NCameraAnimation.easing,
        duration: const Duration(milliseconds: 300),
      );
      _mapController!.updateCamera(update);
    }
  }

  /// 개별 마커의 선택 스타일만 업데이트 (전체 재동기화 대신)
  /// 한국어 주석: fromWidget 호출을 최소화하여 ImageReader 버퍼 부담을 줄입니다.
  Future<void> _updateMarkerSelectionStyle({
    required String? previousSelectedId,
    required String? newSelectedId,
  }) async {
    if (_mapController == null || !mounted) return;

    final colorScheme = Theme.of(context).colorScheme;
    final conditions = context.read<RoadSurfaceViewModel>().roadConditions;

    // 한국어 주석: 이전 선택된 마커를 비선택 상태로 변경
    if (previousSelectedId != null && previousSelectedId != newSelectedId) {
      final previousCondition = conditions.firstWhere(
        (c) => c.id == previousSelectedId,
        orElse: () => conditions.first,
      );
      if (previousCondition.id == previousSelectedId) {
        await _updateSingleMarker(
          previousCondition,
          isSelected: false,
          colorScheme: colorScheme,
        );
      }
    }

    // 한국어 주석: 새로 선택된 마커를 선택 상태로 변경
    if (newSelectedId != null) {
      final newCondition = conditions.firstWhere(
        (c) => c.id == newSelectedId,
        orElse: () => conditions.first,
      );
      if (newCondition.id == newSelectedId) {
        await _updateSingleMarker(
          newCondition,
          isSelected: true,
          colorScheme: colorScheme,
        );
      }
    }
  }

  /// 단일 마커 업데이트 (기존 마커 제거 후 새 마커 추가)
  Future<void> _updateSingleMarker(
    RoadConditionModel condition, {
    required bool isSelected,
    required ColorScheme colorScheme,
  }) async {
    if (_mapController == null || !mounted) return;

    final markerId = 'road_condition_${condition.id}';

    // 한국어 주석: 기존 마커 제거
    try {
      await _mapController!.deleteOverlay(
        NOverlayInfo(type: NOverlayType.marker, id: markerId),
      );
    } catch (_) {
      // 마커가 없을 수 있음
    }

    // 한국어 주석: 새 스타일로 마커 재생성
    final markerSize = isSelected ? 44.0 : 36.0;
    NOverlayImage? icon;
    try {
      icon = await _getMarkerIcon(
        isSelected: isSelected,
        colorScheme: colorScheme,
        markerSize: markerSize,
      );
    } catch (_) {
      icon = null;
    }

    if (!mounted) return;

    final marker = NMarker(
      id: markerId,
      position: NLatLng(condition.latitude, condition.longitude),
      icon: icon,
      size: Size(markerSize, markerSize),
      anchor: const NPoint(0.5, 0.5),
    );

    if (icon == null) {
      marker.setIconTintColor(Colors.orange);
    }

    marker.setOnTapListener((_) {
      _onMarkerTapped(condition);
      return true;
    });

    await _mapController!.addOverlay(marker);
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

  /// 에러 상태
  Widget _buildErrorStateFromMessage(String errorMessage) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: AppConstants.fontFamilySmall,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  context.read<RoadSurfaceViewModel>().initialize(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 한국어 주석: 로딩/에러 상태 전용 (불필요한 빌드를 막기 위해 최소 필드만 포함)
class _RoadSurfaceLoadingState extends Equatable {
  final bool isLoading;
  final bool hasLocation;
  final String? errorMessage;

  const _RoadSurfaceLoadingState({
    required this.isLoading,
    required this.hasLocation,
    required this.errorMessage,
  });

  @override
  List<Object?> get props => [isLoading, hasLocation, errorMessage];
}

/// 한국어 주석: 조건 개수 표시 전용 상태
class _RoadSurfaceConditionsState extends Equatable {
  final bool isLoadingConditions;
  final int conditionsCount;

  const _RoadSurfaceConditionsState({
    required this.isLoadingConditions,
    required this.conditionsCount,
  });

  @override
  List<Object?> get props => [isLoadingConditions, conditionsCount];
}

class _RoadConditionMarkerIconCacheKey {
  final bool isSelected;
  final int surfaceColorValue;
  final int markerSize;

  const _RoadConditionMarkerIconCacheKey({
    required this.isSelected,
    required this.surfaceColorValue,
    required this.markerSize,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _RoadConditionMarkerIconCacheKey &&
        other.isSelected == isSelected &&
        other.surfaceColorValue == surfaceColorValue &&
        other.markerSize == markerSize;
  }

  @override
  int get hashCode => Object.hash(isSelected, surfaceColorValue, markerSize);
}
