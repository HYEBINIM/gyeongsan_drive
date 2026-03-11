import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../view_models/navigation/navigation_viewmodel.dart';

/// 도착지 마커 레이어
/// 경로의 도착지에 빨간색 "도착" 마커 표시
class DestinationMarkerLayer extends StatelessWidget {
  const DestinationMarkerLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<NavigationViewModel, LatLng?>(
      selector: (context, vm) => vm.state.locations.destination?.coordinates,
      builder: (context, destinationCoords, _) {
        // 도착지가 없으면 빈 레이어 반환
        if (destinationCoords == null) {
          return const SizedBox.shrink();
        }

        return MarkerLayer(
          markers: [
            Marker(
              point: destinationCoords,
              width: 48,
              height: 60,
              child: Image.asset(
                'assets/icons/ic_ar.png',
                width: 48,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
          ],
        );
      },
    );
  }
}
