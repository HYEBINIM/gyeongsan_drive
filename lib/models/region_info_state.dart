import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'common_location_state.dart';
import 'location_model.dart';
import 'place_model.dart';

/// 지도 렌더링에 필요한 상태
class MapState extends Equatable {
  final LocationModel? currentLocation;
  final List<PlaceModel>? selectedPlaces;
  final String? selectedPlaceId;
  final bool isTracking;

  const MapState({
    required this.currentLocation,
    required this.selectedPlaces,
    required this.selectedPlaceId,
    required this.isTracking,
  });

  @override
  List<Object?> get props => [
    currentLocation,
    selectedPlaces,
    selectedPlaceId,
    isTracking,
  ];
}

typedef BasicMapState = CommonBasicMapState;
typedef LoadingErrorState = CommonLoadingErrorState;
typedef RefreshButtonState = CommonRefreshButtonState;
typedef LocationState = CommonLocationState;
typedef LoadingState = CommonLoadingState;
typedef ErrorState = CommonErrorState;

/// 카테고리 버튼 상태
class CategoryState extends Equatable {
  final String? selectedCategoryId;
  final bool hasLocation;
  final bool isLoading;

  const CategoryState({
    required this.selectedCategoryId,
    required this.hasLocation,
    required this.isLoading,
  });

  @override
  List<Object?> get props => [selectedCategoryId, hasLocation, isLoading];
}

/// 바텀시트 표시 상태
class BottomSheetState extends Equatable {
  final bool showPlaceList;
  final String? selectedCategoryId;
  final List<PlaceModel>? selectedPlaces;
  final String? selectedPlaceId;
  // 한국어 주석: 지도 마커 선택으로 인해 바텀시트가 해당 카드로 스크롤되어야 하는지 여부
  final bool shouldScrollToSelectedPlace;

  const BottomSheetState({
    required this.showPlaceList,
    required this.selectedCategoryId,
    required this.selectedPlaces,
    required this.selectedPlaceId,
    required this.shouldScrollToSelectedPlace,
  });

  @override
  List<Object?> get props => [
    showPlaceList,
    selectedCategoryId,
    selectedPlaces,
    selectedPlaceId,
    shouldScrollToSelectedPlace,
  ];
}

// ============================================================================
// 통합 상태 관리 클래스
// ============================================================================

/// 선택 관련 상태 (카테고리, 장소)
class SelectionState extends Equatable {
  final String? selectedCategoryId;
  final List<PlaceModel>? selectedPlaces;
  final bool showPlaceList;
  final String? selectedPlaceId;
  final int mapStateRevision;
  // 한국어 주석: 지도 마커에서 선택된 경우 바텀시트가 해당 카드로 자동 스크롤해야 하는지 여부
  final bool shouldScrollToSelectedPlace;
  // 페이지네이션 상태
  final DocumentSnapshot? lastDocument;
  final bool hasMorePlaces;
  final bool isLoadingMore;
  // 한국어 주석: 필터링/정렬 후 남은 버퍼 데이터 (다음 페이지용)
  final List<PlaceModel>? bufferedPlaces;
  // 한국어 주석: 현재까지 표시된 장소 개수
  final int displayedCount;

  const SelectionState({
    required this.selectedCategoryId,
    required this.selectedPlaces,
    required this.showPlaceList,
    required this.selectedPlaceId,
    required this.mapStateRevision,
    required this.shouldScrollToSelectedPlace,
    this.lastDocument,
    this.hasMorePlaces = false,
    this.isLoadingMore = false,
    this.bufferedPlaces,
    this.displayedCount = 0,
  });

  const SelectionState.initial()
    : selectedCategoryId = null,
      selectedPlaces = null,
      showPlaceList = false,
      selectedPlaceId = null,
      mapStateRevision = 0,
      shouldScrollToSelectedPlace = false,
      lastDocument = null,
      hasMorePlaces = false,
      isLoadingMore = false,
      bufferedPlaces = null,
      displayedCount = 0;

  SelectionState copyWith({
    String? selectedCategoryId,
    List<PlaceModel>? selectedPlaces,
    bool? showPlaceList,
    String? selectedPlaceId,
    int? mapStateRevision,
    bool? shouldScrollToSelectedPlace,
    DocumentSnapshot? lastDocument,
    bool? hasMorePlaces,
    bool? isLoadingMore,
    List<PlaceModel>? bufferedPlaces,
    int? displayedCount,
    bool clearLastDocument = false,
    bool clearBufferedPlaces = false,
  }) {
    return SelectionState(
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedPlaces: selectedPlaces ?? this.selectedPlaces,
      showPlaceList: showPlaceList ?? this.showPlaceList,
      selectedPlaceId: selectedPlaceId ?? this.selectedPlaceId,
      mapStateRevision: mapStateRevision ?? this.mapStateRevision,
      shouldScrollToSelectedPlace:
          shouldScrollToSelectedPlace ?? this.shouldScrollToSelectedPlace,
      lastDocument: clearLastDocument
          ? null
          : (lastDocument ?? this.lastDocument),
      hasMorePlaces: hasMorePlaces ?? this.hasMorePlaces,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      bufferedPlaces: clearBufferedPlaces
          ? null
          : (bufferedPlaces ?? this.bufferedPlaces),
      displayedCount: displayedCount ?? this.displayedCount,
    );
  }

  @override
  List<Object?> get props => [
    selectedCategoryId,
    selectedPlaces,
    showPlaceList,
    selectedPlaceId,
    mapStateRevision,
    shouldScrollToSelectedPlace,
    lastDocument,
    hasMorePlaces,
    isLoadingMore,
    bufferedPlaces,
    displayedCount,
  ];
}

/// 통합 RegionInfo 상태
/// - ViewModel의 모든 상태를 하나의 불변 객체로 관리
/// - copyWith 패턴으로 상태 업데이트
/// - Equatable로 자동 동등성 비교
class RegionInfoState extends Equatable
    implements CommonLocationStateContainer<RegionInfoState> {
  @override
  final LocationState location;
  @override
  final LoadingState loading;
  @override
  final ErrorState error;
  final SelectionState selection;

  const RegionInfoState({
    required this.location,
    required this.loading,
    required this.error,
    required this.selection,
  });

  /// 초기 상태 생성
  const RegionInfoState.initial()
    : location = const LocationState.initial(),
      loading = const LoadingState.initial(),
      error = const ErrorState.initial(),
      selection = const SelectionState.initial();

  /// 상태 복사 (일부 필드만 업데이트)
  RegionInfoState copyWith({
    LocationState? location,
    LoadingState? loading,
    ErrorState? error,
    SelectionState? selection,
  }) {
    return RegionInfoState(
      location: location ?? this.location,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      selection: selection ?? this.selection,
    );
  }

  @override
  RegionInfoState copyWithCommon({
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
  String? get selectedCategoryId => selection.selectedCategoryId;
  List<PlaceModel>? get selectedPlaces => selection.selectedPlaces;
  bool get showPlaceList => selection.showPlaceList;
  String? get selectedPlaceId => selection.selectedPlaceId;
  int get mapStateRevision => selection.mapStateRevision;
  bool get shouldScrollToSelectedPlace => selection.shouldScrollToSelectedPlace;
  // 페이지네이션 getter
  DocumentSnapshot? get lastDocument => selection.lastDocument;
  bool get hasMorePlaces => selection.hasMorePlaces;
  bool get isLoadingMore => selection.isLoadingMore;

  @override
  List<Object?> get props => [location, loading, error, selection];
}
