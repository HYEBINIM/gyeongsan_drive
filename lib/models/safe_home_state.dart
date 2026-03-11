import 'package:equatable/equatable.dart';
import 'common_location_state.dart';
import 'location_model.dart';

typedef BasicMapState = CommonBasicMapState;
typedef LoadingErrorState = CommonLoadingErrorState;
typedef RefreshButtonState = CommonRefreshButtonState;
typedef LocationState = CommonLocationState;
typedef LoadingState = CommonLoadingState;
typedef ErrorState = CommonErrorState;

/// 통합 SafeHome 상태
/// - ViewModel의 모든 상태를 하나의 불변 객체로 관리
/// - copyWith 패턴으로 상태 업데이트
/// - Equatable로 자동 동등성 비교
class SafeHomeState extends Equatable
    implements CommonLocationStateContainer<SafeHomeState> {
  @override
  final LocationState location;
  @override
  final LoadingState loading;
  @override
  final ErrorState error;

  const SafeHomeState({
    required this.location,
    required this.loading,
    required this.error,
  });

  /// 초기 상태 생성
  const SafeHomeState.initial()
    : location = const LocationState.initial(),
      loading = const LoadingState.initial(),
      error = const ErrorState.initial();

  /// 상태 복사 (일부 필드만 업데이트)
  SafeHomeState copyWith({
    LocationState? location,
    LoadingState? loading,
    ErrorState? error,
  }) {
    return SafeHomeState(
      location: location ?? this.location,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }

  @override
  SafeHomeState copyWithCommon({
    CommonLocationState? location,
    CommonLoadingState? loading,
    CommonErrorState? error,
  }) {
    return copyWith(location: location, loading: loading, error: error);
  }

  // 편의 getter들
  LocationModel? get currentLocation => location.currentLocation;
  bool get isLoading => loading.isLoading;
  bool get isRefreshing => loading.isRefreshing;
  bool get isInitialized => loading.isInitialized;
  bool get isTracking => location.isTracking;
  bool get isFollowingLocation => location.isFollowingLocation;
  String? get errorMessage => error.errorMessage;
  bool get hasLocation => location.currentLocation != null;

  @override
  List<Object?> get props => [location, loading, error];
}
