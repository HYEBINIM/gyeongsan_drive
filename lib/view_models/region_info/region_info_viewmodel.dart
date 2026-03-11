import 'package:flutter/material.dart';

import '../../models/common_location_state.dart';
import '../../models/location_model.dart';
import '../../models/place_model.dart';
import '../../models/region_info_state.dart';
import '../../services/geocoding/geocoding_service.dart';
import '../../services/region_info/firestore_region_info_service.dart';
import '../../utils/operating_hours_helper.dart';
import '../base/location_tracking_viewmodel.dart';

/// 지역 정보 화면의 비즈니스 로직을 담당하는 ViewModel
class RegionInfoViewModel extends LocationTrackingViewModel<RegionInfoState> {
  final FirestoreRegionInfoService _regionInfoService;
  final GeocodingService _geocodingService;

  int _voiceSearchRequestId = 0;
  bool _voiceSearchActive = false;

  RegionInfoViewModel({
    required super.locationService,
    required FirestoreRegionInfoService regionInfoService,
    required GeocodingService geocodingService,
  }) : _regionInfoService = regionInfoService,
       _geocodingService = geocodingService,
       super(
         initialState: const RegionInfoState.initial(),
         initialMapState: const BasicMapState(
           currentLocation: null,
           selectedPlaceId: null,
           isTracking: false,
           isFollowingLocation: true,
           revision: 0,
         ),
       );

  LocationModel? get currentLocation => state.currentLocation;
  bool get isLoading => state.isLoading;
  bool get isRefreshing => state.isRefreshing;
  String? get errorMessage => state.errorMessage;
  bool get hasLocation => state.hasLocation;
  bool get isTracking => state.isTracking;
  bool get isFollowingLocation => state.isFollowingLocation;
  String? get selectedCategoryId => state.selectedCategoryId;
  List<PlaceModel>? get selectedPlaces => state.selectedPlaces;
  bool get showPlaceList => state.showPlaceList;
  String? get selectedPlaceId => state.selectedPlaceId;
  bool get shouldScrollToSelectedPlace => state.shouldScrollToSelectedPlace;
  bool get hasMorePlaces => state.hasMorePlaces;
  bool get isLoadingMore => state.isLoadingMore;

  void _updateState(
    RegionInfoState Function(RegionInfoState) updater, {
    bool syncMap = true,
  }) {
    updateState(updater, syncMap: syncMap);
  }

  @override
  RegionInfoState onLocationUpdated(
    RegionInfoState currentState,
    LocationModel location,
  ) {
    return currentState.copyWith(
      location: currentState.location.copyWith(currentLocation: location),
    );
  }

  @override
  CommonBasicMapState createMapState(
    RegionInfoState currentState, {
    required int revision,
  }) {
    return BasicMapState(
      currentLocation: currentState.currentLocation,
      selectedPlaceId: currentState.selectedPlaceId,
      isTracking: currentState.isTracking,
      isFollowingLocation: currentState.isFollowingLocation,
      revision: revision,
    );
  }

  @override
  int getStateMapRevision(RegionInfoState currentState) {
    return currentState.mapStateRevision;
  }

  @override
  RegionInfoState setStateMapRevision(
    RegionInfoState currentState,
    int revision,
  ) {
    return currentState.copyWith(
      selection: currentState.selection.copyWith(mapStateRevision: revision),
    );
  }

  static const int _displayPageSize = 30;

  Future<void> selectCategory(String categoryId) async {
    if (state.selectedCategoryId == categoryId) {
      _updateState(
        (s) => s.copyWith(
          selection: const SelectionState.initial(),
          error: s.error.clearError(),
        ),
      );
      return;
    }

    _updateState(
      (s) => s.copyWith(
        selection: s.selection.copyWith(
          selectedCategoryId: categoryId,
          showPlaceList: true,
          clearLastDocument: true,
          clearBufferedPlaces: true,
          hasMorePlaces: false,
          isLoadingMore: false,
          displayedCount: 0,
        ),
        loading: s.loading.copyWith(isLoading: true),
        error: s.error.clearError(),
      ),
    );

    try {
      final allPlaces = await _regionInfoService.getAllPlacesByCategory(
        categoryId,
      );
      final allFilteredPlaces = _updateDistancesAndOperatingStatus(allPlaces);

      final displayPlaces = allFilteredPlaces.take(_displayPageSize).toList();
      final bufferedPlaces = allFilteredPlaces.skip(_displayPageSize).toList();
      final hasMore = bufferedPlaces.isNotEmpty;

      _updateState(
        (s) => s.copyWith(
          selection: s.selection.copyWith(
            selectedPlaces: displayPlaces,
            selectedPlaceId: null,
            shouldScrollToSelectedPlace: false,
            hasMorePlaces: hasMore,
            bufferedPlaces: bufferedPlaces,
            displayedCount: displayPlaces.length,
          ),
          loading: s.loading.copyWith(isLoading: false),
        ),
      );
    } catch (e) {
      _updateState(
        (s) => s.copyWith(
          selection: s.selection.copyWith(
            selectedPlaces: [],
            clearLastDocument: true,
            clearBufferedPlaces: true,
            hasMorePlaces: false,
            displayedCount: 0,
          ),
          loading: s.loading.copyWith(isLoading: false),
          error: ErrorState(errorMessage: e.toString()),
        ),
      );
    }
  }

  Future<void> loadMorePlaces() async {
    if (state.isLoadingMore || !state.hasMorePlaces) {
      return;
    }

    final buffered = state.selection.bufferedPlaces ?? [];
    if (buffered.isEmpty) {
      _updateState(
        (s) =>
            s.copyWith(selection: s.selection.copyWith(hasMorePlaces: false)),
      );
      return;
    }

    final nextPage = buffered.take(_displayPageSize).toList();
    final remainingBuffer = buffered.skip(_displayPageSize).toList();
    final allDisplayed = [...?state.selectedPlaces, ...nextPage];

    _updateState(
      (s) => s.copyWith(
        selection: s.selection.copyWith(
          selectedPlaces: allDisplayed,
          bufferedPlaces: remainingBuffer,
          displayedCount: allDisplayed.length,
          hasMorePlaces: remainingBuffer.isNotEmpty,
        ),
      ),
    );
  }

  void hidePlaceList() {
    _updateState(
      (s) => s.copyWith(
        selection: s.selection.copyWith(
          showPlaceList: false,
          selectedPlaceId: null,
          shouldScrollToSelectedPlace: false,
        ),
      ),
    );
  }

  void selectPlace(String placeId, {bool fromMap = false}) {
    _updateState(
      (s) => s.copyWith(
        location: s.location.copyWith(isFollowingLocation: false),
        selection: s.selection.copyWith(
          selectedPlaceId: placeId,
          showPlaceList: true,
          shouldScrollToSelectedPlace: fromMap,
        ),
      ),
    );
  }

  void clearSelectedPlace() {
    _updateState(
      (s) => s.copyWith(
        selection: s.selection.copyWith(
          selectedPlaceId: null,
          shouldScrollToSelectedPlace: false,
        ),
      ),
    );
  }

  void setFollowingLocation(bool following) {
    _updateState(
      (s) => s.copyWith(
        location: s.location.copyWith(isFollowingLocation: following),
      ),
    );
  }

  void centerMapOnCurrentLocation() {
    setFollowingLocation(true);
  }

  void markScrollToSelectedPlaceHandled() {
    if (!state.shouldScrollToSelectedPlace) {
      return;
    }
    _updateState(
      (s) => s.copyWith(
        selection: s.selection.copyWith(shouldScrollToSelectedPlace: false),
      ),
      syncMap: false,
    );
  }

  List<PlaceModel> _updateDistancesAndOperatingStatus(
    List<PlaceModel> places, {
    LocationModel? currentLocation,
  }) {
    final location = currentLocation ?? state.currentLocation;
    if (location == null || places.isEmpty) return places;

    final updatedPlaces = places.map((place) {
      final distance = locationService.getDistanceBetween(
        startLatitude: location.latitude,
        startLongitude: location.longitude,
        endLatitude: place.latitude,
        endLongitude: place.longitude,
      );

      final isOpen = OperatingHoursHelper.isOpenNow(place.hoursData);
      final hoursText = OperatingHoursHelper.getOperatingHoursText(
        place.hoursData,
      );

      return place.copyWith(
        distanceKm: distance / 1000,
        isOpen: isOpen,
        openingHours: hoursText,
      );
    }).toList();

    final openPlaces = updatedPlaces.where((place) => place.isOpen).toList();
    openPlaces.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return openPlaces;
  }

  Future<void> showVoiceSearchResult(
    Map<String, dynamic> metadata, {
    List<dynamic>? toolsUsed,
    String? originalQuery,
  }) async {
    final requestId = ++_voiceSearchRequestId;
    _voiceSearchActive = true;

    try {
      PlaceModel place = PlaceModel.fromVoiceMetadata(
        metadata,
        toolsUsed: toolsUsed,
        originalQuery: originalQuery,
      );

      if (place.address.isNotEmpty) {
        final coordinates = await _geocodingService.getCoordinatesFromAddress(
          place.address,
        );

        if (coordinates != null) {
          place = place.copyWith(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
          );
        }
      }

      if (!_voiceSearchActive || requestId != _voiceSearchRequestId) {
        return;
      }

      _updateState(
        (s) => s.copyWith(
          location: s.location.copyWith(isFollowingLocation: false),
          selection: s.selection.copyWith(
            selectedCategoryId: place.category,
            selectedPlaces: [place],
            selectedPlaceId: place.id,
            showPlaceList: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[RegionInfoViewModel] 음성 검색 결과 표시 실패: $e');
    }
  }

  void clearVoiceSearchMarker() {
    _voiceSearchActive = false;
    _voiceSearchRequestId++;

    _updateState((s) => s.copyWith(selection: const SelectionState.initial()));
    debugPrint('[RegionInfoViewModel] 음성 검색 마커 초기화 완료');
  }
}
