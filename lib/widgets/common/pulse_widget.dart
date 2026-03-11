import 'package:flutter/material.dart';

/// 펄스 애니메이션 위젯 (재사용 가능)
/// - 안전귀가 모드 활성화 상태를 시각적으로 강조
/// - ScaleTransition으로 부드러운 크기 변화 애니메이션
/// - isActive가 true일 때만 애니메이션 실행
class PulseWidget extends StatefulWidget {
  /// 애니메이션 활성화 여부
  final bool isActive;

  /// 애니메이션을 적용할 자식 위젯
  final Widget child;

  /// 펄스 애니메이션 지속 시간 (기본: 800ms)
  final Duration duration;

  /// 펄스 애니메이션 최소 스케일 (기본: 1.0)
  final double minScale;

  /// 펄스 애니메이션 최대 스케일 (기본: 1.15)
  final double maxScale;

  const PulseWidget({
    super.key,
    required this.isActive,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.minScale = 1.0,
    this.maxScale = 1.15,
  });

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 생성
    _controller = AnimationController(duration: widget.duration, vsync: this);

    // Tween 애니메이션 설정 (1.0 ↔ 1.15 스케일)
    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // 초기 활성화 상태에 따라 애니메이션 시작
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // isActive 상태 변경 감지
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        // 활성화: 애니메이션 시작 (무한 반복)
        _controller.repeat(reverse: true);
      } else {
        // 비활성화: 애니메이션 정지 및 초기화
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 비활성화 상태: 애니메이션 없이 child 반환
    if (!widget.isActive) {
      return widget.child;
    }

    // 활성화 상태: ScaleTransition 애니메이션 적용
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}
