import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// 스켈레톤 UI에 shimmer 애니메이션을 추가하는 래퍼 위젯
///
/// 회색 박스(동적 값 부분)를 감싸서 shimmer 효과를 적용합니다.
/// 고정 텍스트 라벨은 이 위젯으로 감싸지 않고 그대로 표시합니다.
class ShimmerWrapper extends StatelessWidget {
  /// shimmer 효과를 적용할 자식 위젯
  final Widget child;

  /// 애니메이션 주기 (기본값: 1500ms)
  final Duration period;

  /// 기본 색상 (배경색)
  final Color? baseColor;

  /// 하이라이트 색상 (빛나는 부분)
  final Color? highlightColor;

  const ShimmerWrapper({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1500),
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? Colors.grey[300]!,
      highlightColor: highlightColor ?? Colors.grey[100]!,
      period: period,
      child: child,
    );
  }
}
