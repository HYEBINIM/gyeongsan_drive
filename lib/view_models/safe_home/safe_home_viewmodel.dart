import '../../models/common_location_state.dart';
import '../../models/location_model.dart';
import '../../models/safe_home_state.dart';
import '../base/location_tracking_viewmodel.dart';

/// 안전귀가 화면의 비즈니스 로직을 담당하는 ViewModel
class SafeHomeViewModel extends LocationTrackingViewModel<SafeHomeState> {
  SafeHomeViewModel({required super.locationService})
    : super(
        initialState: const SafeHomeState.initial(),
        initialMapState: const BasicMapState(
          currentLocation: null,
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

  void _updateState(
    SafeHomeState Function(SafeHomeState) updater, {
    bool syncMap = true,
  }) {
    updateState(updater, syncMap: syncMap);
  }

  @override
  CommonBasicMapState createMapState(
    SafeHomeState currentState, {
    required int revision,
  }) {
    return BasicMapState(
      currentLocation: currentState.currentLocation,
      isTracking: currentState.isTracking,
      isFollowingLocation: currentState.isFollowingLocation,
      revision: revision,
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
}
