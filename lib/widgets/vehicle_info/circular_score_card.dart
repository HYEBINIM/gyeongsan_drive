import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../utils/constants.dart';

/// 원형 점수 카드 위젯 (내 운전점수)
class CircularScoreCard extends StatelessWidget {
  final int score; // 점수 (0-100)
  final String title; // 카드 제목

  const CircularScoreCard({
    super.key,
    required this.score,
    this.title = '내 운전점수',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 제목
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontFamily: AppConstants.fontFamilySmall,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          // 원형 게이지
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: SfRadialGauge(
                axes: <RadialAxis>[
                  RadialAxis(
                    minimum: 0,
                    maximum: 100,
                    showLabels: false,
                    showTicks: false,
                    startAngle: 150,
                    endAngle: 390,
                    radiusFactor: 1.0,
                    axisLineStyle: AxisLineStyle(
                      thickness: 0.15,
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      thicknessUnit: GaugeSizeUnit.factor,
                    ),
                    pointers: <GaugePointer>[
                      RangePointer(
                        value: score.toDouble(),
                        width: 0.15,
                        sizeUnit: GaugeSizeUnit.factor,
                        color: colorScheme.primary,
                        enableAnimation: true,
                        animationDuration: 1000,
                        animationType: AnimationType.ease,
                      ),
                    ],
                    annotations: <GaugeAnnotation>[
                      GaugeAnnotation(
                        angle: 90,
                        positionFactor: 0.1,
                        widget: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$score',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                fontFamily: AppConstants.fontFamilyBig,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '점',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: AppConstants.fontFamilySmall,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
