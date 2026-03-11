import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../../models/navigation/route_model.dart';
import '../../models/navigation/route_type.dart';
import '../../view_models/navigation/navigation_viewmodel.dart';

/// 경로 폴리라인 레이어
/// 모든 경로를 동시에 표시하고, 선택된 경로는 파란색, 미선택은 회색으로 표시
class RoutePolylineLayer extends StatelessWidget {
  const RoutePolylineLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 모든 경로 + 선택된 경로 타입 구독
    final state = context.select<NavigationViewModel, _RouteLayerState>(
      (vm) => _RouteLayerState(
        routes: vm.routes,
        selectedRouteType: vm.selectedRouteType,
      ),
    );

    // 경로가 없으면 빈 레이어 반환
    if (state.routes.isEmpty) {
      return PolylineLayer(polylines: const <Polyline>[]);
    }

    final polylines = <Polyline>[];

    // 1단계: 미선택 경로를 먼저 그리기 (회색, 얇게)
    for (final entry in state.routes.entries) {
      final routeType = entry.key;
      final route = entry.value;

      // 선택되지 않은 경로만 먼저 그림
      if (routeType != state.selectedRouteType &&
          route != null &&
          route.routePoints.isNotEmpty) {
        polylines.add(
          Polyline(
            points: route.routePoints,
            color: colorScheme.onSurface.withValues(alpha: 0.5), // 회색
            strokeWidth: 5.0, // 얇게
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
        );
      }
    }

    // 2단계: 선택된 경로를 나중에 그리기 (파란색, 두껍게) → 맨 위에 표시됨
    final selectedRoute = state.routes[state.selectedRouteType];
    if (selectedRoute != null && selectedRoute.routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: selectedRoute.routePoints,
          color: colorScheme.primary, // 파란색
          strokeWidth: 5.0, // 두껍게
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
    }

    return PolylineLayer(polylines: polylines);
  }
}

/// 경로 레이어 상태 (Selector 최적화용)
class _RouteLayerState {
  final Map<RouteType, RouteModel?> routes;
  final RouteType selectedRouteType;

  _RouteLayerState({required this.routes, required this.selectedRouteType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RouteLayerState &&
          runtimeType == other.runtimeType &&
          routes == other.routes &&
          selectedRouteType == other.selectedRouteType;

  @override
  int get hashCode => routes.hashCode ^ selectedRouteType.hashCode;
}
