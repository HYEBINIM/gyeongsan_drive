import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import '../../models/vehicle_data_model.dart';
import '../../utils/constants.dart';

/// 배터리 정보 카드 위젯
class BatteryInfoCard extends StatelessWidget {
  final VehicleData data;

  const BatteryInfoCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 배경 컬러 스킴 계산
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        // 그림자 생략
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.battery_charging_full,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '배터리 정보',
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
          // 한글 주석: 한 줄에 4개 항목 표기(온도/전압/전류/급속 충전 횟수)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildInfoItem(
                  context,
                  '배터리 온도',
                  data.averageTemperature.toStringAsFixed(0),
                  '℃',
                  Icons.thermostat,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  context,
                  '배터리 전압',
                  data.hvPackVoltage.toStringAsFixed(2),
                  'v',
                  Icons.electric_bolt,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  context,
                  '배터리 전류',
                  data.hvPackCurrent.toStringAsFixed(2),
                  'A',
                  Icons.flash_on,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  context,
                  '급속 충전 횟수',
                  data.quickChargeCount.toString(),
                  '회',
                  Remix.charging_pile_2_fill,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 정보 아이템 블록
  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontFamily: AppConstants.fontFamilySmall,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
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
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
