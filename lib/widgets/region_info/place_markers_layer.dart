import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/place_model.dart';
import '../../utils/constants.dart';
import '../../view_models/region_info/region_info_viewmodel.dart';
import 'package:equatable/equatable.dart';

/// 장소 마커 레이어
/// - 선택된 장소 리스트/선택 상태 변화에만 반응하도록 별도 분리
class PlaceMarkersLayer extends StatelessWidget {
  const PlaceMarkersLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // ViewModel에서 장소/선택 상태만 구독하여 최소 렌더링
    final markersState = context.select<RegionInfoViewModel, _MarkersState>(
      (vm) => _MarkersState(
        selectedPlaces: vm.selectedPlaces,
        selectedPlaceId: vm.selectedPlaceId,
      ),
    );

    final places = markersState.selectedPlaces;
    if (places == null || places.isEmpty) {
      return const MarkerLayer(markers: []);
    }

    final markers = places.map((place) {
      final isSelected = place.id == markersState.selectedPlaceId;
      final markerSize = isSelected ? 40.0 : 30.0;
      final iconSize = isSelected ? 24.0 : 18.0;
      final borderWidth = isSelected ? 3.0 : 2.0;
      final textSize = isSelected ? 11.0 : 10.0;
      // 한국어 주석: 음성 검색 마커는 라벨을 표시하지 않으므로 높이를 줄임
      final isVoiceMarker = place.id.startsWith('voice_');
      final markerHeight = isVoiceMarker ? 40.0 : (isSelected ? 70.0 : 60.0);

      return Marker(
        point: LatLng(place.latitude, place.longitude),
        width: 80,
        height: markerHeight,
        child: GestureDetector(
          onTap: () {
            // 마커 탭 시 선택/해제 토글
            final vm = context.read<RegionInfoViewModel>();
            if (vm.selectedPlaceId == place.id) {
              vm.clearSelectedPlace();
            } else {
              // 한국어 주석: 지도 마커에서 선택된 경우 바텀시트가 해당 카드로 스크롤되도록 fromMap 플래그를 활성화
              vm.selectPlace(place.id, fromMap: true);
            }
          },
          behavior: HitTestBehavior.translucent,
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
        ),
      );
    }).toList();

    return MarkerLayer(markers: markers);
  }
}

class _MarkersState extends Equatable {
  final List<PlaceModel>? selectedPlaces;
  final String? selectedPlaceId;

  const _MarkersState({
    required this.selectedPlaces,
    required this.selectedPlaceId,
  });

  @override
  List<Object?> get props => [selectedPlaces, selectedPlaceId];
}

/// 카테고리별 마커 아이콘 반환 (이 레이어 전용)
IconData _getMarkerIconByCategory(String categoryId) {
  final category = AppConstants.placeCategories.firstWhere(
    (cat) => cat['id'] == categoryId,
    orElse: () => {'id': '', 'icon': Icons.place},
  );
  return category['icon'] as IconData;
}
