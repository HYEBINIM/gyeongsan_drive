import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/location_model.dart';
import '../../view_models/safe_home/safe_home_viewmodel.dart';
import '../common/map/current_location_marker_layer.dart';

/// 안전귀가 현재 위치 마커 레이어
/// - 지도 프레임과 분리하여 위치 변화에만 반응하도록 설계
class SafeHomeLocationLayer extends StatelessWidget {
  const SafeHomeLocationLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final location = context.select<SafeHomeViewModel, LocationModel?>(
      (vm) => vm.currentLocation,
    );
    return CurrentLocationMarkerLayer(location: location);
  }
}
