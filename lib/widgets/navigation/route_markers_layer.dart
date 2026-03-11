import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../../models/navigation/route_model.dart';
import '../../view_models/navigation/navigation_viewmodel.dart';

/// 마커 레이어 전용 상태 클래스
class _MarkersState extends Equatable {
  final LocationInfo? start;
  final LocationInfo? destination;

  const _MarkersState({required this.start, required this.destination});

  @override
  List<Object?> get props => [start, destination];
}

/// 출발지/도착지 마커 레이어
/// NavigationViewModel의 start/destination만 구독하여 성능 최적화
class RouteMarkersLayer extends StatelessWidget {
  const RouteMarkersLayer({super.key});

  // 마커 공통 크기(논리 픽셀) - DRY 원칙 적용
  static const double _markerSize = 48.0;
  // 마커 이미지 하단 투명 여백 보정용 오프셋(논리 px)
  // - Alignment.bottomCenter 정렬 후, 핀 끝이 좌표를 더 정확히 가리키도록 미세 이동
  static const double _markerOffsetDy = -40.0;

  @override
  Widget build(BuildContext context) {
    // start와 destination만 구독
    final markersState = context.select<NavigationViewModel, _MarkersState>(
      (vm) => _MarkersState(
        start: vm.locations.start,
        destination: vm.locations.destination,
      ),
    );

    final markers = <Marker>[];

    // 출발지 마커 추가
    if (markersState.start != null) {
      markers.add(_buildStartMarker(context, markersState.start!));
    }

    // 도착지 마커 추가
    if (markersState.destination != null) {
      markers.add(_buildDestinationMarker(context, markersState.destination!));
    }

    return MarkerLayer(markers: markers);
  }

  /// 출발지 마커 생성
  Marker _buildStartMarker(BuildContext context, LocationInfo start) {
    return Marker(
      point: start.coordinates,
      width: _markerSize,
      height: _markerSize,
      alignment: Alignment.bottomCenter, // 아이콘 하단 중앙이 좌표를 가리킴
      child: _buildMarkerWidget(context, imagePath: 'assets/icons/ic_st.png'),
    );
  }

  /// 도착지 마커 생성
  Marker _buildDestinationMarker(
    BuildContext context,
    LocationInfo destination,
  ) {
    return Marker(
      point: destination.coordinates,
      width: _markerSize,
      height: _markerSize,
      alignment: Alignment.bottomCenter, // 아이콘 하단 중앙이 좌표를 가리킴
      child: _buildMarkerWidget(context, imagePath: 'assets/icons/ic_ar.png'),
    );
  }

  /// 마커 위젯 빌더 (커스텀 이미지만 표시)
  Widget _buildMarkerWidget(BuildContext context, {required String imagePath}) {
    // 고해상도 디코딩 및 스케일 품질 향상
    // - cacheWidth/Height: 실제 표시 픽셀(논리크기 * DPR)에 맞춰 디코딩하여 선명도 확보
    // - filterQuality: 스케일 시 샘플링 품질 향상
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (_markerSize * dpr).round();
    final colorScheme = Theme.of(context).colorScheme;

    return Transform.translate(
      // 아래쪽(+Y)으로 소폭 이동하여 핀 끝 정렬 보정
      offset: const Offset(0, _markerOffsetDy),
      child: Image.asset(
        imagePath,
        width: _markerSize,
        height: _markerSize,
        fit: BoxFit.contain,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ 마커 이미지 로드 실패: $imagePath');
          debugPrint('에러: $error');
          // fallback: 빨간 원으로 표시
          return Container(
            width: _markerSize,
            height: _markerSize,
            decoration: BoxDecoration(
              color: colorScheme.error,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error, color: colorScheme.onError, size: 24),
          );
        },
      ),
    );
  }
}
