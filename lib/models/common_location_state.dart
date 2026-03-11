import 'package:equatable/equatable.dart';

import 'location_model.dart';

/// 위치 기반 화면에서 공통으로 사용하는 지도 최소 상태
class CommonBasicMapState extends Equatable {
  final LocationModel? currentLocation;
  final String? selectedPlaceId;
  final bool isTracking;
  final bool isFollowingLocation;
  final int revision;

  const CommonBasicMapState({
    required this.currentLocation,
    this.selectedPlaceId,
    required this.isTracking,
    this.isFollowingLocation = true,
    this.revision = 0,
  });

  @override
  List<Object?> get props => [
    currentLocation,
    selectedPlaceId,
    isTracking,
    isFollowingLocation,
    revision,
  ];
}

/// 로딩/에러 오버레이 공통 상태
class CommonLoadingErrorState extends Equatable {
  final bool isLoading;
  final bool hasLocation;
  final String? errorMessage;

  const CommonLoadingErrorState({
    required this.isLoading,
    required this.hasLocation,
    required this.errorMessage,
  });

  @override
  List<Object?> get props => [isLoading, hasLocation, errorMessage];
}

/// 리프레시 버튼 공통 상태
class CommonRefreshButtonState extends Equatable {
  final bool hasLocation;
  final bool isLoading;
  final bool showPlaceList;

  const CommonRefreshButtonState({
    required this.hasLocation,
    required this.isLoading,
    this.showPlaceList = false,
  });

  @override
  List<Object?> get props => [hasLocation, isLoading, showPlaceList];
}

/// 위치 관련 공통 상태
class CommonLocationState extends Equatable {
  final LocationModel? currentLocation;
  final bool isTracking;
  final bool isFollowingLocation;

  const CommonLocationState({
    required this.currentLocation,
    required this.isTracking,
    this.isFollowingLocation = true,
  });

  const CommonLocationState.initial()
    : currentLocation = null,
      isTracking = false,
      isFollowingLocation = true;

  CommonLocationState copyWith({
    LocationModel? currentLocation,
    bool? isTracking,
    bool? isFollowingLocation,
  }) {
    return CommonLocationState(
      currentLocation: currentLocation ?? this.currentLocation,
      isTracking: isTracking ?? this.isTracking,
      isFollowingLocation: isFollowingLocation ?? this.isFollowingLocation,
    );
  }

  @override
  List<Object?> get props => [currentLocation, isTracking, isFollowingLocation];
}

/// 로딩/초기화 공통 상태
class CommonLoadingState extends Equatable {
  final bool isLoading;
  final bool isRefreshing;
  final bool isInitialized;

  const CommonLoadingState({
    required this.isLoading,
    required this.isRefreshing,
    required this.isInitialized,
  });

  const CommonLoadingState.initial()
    : isLoading = false,
      isRefreshing = false,
      isInitialized = false;

  CommonLoadingState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isInitialized,
  }) {
    return CommonLoadingState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  @override
  List<Object?> get props => [isLoading, isRefreshing, isInitialized];
}

/// 에러 공통 상태
class CommonErrorState extends Equatable {
  final String? errorMessage;

  const CommonErrorState({required this.errorMessage});

  const CommonErrorState.initial() : errorMessage = null;

  CommonErrorState copyWith({String? errorMessage}) {
    return CommonErrorState(errorMessage: errorMessage ?? this.errorMessage);
  }

  CommonErrorState clearError() {
    return const CommonErrorState(errorMessage: null);
  }

  @override
  List<Object?> get props => [errorMessage];
}

/// 위치 기반 통합 상태의 공통 인터페이스
abstract class CommonLocationStateContainer<TSelf> {
  CommonLocationState get location;
  CommonLoadingState get loading;
  CommonErrorState get error;

  TSelf copyWithCommon({
    CommonLocationState? location,
    CommonLoadingState? loading,
    CommonErrorState? error,
  });
}
