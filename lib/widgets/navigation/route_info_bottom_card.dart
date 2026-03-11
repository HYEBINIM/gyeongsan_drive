import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../models/navigation/route_model.dart';
import '../../models/navigation/route_type.dart';
import '../../models/navigation/navigation_state.dart';
import 'route_option_card.dart';

/// 하단 경로 정보 수평 스크롤 카드 위젯 (PageView 방식)
/// TransportMode에 따라 표시되는 경로 타입이 동적으로 변경됨
class RouteInfoBottomCard extends StatefulWidget {
  final Map<RouteType, RouteModel?> routes; // 경로 타입별 경로 맵
  final RouteType selectedRouteType; // 현재 선택된 경로 타입
  final TransportMode transportMode; // 교통수단 (경로 타입 필터링에 사용)
  final bool isCalculating; // 경로 계산 중 여부
  final Function(RouteType) onRouteTypeSelected; // 경로 타입 선택 콜백
  final VoidCallback onStartGuidance; // 안내 시작 버튼 콜백

  const RouteInfoBottomCard({
    super.key,
    required this.routes,
    required this.selectedRouteType,
    required this.transportMode,
    required this.isCalculating,
    required this.onRouteTypeSelected,
    required this.onStartGuidance,
  });

  @override
  State<RouteInfoBottomCard> createState() => _RouteInfoBottomCardState();
}

class _RouteInfoBottomCardState extends State<RouteInfoBottomCard> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _initPageController();
  }

  /// PageController 초기화
  /// TransportMode에 따라 사용 가능한 경로 타입 목록에서 인덱스 계산
  void _initPageController() {
    final availableRouteTypes = RouteTypeExtension.availableTypes(
      widget.transportMode,
    );
    final initialPage = availableRouteTypes.indexOf(widget.selectedRouteType);

    _pageController = PageController(
      initialPage: initialPage >= 0 ? initialPage : 0,
      viewportFraction: 0.95, // 다음 카드가 살짝 보이도록 설정
    );
  }

  @override
  void didUpdateWidget(RouteInfoBottomCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // TransportMode가 변경되면 PageController 재생성
    if (widget.transportMode != oldWidget.transportMode) {
      _pageController.dispose();
      _initPageController();
      return;
    }

    // 선택된 경로 타입이 외부에서 변경되면 페이지 이동
    if (widget.selectedRouteType != oldWidget.selectedRouteType) {
      final availableRouteTypes = RouteTypeExtension.availableTypes(
        widget.transportMode,
      );
      final newPage = availableRouteTypes.indexOf(widget.selectedRouteType);

      if (newPage >= 0 && _pageController.hasClients) {
        _pageController.animateToPage(
          newPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.transparent, // 배경 투명
      child: widget.routes.isEmpty
          ? (widget.isCalculating
                ? _buildLoadingState(colorScheme)
                : _buildEmptyState(colorScheme))
          : _buildRouteCards(),
    );
  }

  /// 로딩 상태
  Widget _buildLoadingState(ColorScheme colorScheme) {
    return SizedBox(
      height: 120, // 경로 카드와 동일한 높이
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.scrim.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 12),
              const SizedBox(height: 12),
              Text(
                '경로를 계산하는 중...',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 경로 정보 없음 상태
  Widget _buildEmptyState(ColorScheme colorScheme) {
    return SizedBox(
      height: 120, // 경로 카드와 동일한 높이
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.scrim.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '경로를 계산할 수 없습니다',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  /// 경로 카드 수평 스크롤 (PageView - 한 번에 한 카드씩)
  /// TransportMode에 따라 표시되는 경로 타입이 동적으로 변경됨
  Widget _buildRouteCards() {
    // TransportMode에 따라 사용 가능한 경로 타입만 필터링
    final availableRouteTypes = RouteTypeExtension.availableTypes(
      widget.transportMode,
    );

    return SizedBox(
      height: 120, // 카드 높이 고정 (컴팩트하게)
      child: PageView.builder(
        controller: _pageController,
        itemCount: availableRouteTypes.length, // 동적 개수
        padEnds: false, // 양쪽 끝에 패딩 없이 카드 배치
        onPageChanged: (index) {
          // 페이지 변경 시 선택된 경로 타입 업데이트
          final routeType = availableRouteTypes[index];
          widget.onRouteTypeSelected(routeType);
        },
        itemBuilder: (context, index) {
          final routeType = availableRouteTypes[index];
          final route = widget.routes[routeType];
          final isSelected = routeType == widget.selectedRouteType;

          return RouteOptionCard(
            routeType: routeType,
            route: route,
            transportMode: widget.transportMode, // TransportMode 전달
            isSelected: isSelected,
            onTap: () {
              // 카드 탭 시 해당 페이지로 이동
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            onStartGuidance: widget.onStartGuidance,
          );
        },
      ),
    );
  }
}
