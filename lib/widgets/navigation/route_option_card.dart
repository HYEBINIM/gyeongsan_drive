import 'package:flutter/material.dart';
import '../../models/navigation/route_model.dart';
import '../../models/navigation/route_type.dart';
import '../../models/navigation/navigation_state.dart';
import '../../utils/constants.dart';

/// 개별 경로 옵션 카드 위젯
/// 수평 스크롤 리스트에서 사용되는 전체 너비 카드
/// TransportMode에 따라 라벨이 동적으로 변경됨
class RouteOptionCard extends StatelessWidget {
  final RouteType routeType; // 경로 타입
  final RouteModel? route; // 경로 정보 (null이면 계산 중 또는 실패)
  final TransportMode transportMode; // 교통수단 (라벨 표시에 사용)
  final bool isSelected; // 선택 여부
  final VoidCallback onTap; // 탭 콜백
  final VoidCallback onStartGuidance; // 안내시작 버튼 콜백

  const RouteOptionCard({
    super.key,
    required this.routeType,
    required this.route,
    required this.transportMode,
    required this.isSelected,
    required this.onTap,
    required this.onStartGuidance,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 선택 상태에 따른 스타일 변수
    final double borderOpacity = isSelected ? 0.5 : 0.3;
    final double borderWidth = isSelected ? 2.0 : 1.5;
    final double shadowBlur = isSelected ? 30.0 : 20.0;
    final double shadowOpacity = isSelected ? 0.12 : 0.08;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: borderOpacity),
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.scrim.withValues(alpha: shadowOpacity),
              blurRadius: shadowBlur,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: route != null
            ? _buildRouteContent(context)
            : _buildLoadingOrError(),
      ),
    );
  }

  /// 경로 정보 컨텐츠
  Widget _buildRouteContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 왼쪽: 메인 컨텐츠 (경로 정보)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 경로 타입 라벨
                // TransportMode에 따라 다른 라벨 표시
                Text(
                  routeType.labelForMode(transportMode),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
                const SizedBox(height: 3),

                // 경로 설명 (서브텍스트)
                Text(
                  routeType.descriptionForMode(transportMode),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // 예상 시간 (큰 파란색 글씨)
                Text(
                  '${route!.estimatedMinutes}분',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontFamily: AppConstants.fontFamilyBig,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),

                // 거리 (회색)
                Text(
                  '${route!.totalDistanceKm.toStringAsFixed(1)}km',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 오른쪽: 안내시작 버튼 (아이콘 + 텍스트 수직 배치)
          SizedBox(
            width: 100,
            child: ElevatedButton(
              onPressed: onStartGuidance,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.near_me, size: 40),
                  const SizedBox(height: 4),
                  const Text(
                    '안내시작',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 로딩 또는 에러 상태
  Widget _buildLoadingOrError() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
