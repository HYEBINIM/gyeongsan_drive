import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/location_model.dart';
import '../../view_models/navigation/navigation_viewmodel.dart';
import '../common/map/current_location_marker_layer.dart';

/// 현재 위치 마커 레이어
/// Navigator ViewModel의 currentLocation만 구독하여 성능 최적화
class CurrentLocationLayer extends StatelessWidget {
  const CurrentLocationLayer({super.key});

  @override
  Widget build(BuildContext context) {
    // currentLocation만 구독 (다른 상태 변경 시 rebuild 안 됨)
    final location = context.select<NavigationViewModel, LocationModel?>(
      (vm) => vm.currentLocation,
    );
    return CurrentLocationMarkerLayer(location: location);
  }
}
