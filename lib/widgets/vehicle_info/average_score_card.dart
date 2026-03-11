import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 평균 점수 카드 위젯 (운전자 평균 점수)
class AverageScoreCard extends StatelessWidget {
  // 평균 점수 (0-100)
  final int averageScore;
  // 카드 내부 패딩(외곽 여백) - 수동 조절용
  final EdgeInsetsGeometry contentPadding;
  // 제목 아래 간격 - 수동 조절용
  final double titleGap;
  // 점수와 프로그레스 바 사이 간격 - 수동 조절용
  final double barTopGap;
  // 프로그레스 바와 하단 라벨 사이 간격 - 수동 조절용
  final double labelsTopGap;
  // 제목 위 여백(카드 내부 최상단과 제목 사이) - 수동 조절용
  final double headerTopGap;
  // 하단 레이블 아래 여백(라벨과 카드 내부 최하단 사이) - 수동 조절용
  final double footerBottomGap;
  // 세로 정렬 방식(기본: 가운데) - 수동 조절용
  final MainAxisAlignment verticalAlignment;
  // 애니메이션 지속시간 - 진행바 애니메이션용
  final Duration animationDuration;
  // 애니메이션 곡선 - 진행바 애니메이션용
  final Curve animationCurve;

  const AverageScoreCard({
    super.key,
    required this.averageScore,
    this.contentPadding = const EdgeInsets.all(10),
    this.titleGap = 5,
    this.barTopGap = 6,
    this.labelsTopGap = 4,
    this.headerTopGap = 0,
    this.footerBottomGap = 0,
    this.verticalAlignment = MainAxisAlignment.center,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.animationCurve = Curves.ease,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
        // 세로 정렬을 외부에서 제어 가능
        mainAxisAlignment: verticalAlignment,
        children: [
          // 제목 위 여백(필요 시만 적용)
          if (headerTopGap > 0) SizedBox(height: headerTopGap),
          // 제목
          Text(
            '운전자 평균 점수',
            style: TextStyle(
              fontSize: 14,
              fontFamily: AppConstants.fontFamilySmall,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: titleGap),
          // 평균 점수
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$averageScore',
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
                  '점',
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
                tween: Tween<double>(begin: 0, end: averageScore / 100),
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
              // 0점 ~ 100점 라벨
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0점',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: AppConstants.fontFamilySmall,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    '100점',
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
          // 하단 레이블 아래 여백(필요 시만 적용)
          if (footerBottomGap > 0) SizedBox(height: footerBottomGap),
        ],
      ),
    );
  }
}
