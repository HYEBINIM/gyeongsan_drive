import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 길안내 하단 정보 바 위젯
/// 도착 예정 시간, 남은 거리, 현재 속도 표시
class GuidanceBottomBar extends StatelessWidget {
  final double remainingDistanceKm;
  final int remainingMinutes;
  final double currentSpeedKmh;

  const GuidanceBottomBar({
    super.key,
    required this.remainingDistanceKm,
    required this.remainingMinutes,
    required this.currentSpeedKmh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final eta = now.add(Duration(minutes: remainingMinutes));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 도착 예정 시간
            _buildInfoItem(
              context,
              icon: Icons.access_time,
              label: '도착',
              value: _formatTime(eta),
            ),

            // 구분선
            Container(
              height: 40,
              width: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),

            // 남은 거리
            _buildInfoItem(
              context,
              icon: Icons.route,
              label: '남은 거리',
              value: '${remainingDistanceKm.toStringAsFixed(1)}km',
            ),

            // 구분선
            Container(
              height: 40,
              width: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),

            // 현재 속도
            _buildInfoItem(
              context,
              icon: Icons.speed,
              label: '속도',
              value: '${currentSpeedKmh.toStringAsFixed(0)}km/h',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 라벨
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // 값
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            fontFamily: AppConstants.fontFamilyBig,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');

    if (hour < 12) {
      return '오전 $hour:$minute';
    } else if (hour == 12) {
      return '오후 12:$minute';
    } else {
      return '오후 ${hour - 12}:$minute';
    }
  }
}
