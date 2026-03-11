import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/driving_score_model.dart';
import '../../utils/constants.dart';

/// 주간 점수 막대 그래프 위젯 (이미지와 동일한 컴팩트 스타일)
/// - 외부 라이브러리 대신 가벼운 커스텀 위젯으로 구현하여 정확한 모양을 유지
/// - 각 막대는 세로 진행도 형태의 캡슐(track + fill)로 표현
/// - 각 막대 클릭 시 해당 날짜 선택 가능
class WeeklyScoreChart extends StatelessWidget {
  /// 주간 점수 데이터
  final List<DailyScore> weeklyScores;

  /// 날짜 선택 콜백
  final ValueChanged<DateTime>? onDateSelected;

  /// 현재 선택된 날짜
  final DateTime? selectedDate;

  const WeeklyScoreChart({
    super.key,
    required this.weeklyScores,
    this.onDateSelected,
    this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 디자인 값 상수화(필요 이상의 복잡도는 배제: KISS/YAGNI)
    const double cardRadius = 16;
    const double barTrackWidth = 24;
    const double barHeight = 110; // 트랙(배경 캡슐) 고정 높이
    const double horizontalPadding = 14;
    const double minGap = 18; // 막대 간 최소 간격

    // 카드 컨테이너: 밝은 배경 + 소프트 그림자 (이미지 유사)
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      // 전체 높이를 컴팩트하게 유지
      height: 200,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 막대 간 간격: 고정값 사용
          final count = weeklyScores.length;
          final double gap = minGap;

          // Expanded를 사용하여 열 폭을 동일하게 맞추고 텍스트 잘림 방지
          final List<Widget> barColumns = [];

          for (var i = 0; i < count; i++) {
            final daily = weeklyScores[i];
            final int clampedScore = daily.score.clamp(0, 100).toInt();
            final double value = clampedScore / 100.0; // 0.0 ~ 1.0
            final String dateStr = DateFormat('MM/dd').format(daily.date);

            // 날짜 정규화 (시간 제거하여 비교)
            final normalizedDate = DateTime(
              daily.date.year,
              daily.date.month,
              daily.date.day,
            );
            final normalizedSelectedDate = selectedDate != null
                ? DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                  )
                : null;

            // 선택된 날짜인지 확인 (선택 안 되었으면 마지막 날짜가 기본)
            final isSelected = normalizedSelectedDate != null
                ? normalizedDate == normalizedSelectedDate
                : (i == count - 1);

            barColumns.add(
              Expanded(
                child: GestureDetector(
                  onTap: () => onDateSelected?.call(daily.date),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 상단 점수 라벨 (가운데 정렬, 막대와 동일한 너비로 픽셀 퍼펙트 정렬)
                      SizedBox(
                        width: barTrackWidth,
                        child: Text(
                          '${daily.score}점',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.0,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppConstants.fontFamilySmall,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 막대 영역 (트랙 + 진행도)
                      SizedBox(
                        height: barHeight,
                        width: barTrackWidth,
                        child: _CapsuleBar(
                          value: value,
                          highlight: isSelected,
                          colorScheme: colorScheme,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 하단 날짜 라벨 (가운데 정렬, 막대와 동일한 너비로 픽셀 퍼펙트 정렬)
                      SizedBox(
                        width: barTrackWidth,
                        child: Transform.translate(
                          offset: const Offset(-3, 0), // 왼쪽으로 3px 미세 조정
                          child: Text(
                            dateStr,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            softWrap: false,
                            strutStyle: const StrutStyle(
                              forceStrutHeight: true,
                              fontSize: 10,
                              height: 1.0,
                            ),
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.0,
                              fontFamily: AppConstants.fontFamilySmall,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              // 한국어 주석: 막대 선택 시 하단 날짜도 함께 강조합니다.
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            if (i != count - 1) {
              barColumns.add(SizedBox(width: gap));
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: barColumns,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 세로 진행도 형태의 캡슐 막대 위젯
/// - 트랙(연한 회색 그라디언트) + 진행도(그라디언트) 구성
/// - 마지막 막대(highlight=true)는 파란 계열로 강조
class _CapsuleBar extends StatelessWidget {
  final double value; // 0.0 ~ 1.0
  final bool highlight;
  final ColorScheme colorScheme;

  const _CapsuleBar({
    required this.value,
    required this.highlight,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // 안전한 값 범위 보정(DRY)
    final double clamped = value.clamp(0.0, 1.0).toDouble();

    // 색상 정의(재사용: DRY)
    final trackTop = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final trackBottom = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.6,
    );

    final barGreyTop = colorScheme.onSurface.withValues(alpha: 0.2);
    final barGreyBottom = colorScheme.onSurface.withValues(alpha: 0.3);

    final barBlueTop = colorScheme.primary.withValues(alpha: 0.8);
    final barBlueBottom = colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          // 트랙 배경 그라디언트(위 밝음 -> 아래 살짝 진함)
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [trackTop, trackBottom],
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          // 진행도(값 비율에 따른 높이)
          child: FractionallySizedBox(
            heightFactor: clamped == 0.0 ? 0.001 : clamped, // 완전 0일 때도 모양 유지
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: highlight
                      ? [barBlueTop, barBlueBottom]
                      : [barGreyTop, barGreyBottom],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
