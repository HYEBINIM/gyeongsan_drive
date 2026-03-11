import 'package:flutter/material.dart';
import '../../models/battery_status_model.dart';
import '../../utils/constants.dart';

/// 배터리 상태 정보 위젯
class BatteryStatusInfoGrid extends StatelessWidget {
  final BatteryStatusData batteryData;

  const BatteryStatusInfoGrid({super.key, required this.batteryData});

  @override
  Widget build(BuildContext context) {
    // 테마 색상 스키마 가져오기
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 + 툴팁 아이콘
          Row(
            children: [
              Text(
                '배터리 상태',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 5),
              Tooltip(
                message: '선택한 월의 배터리 건강도(SOH) 통계 및 변화 추이',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                textStyle: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onPrimary,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 첫 번째 행 (핵심 지표)
          Row(
            children: [
              Expanded(
                child: _buildInfoCell(
                  label: '평균',
                  value: '${batteryData.monthlyAverageSOH.toStringAsFixed(1)}%',
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCell(
                  label: '변화율',
                  value:
                      '${batteryData.monthlyChange >= 0 ? '+' : ''}${batteryData.monthlyChange.toStringAsFixed(2)}%',
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCell(
                  label: '안정성',
                  value: batteryData.stabilityStatus,
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 두 번째 행 (상세 통계)
          Row(
            children: [
              Expanded(
                child: _buildInfoCell(
                  label: '최대',
                  value: '${batteryData.maxSOH.toStringAsFixed(1)}%',
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCell(
                  label: '최소',
                  value: '${batteryData.minSOH.toStringAsFixed(1)}%',
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCell(
                  label: '표준편차',
                  value:
                      '±${batteryData.standardDeviation.toStringAsFixed(2)}%',
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 정보 셀 (라벨 + 값)
  Widget _buildInfoCell({
    required String label,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: AppConstants.fontFamilySmall,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: AppConstants.fontFamilyBig,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
