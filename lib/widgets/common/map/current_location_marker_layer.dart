import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/location_model.dart';
import 'current_location_marker.dart';

/// 현재 위치 마커 공통 레이어
class CurrentLocationMarkerLayer extends StatelessWidget {
  final LocationModel? location;

  const CurrentLocationMarkerLayer({required this.location, super.key});

  @override
  Widget build(BuildContext context) {
    if (location == null) {
      return const MarkerLayer(markers: []);
    }

    final point = LatLng(location!.latitude, location!.longitude);
    return MarkerLayer(
      markers: [
        Marker(
          point: point,
          width: 80,
          height: 80,
          child: const CurrentLocationMarker(
            style: CurrentLocationMarkerStyle.navigation(),
          ),
        ),
      ],
    );
  }
}
