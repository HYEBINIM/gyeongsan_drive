import 'package:flutter/material.dart';

/// 현재 위치 마커 UI (순수 위젯)
///
/// ViewModel과 무관하게 독립적으로 동작하며,
/// 스타일 옵션으로 다양한 디자인을 지원합니다.
class CurrentLocationMarker extends StatelessWidget {
  /// 마커 스타일
  final CurrentLocationMarkerStyle style;

  const CurrentLocationMarker({
    super.key,
    this.style = const CurrentLocationMarkerStyle.navigation(),
  });

  @override
  Widget build(BuildContext context) {
    // 테마 색상 스키마 가져오기
    final colorScheme = Theme.of(context).colorScheme;
    // 스타일에서 지정한 색상이 있으면 사용, 없으면 primary 색상 사용
    final effectiveColor = style.color ?? colorScheme.primary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 외곽 원 (펄싱 효과용 반투명 원)
        Container(
          width: style.outerSize,
          height: style.outerSize,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: style.outerOpacity),
            shape: BoxShape.circle,
          ),
          child: Center(
            // 중간 원 (파란색 실선)
            child: Container(
              width: style.innerSize,
              height: style.innerSize,
              decoration: BoxDecoration(
                color: effectiveColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.scrim.withValues(alpha: 0.26),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              // 내부 원 (흰색 중심점 - 선택적)
              child: style.showCenterDot
                  ? Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// 현재 위치 마커 스타일 설정
///
/// 다양한 디자인 옵션을 제공하며,
/// 사전 정의된 스타일(navigation, basic)을 사용하거나
/// 커스텀 스타일을 정의할 수 있습니다.
class CurrentLocationMarkerStyle {
  /// 외곽 원 크기
  final double outerSize;

  /// 중간/내부 원 크기
  final double innerSize;

  /// 마커 색상 (null이면 테마의 primary 색상 사용)
  final Color? color;

  /// 외곽 원 불투명도 (0.0 ~ 1.0)
  final double outerOpacity;

  /// 중심점 표시 여부 (흰색 점)
  final bool showCenterDot;

  const CurrentLocationMarkerStyle({
    required this.outerSize,
    required this.innerSize,
    required this.color,
    required this.outerOpacity,
    required this.showCenterDot,
  });

  /// 내비게이션 스타일 (3계층)
  ///
  /// - 외곽 반투명 원 + 중간 파란 원 + 내부 흰색 점
  /// - GPS 마커처럼 정확한 위치를 강조
  /// - 경로 안내 시 권장
  /// - 테마의 primary 색상 사용
  const CurrentLocationMarkerStyle.navigation()
    : outerSize = 50.0,
      innerSize = 20.0,
      color = null,
      outerOpacity = 0.3,
      showCenterDot = true;

  /// 기본 스타일 (2계층처럼 보임)
  ///
  /// - 외곽 반투명 원 + 중간 파란 원
  /// - 더 간단하고 미니멀한 디자인
  /// - 지역 탐색 시 권장
  /// - 테마의 primary 색상 사용
  const CurrentLocationMarkerStyle.basic()
    : outerSize = 50.0,
      innerSize = 20.0,
      color = null,
      outerOpacity = 0.3,
      showCenterDot = false;
}
