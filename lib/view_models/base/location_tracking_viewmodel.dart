import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/common_location_state.dart';
import '../../models/location_model.dart';
import '../../services/location/location_service.dart';

/// 위치 기반 화면의 공통 ViewModel 베이스
abstract class LocationTrackingViewModel<
  TState extends CommonLocationStateContainer<TState>
>
    extends ChangeNotifier {
  final LocationService _locationService;
  StreamSubscription<LocationModel>? _locationSubscription;
  TState _state;

  final ValueNotifier<CommonBasicMapState> _mapStateNotifier;

  LocationTrackingViewModel({
    required LocationService locationService,
    required TState initialState,
    required CommonBasicMapState initialMapState,
  }) : _locationService = locationService,
       _state = initialState,
       _mapStateNotifier = ValueNotifier(initialMapState);

  TState get state => _state;
  ValueNotifier<CommonBasicMapState> get mapStateNotifier => _mapStateNotifier;

  @protected
  LocationService get locationService => _locationService;

  @protected
  void updateState(TState Function(TState) updater, {bool syncMap = true}) {
    _state = updater(_state);
    if (syncMap) {
      _syncMapState();
    }
    notifyListeners();
  }

  Future<void> initialize({bool force = false}) async {
    if (_state.loading.isInitialized && !force) {
      return;
    }

    updateState(
      (s) => s.copyWithCommon(
        loading: s.loading.copyWith(isLoading: true),
        error: s.error.clearError(),
      ),
    );

    try {
      final lastKnownLocation = await _locationService.getLastKnownLocation();
      if (lastKnownLocation != null) {
        updateState(
          (s) => s.copyWithCommon(
            location: s.location.copyWith(currentLocation: lastKnownLocation),
          ),
        );
      }

      final location = await _locationService.getCurrentLocation();
      updateState(
        (s) => s.copyWithCommon(
          location: s.location.copyWith(currentLocation: location),
          loading: s.loading.copyWith(isLoading: false, isInitialized: true),
          error: s.error.clearError(),
        ),
      );

      startLocationTracking();
    } catch (e) {
      updateState(
        (s) => s.copyWithCommon(
          loading: s.loading.copyWith(isLoading: false),
          error: CommonErrorState(errorMessage: e.toString()),
        ),
      );
    }
  }

  Future<void> refreshLocation() async {
    if (_state.loading.isRefreshing) return;

    updateState(
      (s) => s.copyWithCommon(
        loading: s.loading.copyWith(isRefreshing: true),
        error: s.error.clearError(),
      ),
    );

    try {
      final location = await _locationService.getCurrentLocation();
      updateState(
        (s) => s.copyWithCommon(
          location: s.location.copyWith(currentLocation: location),
          loading: s.loading.copyWith(isRefreshing: false),
          error: s.error.clearError(),
        ),
      );
    } catch (e) {
      updateState(
        (s) => s.copyWithCommon(
          loading: s.loading.copyWith(isRefreshing: false),
          error: CommonErrorState(errorMessage: e.toString()),
        ),
      );
    }
  }

  Future<bool> checkLocationServiceEnabled() async {
    return _locationService.isLocationServiceEnabled();
  }

  void clearError() {
    updateState((s) => s.copyWithCommon(error: s.error.clearError()));
  }

  void startLocationTracking() {
    if (_state.location.isTracking) return;

    try {
      _locationSubscription = _locationService.getLocationStream().listen(
        (location) {
          updateState((s) => onLocationUpdated(s, location));
        },
        onError: (error) {
          updateState((s) => onLocationStreamError(s, error));
        },
      );

      updateState(
        (s) =>
            s.copyWithCommon(location: s.location.copyWith(isTracking: true)),
      );
    } catch (_) {
      // 위치 스트림 시작 실패 시 무시
    }
  }

  void stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;

    updateState(
      (s) => s.copyWithCommon(location: s.location.copyWith(isTracking: false)),
    );
  }

  @protected
  TState onLocationUpdated(TState currentState, LocationModel location) {
    return currentState.copyWithCommon(
      location: currentState.location.copyWith(currentLocation: location),
    );
  }

  @protected
  TState onLocationStreamError(TState currentState, Object error) {
    return currentState.copyWithCommon(
      error: CommonErrorState(errorMessage: error.toString()),
    );
  }

  @protected
  CommonBasicMapState createMapState(
    TState currentState, {
    required int revision,
  });

  @protected
  int getStateMapRevision(TState currentState) {
    return _mapStateNotifier.value.revision;
  }

  @protected
  TState setStateMapRevision(TState currentState, int revision) {
    return currentState;
  }

  void _syncMapState({bool force = false}) {
    final currentRevision = getStateMapRevision(_state);
    final revision = force ? currentRevision + 1 : currentRevision;
    final nextState = createMapState(_state, revision: revision);

    if (!force && _mapStateNotifier.value == nextState) {
      return;
    }

    if (revision != currentRevision) {
      _state = setStateMapRevision(_state, revision);
    }

    _mapStateNotifier.value = createMapState(_state, revision: revision);
  }

  @override
  void dispose() {
    stopLocationTracking();
    _mapStateNotifier.dispose();
    super.dispose();
  }
}
