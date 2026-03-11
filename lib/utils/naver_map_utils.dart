import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/common/map/current_location_marker.dart';

export '../widgets/common/map/current_location_marker.dart';

/// 지역 좌표를 네이버 지도 좌표로 변환
NLatLng toNLatLng(LatLng latLng) => NLatLng(latLng.latitude, latLng.longitude);

/// 네이버 지도 좌표를 지역 좌표로 변환
LatLng toLatLng(NLatLng latLng) => LatLng(latLng.latitude, latLng.longitude);

/// 현재 위치 마커를 네이버 지도 오버레이로 생성
///
/// 한국어 주석: NOverlayImage.fromWidget은 내부적으로 ImageReader를 사용하여
/// Flutter 위젯을 비트맵으로 변환합니다. 연속 호출 시 버퍼 오버플로우 방지를 위해
/// 적절한 딜레이를 두고 호출하는 것을 권장합니다.
Future<NMarker> buildCurrentLocationOverlay(
  BuildContext context, {
  required String id,
  required LatLng position,
  CurrentLocationMarkerStyle style =
      const CurrentLocationMarkerStyle.navigation(),
}) async {
  final image = await NOverlayImage.fromWidget(
    widget: CurrentLocationMarker(style: style),
    size: Size(style.outerSize, style.outerSize),
    context: context,
  );

  return NMarker(
    id: id,
    position: toNLatLng(position),
    icon: image,
    size: Size(style.outerSize, style.outerSize),
    anchor: const NPoint(0.5, 0.5),
  );
}

/// 에셋 이미지를 사용하는 기본 마커 생성
Future<NMarker> buildAssetMarkerOverlay(
  String id, {
  required LatLng position,
  required String assetPath,
  Size size = const Size(48, 48),
}) async {
  final image = NOverlayImage.fromAssetImage(assetPath);
  return NMarker(
    id: id,
    position: toNLatLng(position),
    icon: image,
    size: size,
    anchor: const NPoint(0.5, 1.0),
  );
}

/// 단순 폴리라인 오버레이 생성
NPolylineOverlay buildPolylineOverlay(
  String id, {
  required List<LatLng> points,
  required Color color,
  double width = 5.0,
}) {
  return NPolylineOverlay(
    id: id,
    coords: points.map(toNLatLng),
    color: color,
    width: width,
    lineCap: NLineCap.round,
    lineJoin: NLineJoin.round,
  );
}

/// 바텀시트에 가려지지 않도록 카메라 중심을 화면상의 y 픽셀만큼 아래로 이동시킨 좌표 변환
Future<LatLng> offsetCenterByPixels({
  required NaverMapController controller,
  required LatLng target,
  required double offsetPixels,
}) async {
  final targetPoint = await controller.latLngToScreenLocation(
    toNLatLng(target),
  );
  final offsetPoint = NPoint(targetPoint.x, targetPoint.y + offsetPixels);
  final adjusted = await controller.screenLocationToLatLng(offsetPoint);
  return toLatLng(adjusted);
}

/// 줌/위도 기반으로 1dp당 미터 값을 계산 (Web Mercator 기준)
double meterPerDp({required double latitude, required double zoom}) {
  return 156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);
}

/// LatLng 리스트로부터 NLatLngBounds 생성
NLatLngBounds buildBoundsFromPoints(List<LatLng> points) {
  assert(points.isNotEmpty, 'bounds 계산을 위해서는 최소 1개 이상의 포인트가 필요합니다.');
  double minLat = points.first.latitude;
  double maxLat = points.first.latitude;
  double minLon = points.first.longitude;
  double maxLon = points.first.longitude;

  for (final p in points.skip(1)) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLon) minLon = p.longitude;
    if (p.longitude > maxLon) maxLon = p.longitude;
  }

  return NLatLngBounds(
    southWest: NLatLng(minLat, minLon),
    northEast: NLatLng(maxLat, maxLon),
  );
}
