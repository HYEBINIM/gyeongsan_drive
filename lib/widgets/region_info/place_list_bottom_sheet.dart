import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/place_model.dart';
import '../../models/region_info_state.dart';
import '../../utils/constants.dart';
import '../../view_models/region_info/region_info_viewmodel.dart';
import 'bottom_sheet_filter_bar.dart';
import 'place_item_card.dart';

// 한국어 주석: 바텀시트 확장 비율 업데이트 시 드래그 중/종료 여부를 함께 전달하기 위한 콜백 타입
typedef PlaceSheetExtentCallback =
    void Function(double extent, bool isFinalExtent);

// 한국어 주석: 바텀시트 드래그 로직 기본값 (한 곳에서 관리하여 DRY 유지)
const double kPlaceListMinChildSize = 0.1; // 10%
const double kPlaceListInitialChildSize = 0.5; // 50%
const double kPlaceListMaxChildSize = 0.9; // 90%

/// 장소 목록 바텀시트
class PlaceListBottomSheet extends StatefulWidget {
  final String categoryName;
  final List<PlaceModel> places;
  // 한국어 주석: 선택된 장소 ID (지도 마커/리스트 탭 연동용)
  final String? selectedPlaceId;
  // 한국어 주석: 이번 빌드 사이클 동안 선택된 장소 카드로 자동 스크롤이 필요한지 여부
  // - true: 지도 마커에서 선택된 경우
  // - false: 바텀시트 카드에서 선택된 경우 (스크롤 없음)
  final bool shouldScrollToSelectedPlace;
  // 한국어 주석: 바텀시트의 현재 확장 비율(0.0~1.0)을 상위에 알리는 콜백
  final PlaceSheetExtentCallback? onExtentChanged;
  // 페이지네이션 상태
  final bool hasMore;
  final bool isLoadingMore;

  const PlaceListBottomSheet({
    super.key,
    required this.categoryName,
    required this.places,
    required this.shouldScrollToSelectedPlace,
    this.selectedPlaceId,
    this.onExtentChanged,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  @override
  State<PlaceListBottomSheet> createState() => _PlaceListBottomSheetState();
}

// 한국어 주석: 드래그 알림을 프레임마다 모두 전달하면 상위에서 잦은 setState가 발생하여
// 프레임 드랍(끊김 느낌)을 유발할 수 있습니다. 여기서 미세 변화는 묶어(throttle) 전달합니다.
class _PlaceListBottomSheetState extends State<PlaceListBottomSheet> {
  // 한국어 주석: 마지막으로 알린 확장 비율 (불필요한 중복 알림 방지)
  double _lastNotifiedExtent = -1;
  // 한국어 주석: 변화 임계값(1%) — 이 값보다 작은 변화는 무시하여 잔떨림 감소
  static const double _kExtentNotifyEpsilon = 0.01;
  // 한국어 주석: 선택된 장소 카드로 스크롤하기 위한 상태
  String? _lastScrolledPlaceId;
  // 한국어 주석: 바텀시트 높이 제어를 위한 컨트롤러 (헤더 드래그 전용)
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  // 한국어 주석: 카드별 실제 위치 계산을 위한 GlobalKey 맵
  final Map<String, GlobalKey> _itemKeys = {};
  // 한국어 주석: 카드 리스트 전용 스크롤 컨트롤러
  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 한국어 주석: 최초 빌드 시 현재 목록과 동기화하여 불필요한 키 누수를 방지
    _syncItemKeysWithPlaces();
    // 한국어 주석: 최초 빌드 이후 선택된 카드가 있다면 한 번 스크롤 정렬
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedPlaceIfNeeded();
    });
    // 한국어 주석: 무한 스크롤을 위한 스크롤 리스너 추가
    _listScrollController.addListener(_onScroll);
  }

  // 한국어 주석: 스크롤 위치가 끝에 가까워지면 다음 페이지 로드
  void _onScroll() {
    if (!_listScrollController.hasClients) return;

    final maxScroll = _listScrollController.position.maxScrollExtent;
    final currentScroll = _listScrollController.position.pixels;
    // 한국어 주석: 끝에서 200px 전에 다음 페이지 로드 시작
    const threshold = 200.0;

    if (maxScroll - currentScroll <= threshold) {
      // 한국어 주석: 더 불러올 데이터가 있고 로딩 중이 아닐 때만
      if (widget.hasMore && !widget.isLoadingMore) {
        context.read<RegionInfoViewModel>().loadMorePlaces();
      }
    }
  }

  @override
  void dispose() {
    _listScrollController.removeListener(_onScroll);
    _listScrollController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlaceListBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool didPlacesChange = !identical(oldWidget.places, widget.places);

    // 한국어 주석: 카테고리/목록이 바뀌면 스크롤 기준을 초기화
    if (didPlacesChange) {
      _lastScrolledPlaceId = null;
    }

    // 한국어 주석: 최신 목록과 동기화하여 제거된 카드의 키를 정리
    _syncItemKeysWithPlaces();

    // 한국어 주석: 선택된 장소가 변경되면 해당 카드가 보이도록 스크롤
    // 수정: null → 값 / 값 → 다른 값 모두 포함 (바텀시트 재개 및 다른 마커 선택)
    if (widget.selectedPlaceId != oldWidget.selectedPlaceId) {
      // 한국어 주석: 같은 장소라도 다시 스크롤해야 할 수 있으므로 매번 초기화
      _lastScrolledPlaceId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedPlaceIfNeeded();
      });
    }
  }

  // 한국어 주석: 선택된 장소 카드로 스크롤 (재시도 로직 포함)
  void _scrollToSelectedPlaceIfNeeded() {
    // 한국어 주석: 바텀시트가 이 빌드 사이클에서 스크롤을 수행해야 하는 경우에만 동작
    if (!widget.shouldScrollToSelectedPlace) {
      return;
    }

    final selectedId = widget.selectedPlaceId;

    if (selectedId == null || selectedId.isEmpty) {
      return;
    }

    // 한국어 주석: 중복 스크롤 방지는 didUpdateWidget에서 _lastScrolledPlaceId를 null로 초기화하여 처리
    if (_lastScrolledPlaceId == selectedId) {
      return;
    }

    _performScrollToKey(selectedId, retryCount: 0);
  }

  // 한국어 주석: GlobalKey를 사용하여 실제 카드 위치를 기준으로 스크롤합니다.
  // Scrollable.ensureVisible을 사용하여 항상 동일한 상대 위치(alignment)에 카드가 보이도록 합니다.
  void _performScrollToKey(String placeId, {required int retryCount}) {
    final targetKey = _itemKeys[placeId];
    final cardContext = targetKey?.currentContext;

    // 한국어 주석: context가 null이면 아직 렌더링되지 않은 상태이므로 다음 프레임에서 재시도
    if (cardContext == null && retryCount < 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _performScrollToKey(placeId, retryCount: retryCount + 1);
        }
      });
      return;
    }

    if (cardContext != null) {
      _lastScrolledPlaceId = placeId;
      Scrollable.ensureVisible(
        cardContext,
        duration: const Duration(milliseconds: 250),
        // 한국어 주석: 항상 화면 상단에서 약간 아래(10%) 지점에 카드가 위치하도록 정렬
        alignment: 0.1,
        curve: Curves.easeOutCubic,
      );

      // 한국어 주석: 자동 스크롤을 한 번 수행했으므로 ViewModel의 플래그를 초기화
      context.read<RegionInfoViewModel>().markScrollToSelectedPlaceHandled();
    } else {
      // 한국어 주석: 여러 번 재시도 후에도 실패한 경우 플래그만 초기화하여 무한 재시도를 방지
      context.read<RegionInfoViewModel>().markScrollToSelectedPlaceHandled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 한국어 주석: 뒤로가기 버튼 동작을 커스터마이징
      canPop: false, // 기본 pop 동작 방지
      onPopInvokedWithResult: (didPop, result) {
        // 한국어 주석: pop이 발생하지 않았을 때 바텀시트 닫기 (X 버튼과 동일)
        if (!didPop) {
          context.read<RegionInfoViewModel>().hidePlaceList();
        }
      },
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          // 한국어 주석: 바텀시트의 현재 확장 비율을 상위로 전달(스로틀 적용)
          final extent = notification.extent;
          if (_shouldNotifyExtent(extent)) {
            _lastNotifiedExtent = extent;
            widget.onExtentChanged?.call(extent, false);
          }
          return false; // 다른 리스너로 전파 허용
        },
        child: NotificationListener<ScrollEndNotification>(
          // 한국어 주석: 드래그가 끝난 시점에는 최종 값을 한 번 더 보장 전달
          onNotification: (end) {
            if (_lastNotifiedExtent >= 0) {
              widget.onExtentChanged?.call(_lastNotifiedExtent, true);
            }
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: kPlaceListInitialChildSize, // 초기 높이
            minChildSize: kPlaceListMinChildSize, // 최소 높이
            maxChildSize: kPlaceListMaxChildSize, // 최대 높이
            builder: (context, scrollController) {
              final colorScheme = Theme.of(context).colorScheme;

              // 한국어 주석: BoxShadow(blur) 대신 Material.elevation을 사용하여 그림자 렌더링 비용 절감
              return Material(
                color: colorScheme.surface,
                elevation: 8,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                // 한국어 주석: 안티에일리어싱은 GPU 비용이 커서 드래그 중 프레임 드랍 유발 가능
                // 고해상도 단말 기준으로 hardEdge가 시각 차이가 적어 비용 대비 효과가 큽니다.
                clipBehavior: Clip.hardEdge,
                child: Selector<RegionInfoViewModel, LoadingErrorState>(
                  selector: (context, viewModel) => LoadingErrorState(
                    isLoading: viewModel.isLoading,
                    hasLocation: viewModel.hasLocation,
                    errorMessage: viewModel.errorMessage,
                  ),
                  builder: (context, state, child) {
                    // 로딩 중
                    if (state.isLoading) {
                      return Column(
                        children: [
                          _buildDragHandle(colorScheme),
                          BottomSheetFilterBar(
                            onClose: () {
                              context
                                  .read<RegionInfoViewModel>()
                                  .hidePlaceList();
                            },
                          ),
                          Expanded(
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // 에러 발생
                    if (state.errorMessage != null) {
                      return Column(
                        children: [
                          _buildDragHandle(colorScheme),
                          BottomSheetFilterBar(
                            onClose: () {
                              context
                                  .read<RegionInfoViewModel>()
                                  .hidePlaceList();
                            },
                          ),
                          Expanded(
                            child: _buildErrorState(
                              colorScheme,
                              state.errorMessage!,
                            ),
                          ),
                        ],
                      );
                    }

                    // 데이터 없음
                    if (widget.places.isEmpty) {
                      return Column(
                        children: [
                          _buildDragHandle(colorScheme),
                          BottomSheetFilterBar(
                            onClose: () {
                              context
                                  .read<RegionInfoViewModel>()
                                  .hidePlaceList();
                            },
                          ),
                          Expanded(child: _buildEmptyState(colorScheme)),
                        ],
                      );
                    }

                    // 데이터 표시 - 헤더는 고정, 카드 리스트만 독립적으로 스크롤되도록 구성
                    // 한국어 주석: 숨겨진 Scrollable에 builder의 scrollController를 연결하여
                    // DraggableScrollableSheet와의 attach 상태를 유지합니다.
                    return Column(
                      children: [
                        Offstage(
                          offstage: true,
                          child: ListView(
                            controller: scrollController,
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            children: const [SizedBox.shrink()],
                          ),
                        ),
                        _buildInteractiveHeader(colorScheme),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _listScrollController,
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              children: [
                                ...widget.places.map((place) {
                                  final itemKey = _ensureItemKey(place.id);
                                  return PlaceItemCard(
                                    key: itemKey,
                                    place: place,
                                    onTap: () {
                                      context.read<RegionInfoViewModel>()
                                      // 한국어 주석: 바텀시트 카드 탭은 지도만 이동하고,
                                      // 바텀시트 자동 스크롤은 발생하지 않도록 fromMap=false 사용
                                      .selectPlace(place.id, fromMap: false);
                                    },
                                  );
                                }),
                                // 한국어 주석: 무한 스크롤 로딩 인디케이터
                                if (widget.isLoadingMore)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              colorScheme.primary,
                                            ),
                                      ),
                                    ),
                                  ),
                                // 한국어 주석: 더 불러올 데이터가 있을 때 여백 추가
                                if (widget.hasMore && !widget.isLoadingMore)
                                  const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ), // child: NotificationListener<ScrollEndNotification>
      ), // child: NotificationListener<DraggableScrollableNotification>
    ); // PopScope
  }

  // 한국어 주석: 미세한 변화를 걸러 상위 rebuild 빈도를 줄이는 헬퍼
  bool _shouldNotifyExtent(double next) {
    if (_lastNotifiedExtent < 0) return true; // 첫 프레임은 무조건 전달
    // 한국어 주석: 최대/최소 근처에서는 작은 변화도 전달하여 정밀도 보장
    const double kEdge = 0.02;
    if ((next - kPlaceListMinChildSize).abs() < kEdge) return true;
    if ((next - kPlaceListMaxChildSize).abs() < kEdge) return true;
    return (next - _lastNotifiedExtent).abs() >= _kExtentNotifyEpsilon;
  }

  /// 드래그 핸들
  Widget _buildDragHandle(ColorScheme colorScheme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // 한국어 주석: 헤더(드래그 핸들 + 필터 바)를 감싸
  // 세로 드래그 시 DraggableScrollableSheet 높이가 변경되도록 구현
  Widget _buildInteractiveHeader(ColorScheme colorScheme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _handleHeaderDragUpdate,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(colorScheme),
          BottomSheetFilterBar(
            onClose: () {
              context.read<RegionInfoViewModel>().hidePlaceList();
            },
          ),
        ],
      ),
    );
  }

  /// 빈 상태
  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '검색 결과가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 상태
  Widget _buildErrorState(ColorScheme colorScheme, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 한국어 주석: 현재 목록에 포함된 장소만 키를 유지하여 폐기된 카드 참조를 정리
  void _syncItemKeysWithPlaces() {
    final validIds = widget.places.map((place) => place.id).toSet();
    _itemKeys.removeWhere((placeId, _) => !validIds.contains(placeId));
    for (final place in widget.places) {
      _itemKeys.putIfAbsent(
        place.id,
        () => GlobalKey(debugLabel: 'place_card_${place.id}'),
      );
    }
  }

  // 한국어 주석: ensureVisible 호출 시 재사용할 수 있도록 GlobalKey를 반환하는 헬퍼
  GlobalKey _ensureItemKey(String placeId) {
    return _itemKeys.putIfAbsent(
      placeId,
      () => GlobalKey(debugLabel: 'place_card_$placeId'),
    );
  }

  // 한국어 주석: 헤더 드래그 제스처를 DraggableScrollableSheet 높이로 변환
  // - dy(화면 픽셀)를 화면 전체 높이 대비 비율로 환산하여 extent를 증감
  void _handleHeaderDragUpdate(DragUpdateDetails details) {
    // 한국어 주석: 시트가 attach되기 전에는 컨트롤러를 사용하지 않음
    if (!_sheetController.isAttached) {
      return;
    }

    final maxHeight = MediaQuery.of(context).size.height;
    if (maxHeight <= 0) {
      return;
    }

    final currentExtent = _sheetController.size;
    // 한국어 주석: 사용자가 아래로 드래그하면 시트가 내려가고 (닫히고)
    // 위로 드래그하면 시트가 올라가도록 부호를 반대로 설정
    final deltaExtent = -details.delta.dy / maxHeight;
    final targetExtent = (currentExtent + deltaExtent).clamp(
      kPlaceListMinChildSize,
      kPlaceListMaxChildSize,
    );

    _sheetController.jumpTo(targetExtent);
  }
}

// 한국어 주석: SliverPersistentHeader용 델리게이트
// - 헤더(드래그 핸들 + 필터 바)를 항상 상단에 고정
// - 헤더 영역에서 발생하는 드래그 제스처도 DraggableScrollableSheet와 연동
