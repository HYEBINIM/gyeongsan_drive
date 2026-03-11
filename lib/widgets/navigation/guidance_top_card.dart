import 'package:flutter/material.dart';
import '../../models/navigation/maneuver_model.dart';
import '../../services/navigation/guidance_service.dart';
import '../../utils/constants.dart';

/// 길안내 상단 카드 위젯 (네이버 지도 스타일)
/// 좌측 상단에 작은 카드로 표시 (2단 구조)
class GuidanceTopCard extends StatelessWidget {
  final ManeuverModel? currentManeuver;
  final ManeuverModel? nextManeuver;
  final double distanceToCurrentManeuverMeters; // 현재 maneuver까지 거리
  final double? distanceToNextManeuverMeters; // 다음 maneuver까지 거리
  final String pureInstructionText; // 순수 안내문구 (거리 제외)
  final bool isRecalculating;

  // GuidanceService 인스턴스 (아이콘 조회 + 거리 포맷팅용)
  final GuidanceService _guidanceService = GuidanceService();

  GuidanceTopCard({
    super.key,
    required this.currentManeuver,
    required this.nextManeuver,
    required this.distanceToCurrentManeuverMeters,
    required this.distanceToNextManeuverMeters,
    required this.pureInstructionText,
    required this.isRecalculating,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Stack(
        children: [
          // 좌측 상단: 안내 카드들
          Positioned(
            top: 0,
            left: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 재경로 탐색 배너 (필요시)
                if (isRecalculating) ...[
                  _buildRecalculatingBanner(colorScheme),
                  const SizedBox(height: 8),
                ],

                // 상단 카드 (현재 안내 - 녹색 배경)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: _buildCurrentManeuverCard(context, colorScheme),
                ),

                // 하단 카드 (다음 안내 - 반투명 배경)
                if (nextManeuver != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: _buildNextManeuverCard(context, colorScheme),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 상단 카드: 현재 maneuver (녹색 배경, 네이버 스타일)
  Widget _buildCurrentManeuverCard(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    if (currentManeuver == null) {
      return _buildArrivalCard(colorScheme);
    }

    final distanceText = _guidanceService.formatDistance(
      distanceToCurrentManeuverMeters,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primary, // Spotify Green
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.2),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 왼쪽: 큰 화살표 아이콘 (배경 없이)
          Icon(
            _guidanceService.getManeuverIcon(currentManeuver!.type),
            size: 60,
            color: colorScheme.onPrimary, // 검은색
          ),

          const SizedBox(width: 16),

          // 오른쪽: 거리 + 안내문구
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 큰 거리 숫자
              Text(
                distanceText,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimary,
                  fontFamily: AppConstants.fontFamilyBig,
                  height: 1.0,
                ),
              ),

              const SizedBox(height: 2),

              // 작은 안내문구
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  pureInstructionText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimary,
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 하단 카드: 다음 maneuver (반투명 배경)
  Widget _buildNextManeuverCard(BuildContext context, ColorScheme colorScheme) {
    if (nextManeuver == null || distanceToNextManeuverMeters == null) {
      return const SizedBox.shrink();
    }

    final distanceText = _guidanceService.formatDistance(
      distanceToNextManeuverMeters!,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 왼쪽: 작은 화살표 아이콘
          Icon(
            _guidanceService.getManeuverIcon(nextManeuver!.type),
            size: 24,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),

          const SizedBox(width: 8),

          // 오른쪽: 거리
          Text(
            distanceText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              fontFamily: AppConstants.fontFamilyBig,
            ),
          ),
        ],
      ),
    );
  }

  /// 도착 카드 (maneuver가 없을 때)
  Widget _buildArrivalCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.2),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 40, color: colorScheme.onPrimary),
          const SizedBox(width: 12),
          Text(
            '목적지에 도착했습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
              fontFamily: AppConstants.fontFamilyBig,
            ),
          ),
        ],
      ),
    );
  }

  /// 재경로 탐색 배너
  Widget _buildRecalculatingBanner(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '재경로 탐색 중...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ],
      ),
    );
  }
}
