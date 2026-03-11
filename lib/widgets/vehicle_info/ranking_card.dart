import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 상위 % 카드 위젯 (운전자 순위)
class RankingCard extends StatelessWidget {
  // 상위 몇 % (예: 52 = 상위 52%)
  final int rankingPercentile;
  // 카드 내부 패딩(외곽 여백) - 수동 조절용
  final EdgeInsetsGeometry contentPadding;
  // 제목 아래 간격 - 수동 조절용
  final double titleGap;
  // 퍼센트 영역과 프로그레스 바 사이 간격 - 수동 조절용
  final double barTopGap;
  // 프로그레스 바와 하단 라벨 사이 간격 - 수동 조절용
  final double labelsTopGap;
  // 애니메이션 지속시간 - 진행바 애니메이션용
  final Duration animationDuration;
  // 애니메이션 곡선 - 진행바 애니메이션용
  final Curve animationCurve;

  const RankingCard({
    super.key,
    required this.rankingPercentile,
    this.contentPadding = const EdgeInsets.all(10),
    this.titleGap = 5,
    this.barTopGap = 6,
    this.labelsTopGap = 4,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.animationCurve = Curves.ease,
  });

  @override
  Widget build(BuildContext context) {
    // 테마 색상 스키마 가져오기
    final colorScheme = Theme.of(context).colorScheme;

    // rankingPercentile은 "상위 N%" 형태의 값(작을수록 상위)이라서,
    // 그래프는 오른쪽(상위)으로 갈수록 채워지도록 반전해서 표시한다.
    final int clampedPercentile = rankingPercentile.clamp(0, 100);
    final double progressValue = (100 - clampedPercentile) / 100;

    // 카드 전체를 컴팩트하게 축소
    return Container(
      // 내부 패딩을 외부에서 수동 조절 가능
      padding: contentPadding,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 제목
          Text(
            '상위',
            style: TextStyle(
              fontSize: 14,
              fontFamily: AppConstants.fontFamilySmall,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: titleGap),
          // 상위 % 표시
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$rankingPercentile',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppConstants.fontFamilyBig,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '%',
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: AppConstants.fontFamilySmall,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: barTopGap),
          // 프로그레스 바
          Column(
            children: [
              // 진행바 애니메이션 적용
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progressValue),
                duration: animationDuration,
                curve: animationCurve,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    color: colorScheme.primary,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(3),
                  );
                },
              ),
              SizedBox(height: labelsTopGap),
              // 하위 ~ 상위 라벨
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '하위',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: AppConstants.fontFamilySmall,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    '상위',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: AppConstants.fontFamilySmall,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
