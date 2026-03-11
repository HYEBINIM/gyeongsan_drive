import 'package:flutter/material.dart';
import '../../models/vehicle_data_model.dart';
import '../../utils/constants.dart';

/// 배터리 세부 정보 카드 위젯
class BatteryDetailCard extends StatelessWidget {
  final VehicleData data;

  const BatteryDetailCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 테마 색상 스키마 가져오기
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        // 그림자 제거
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '배터리 세부 정보',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppConstants.fontFamilyBig,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  context,
                  '셀 Max 전압',
                  data.cellVoltageMax.toStringAsFixed(2),
                  'v',
                  Icons.arrow_upward,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  context,
                  '셀 Min 전압',
                  data.cellVoltageMin.toStringAsFixed(2),
                  'v',
                  Icons.arrow_downward,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  context,
                  '모듈 Max 온도',
                  data.maxTemperature.toStringAsFixed(0),
                  '°C',
                  Icons.thermostat,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  context,
                  '모듈 Min 온도',
                  data.minTemperature.toStringAsFixed(0),
                  '°C',
                  Icons.ac_unit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 정보 항목 위젯
  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontFamily: AppConstants.fontFamilyBig,
                  ),
                ),
                WidgetSpan(child: SizedBox(width: 2)),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
