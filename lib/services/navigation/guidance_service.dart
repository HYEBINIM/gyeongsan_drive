import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/navigation/maneuver_model.dart';

/// 길안내 비즈니스 로직 서비스
/// 경로 이탈 감지, 거리 계산, 안내 문구 생성 등을 담당
class GuidanceService {
  /// 경로 이탈 판단 임계값 (미터)
  static const double _offRouteThresholdMeters = 50.0;

  /// 거리 계산 도구
  final Distance _distance = const Distance();

  /// 경로 이탈 여부 감지
  /// 현재 위치가 경로선에서 [_offRouteThresholdMeters] 이상 벗어났는지 체크
  bool isOffRoute({
    required LatLng currentLocation,
    required List<LatLng> routePoints,
  }) {
    if (routePoints.isEmpty) return false;

    final minDistance = _calculateMinDistanceToRoute(
      currentLocation,
      routePoints,
    );
    return minDistance > _offRouteThresholdMeters;
  }

  /// 현재 maneuver 인덱스 찾기
  /// 현재 위치에서 가장 가까운 maneuver를 찾아 인덱스 반환
  int findCurrentManeuverIndex({
    required LatLng currentLocation,
    required List<ManeuverModel> maneuvers,
  }) {
    if (maneuvers.isEmpty) return 0;

    // 현재 위치에서 가장 가까운 maneuver 찾기
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < maneuvers.length; i++) {
      final maneuver = maneuvers[i];
      if (maneuver.beginLocation == null) continue;

      final distance = _distance.as(
        LengthUnit.Meter,
        currentLocation,
        maneuver.beginLocation!,
      );

      // 이미 지나간 maneuver는 제외 (음수 거리)
      if (distance < minDistance && distance >= 0) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// 남은 총 거리 계산 (현재 위치 ~ 목적지)
  /// 현재 maneuver부터 끝까지 거리 합산
  double calculateRemainingDistance({
    required LatLng currentLocation,
    required List<LatLng> routePoints,
    required int currentManeuverIndex,
    required List<ManeuverModel> maneuvers,
  }) {
    if (routePoints.isEmpty || maneuvers.isEmpty) return 0.0;

    // 현재 maneuver부터 끝까지 거리 합산
    double totalKm = 0.0;

    for (int i = currentManeuverIndex; i < maneuvers.length; i++) {
      totalKm += maneuvers[i].lengthKm;
    }

    return totalKm;
  }

  /// 다음 maneuver까지의 거리 계산 (미터)
  double calculateDistanceToNextManeuver({
    required LatLng currentLocation,
    required ManeuverModel nextManeuver,
  }) {
    if (nextManeuver.beginLocation == null) return 0.0;

    final meters = _distance.as(
      LengthUnit.Meter,
      currentLocation,
      nextManeuver.beginLocation!,
    );

    return meters;
  }

  /// 거리를 포맷팅 (네이버 지도 스타일)
  /// 1km 미만: "181m"
  /// 1km 이상: "1.2km"
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// 다음 안내 문구 생성
  /// 예: "200m 앞에서 좌회전하세요"
  String getNextInstruction({
    required int currentManeuverIndex,
    required List<ManeuverModel> maneuvers,
    required double distanceToNextManeuverMeters,
  }) {
    if (currentManeuverIndex >= maneuvers.length) {
      return '목적지에 도착했습니다';
    }

    final nextManeuver = maneuvers[currentManeuverIndex];
    final distanceStr = _formatDistance(distanceToNextManeuverMeters);

    return '$distanceStr ${nextManeuver.instruction}';
  }

  /// Maneuver type에 따른 화살표 아이콘 반환
  /// Valhalla maneuver types: https://valhalla.github.io/valhalla/api/turn-by-turn/api-reference/#maneuvers
  IconData getManeuverIcon(int type) {
    switch (type) {
      case 0:
        return Icons.near_me; // 출발
      case 1:
      case 2:
        return Icons.arrow_upward; // 직진
      case 7:
      case 8:
        return Icons.turn_left; // 좌회전 / 약간 좌회전
      case 15:
      case 16:
        return Icons.turn_right; // 우회전 / 약간 우회전
      case 6:
        return Icons.u_turn_left; // 유턴
      case 4:
        return Icons.flag; // 목적지 도착
      case 10:
      case 11:
        return Icons.ramp_left; // 램프 좌측
      case 18:
      case 19:
        return Icons.ramp_right; // 램프 우측
      default:
        return Icons.arrow_upward; // 기본 (직진)
    }
  }

  /// 경로선까지의 최단 거리 계산
  /// 현재 위치에서 모든 경로 선분까지의 최단 거리를 계산
  double _calculateMinDistanceToRoute(LatLng point, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return 0.0;

    double minDistance = double.infinity;

    // 모든 경로 선분에 대해 최단 거리 계산
    for (int i = 0; i < routePoints.length - 1; i++) {
      final segmentDistance = _distanceToSegment(
        point,
        routePoints[i],
        routePoints[i + 1],
      );

      if (segmentDistance < minDistance) {
        minDistance = segmentDistance;
      }
    }

    return minDistance;
  }

  /// 점에서 선분까지의 최단 거리 계산
  /// 벡터 투영을 이용한 수직 거리 계산
  double _distanceToSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    // 선분의 길이가 0인 경우 (점과 점)
    if (dx == 0 && dy == 0) {
      return _distance.as(LengthUnit.Meter, point, lineStart);
    }

    // 벡터 투영을 이용한 선분 위의 가장 가까운 점 계산
    // t = 0: lineStart, t = 1: lineEnd
    final t = math.max(
      0.0,
      math.min(
        1.0,
        ((point.longitude - lineStart.longitude) * dx +
                (point.latitude - lineStart.latitude) * dy) /
            (dx * dx + dy * dy),
      ),
    );

    // 가장 가까운 점의 좌표
    final closestPoint = LatLng(
      lineStart.latitude + t * dy,
      lineStart.longitude + t * dx,
    );

    // 점에서 가장 가까운 점까지의 거리
    return _distance.as(LengthUnit.Meter, point, closestPoint);
  }

  /// 거리 포맷팅
  /// 1km 미만: "200m 앞에서"
  /// 1km 이상: "1.5km 앞에서"
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m 앞에서';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km 앞에서';
    }
  }
}
