import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/battery_status_model.dart';
import '../../utils/constants.dart';

/// SOH 라인 차트 위젯
class SOHLineChart extends StatelessWidget {
  final List<DailySOH> dailySOHList; // 일자별 SOH 목록
  final double averageSOH; // 월평균 SOH (평균선 표시용)

  const SOHLineChart({
    super.key,
    required this.dailySOHList,
    required this.averageSOH,
  });

  @override
  Widget build(BuildContext context) {
    // 테마 색상 스키마 가져오기
    final colorScheme = Theme.of(context).colorScheme;

    // SOH 데이터가 비어있으면 빈 상태 표시
    if (dailySOHList.isEmpty) {
      return _buildEmptyChart(colorScheme);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
                'SOH 추이',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 5),
              Tooltip(
                message: '일별 배터리 건강도(SOH) 변화 추이',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                textStyle: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onInverseSurface,
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
          const SizedBox(height: 16),
          // 차트
          SizedBox(height: 200, child: LineChart(_buildChartData(colorScheme))),
          const SizedBox(height: 12),
          // 범례
          _buildLegend(colorScheme),
        ],
      ),
    );
  }

  /// 빈 차트 상태
  Widget _buildEmptyChart(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
                'SOH 추이',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 5),
              Tooltip(
                message: '일별 배터리 건강도(SOH) 변화 추이',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                textStyle: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onInverseSurface,
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
          const SizedBox(height: 40),
          Center(
            child: Text(
              '데이터가 없습니다',
              style: TextStyle(
                fontSize: 14,
                fontFamily: AppConstants.fontFamilySmall,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 차트 데이터 생성
  LineChartData _buildChartData(ColorScheme colorScheme) {
    // SOH 값 범위 계산
    final sohValues = dailySOHList.map((e) => e.soh).toList();
    final minSOH = sohValues.reduce((a, b) => a < b ? a : b);
    final maxSOH = sohValues.reduce((a, b) => a > b ? a : b);

    // Y축 범위 설정 (최소값-2%, 최대값+2%)
    final yMin = (minSOH - 2).clamp(0, 100);
    final yMax = (maxSOH + 2).clamp(0, 100);

    // LineChartBarData 생성
    final spots = dailySOHList.asMap().entries.map((entry) {
      final index = entry.key;
      final dailySOH = entry.value;
      return FlSpot(index.toDouble(), dailySOH.soh);
    }).toList();

    return LineChartData(
      minY: yMin.toDouble(),
      maxY: yMax.toDouble(),
      lineBarsData: [
        // SOH 라인
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: colorScheme.primary,
          barWidth: 3,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: colorScheme.primary,
                strokeWidth: 2,
                strokeColor: colorScheme.surface,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: 0.2),
                colorScheme.primary.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      // 평균선 (점선)
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: averageSOH,
            color: Colors.orange,
            strokeWidth: 2,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 5, bottom: 5),
              style: TextStyle(
                fontSize: 10,
                fontFamily: AppConstants.fontFamilySmall,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
              labelResolver: (line) => '평균 ${averageSOH.toStringAsFixed(1)}%',
            ),
          ),
        ],
      ),
      titlesData: FlTitlesData(
        // 상단 제목 숨김
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        // 우측 제목 숨김
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        // 하단 제목 (날짜)
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: dailySOHList.length > 10 ? 5 : 2,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= dailySOHList.length) {
                return const SizedBox();
              }
              final date = dailySOHList[index].date;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${date.day}일',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: AppConstants.fontFamilySmall,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              );
            },
          ),
        ),
        // 좌측 제목 (SOH %)
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: (yMax - yMin) / 4,
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.toInt()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (yMax - yMin) / 4,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            strokeWidth: 1,
          );
        },
      ),
      borderData: FlBorderData(show: false),
      // 터치 인터랙션
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => colorScheme.inverseSurface,
          tooltipBorderRadius: BorderRadius.circular(8),
          tooltipPadding: const EdgeInsets.all(8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              if (index < 0 || index >= dailySOHList.length) {
                return null;
              }
              final date = dailySOHList[index].date;
              final soh = spot.y;
              return LineTooltipItem(
                '${date.month}월 ${date.day}일\n',
                TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: colorScheme.onInverseSurface,
                ),
                children: [
                  TextSpan(
                    text: 'SOH: ${soh.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      fontFamily: AppConstants.fontFamilySmall,
                      color: colorScheme.onInverseSurface,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }

  /// 범례
  Widget _buildLegend(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // SOH 라인 범례
        Row(
          children: [
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'SOH',
              style: TextStyle(
                fontSize: 12,
                fontFamily: AppConstants.fontFamilySmall,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        // 평균선 범례
        Row(
          children: [
            Container(
              width: 16,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '평균',
              style: TextStyle(
                fontSize: 12,
                fontFamily: AppConstants.fontFamilySmall,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
