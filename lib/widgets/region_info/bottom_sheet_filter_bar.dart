import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import '../../utils/constants.dart';

/// 바텀시트 필터 바 위젯
class BottomSheetFilterBar extends StatelessWidget {
  final VoidCallback onClose;

  const BottomSheetFilterBar({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 현위치 중심 필터
          _buildFilterLabel(colorScheme: colorScheme, label: '현위치 중심'),
          const SizedBox(width: 8),
          // 거리순 필터
          _buildFilterLabel(colorScheme: colorScheme, label: '거리순'),
          // 우측 정렬을 위한 Spacer
          const Spacer(),
          // X 버튼
          GestureDetector(
            onTap: onClose,
            child: Icon(
              Remix.close_line,
              size: 20,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 필터 라벨 빌더 (버튼 모양 없음)
  Widget _buildFilterLabel({
    required ColorScheme colorScheme,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurface,
            fontFamily: AppConstants.fontFamilySmall,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Remix.arrow_down_s_line,
          size: 14,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ],
    );
  }
}
