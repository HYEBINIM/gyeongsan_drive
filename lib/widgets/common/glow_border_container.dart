import 'package:flutter/material.dart';

/// 네온 글로우 효과가 있는 테두리 컨테이너
/// - 안전귀가 모드 활성화 시 발광 테두리 표시
/// - 다중 레이어 BoxShadow로 네온 효과 구현
/// - Opacity 펄스 애니메이션으로 호흡하는 효과
class GlowBorderContainer extends StatefulWidget {
  /// 글로우 효과 활성화 여부
  final bool isActive;

  /// 테두리 및 글로우 색상 (기본값: Spotify Green)
  final Color glowColor;

  /// 테두리 두께 (기본값: 4px)
  final double borderWidth;

  /// 자식 위젯
  final Widget child;

  /// 펄스 애니메이션 지속 시간 (기본값: 1200ms)
  final Duration pulseDuration;

  const GlowBorderContainer({
    super.key,
    required this.isActive,
    required this.child,
    this.glowColor = const Color(0xFF1ED760), // Spotify Green
    this.borderWidth = 4.0,
    this.pulseDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<GlowBorderContainer> createState() => _GlowBorderContainerState();
}

class _GlowBorderContainerState extends State<GlowBorderContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 생성
    _controller = AnimationController(
      duration: widget.pulseDuration,
      vsync: this,
    );

    // Opacity 애니메이션 (0.75 ↔ 0.85) - 매우 은은한 펄스
    _opacityAnimation = Tween<double>(
      begin: 0.75,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // 활성화 상태면 애니메이션 시작
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GlowBorderContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // isActive 상태 변경 감지
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        // 활성화: 애니메이션 시작
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
    // 비활성화 상태: 테두리/그림자 없이 child만 반환
    if (!widget.isActive) {
      return widget.child;
    }

    // 활성화 상태: 네온 글로우 효과 적용 (테두리만 펄스)
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        final glowOpacity = _opacityAnimation.value;

        // 한국어 주석: CustomPainter로 테두리 스트로크에만 블러를 적용해
        // 화면 전체를 덮는 오버레이 없이, 가장자리 안쪽에만 펄스 효과를 냅니다.
        return CustomPaint(
          foregroundPainter: _GlowBorderPainter(
            color: widget.glowColor,
            borderWidth: widget.borderWidth,
            glowOpacity: glowOpacity,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 한국어 주석: 가장자리 스트로크에만 글로우를 그리는 Painter
class _GlowBorderPainter extends CustomPainter {
  final Color color;
  final double borderWidth;
  final double glowOpacity;

  _GlowBorderPainter({
    required this.color,
    required this.borderWidth,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 한국어 주석: 그리기 영역(가장자리에서 절반 두께만큼 안쪽으로)
    // 직각 테두리를 위해 Rect 직접 사용
    final rect = Rect.fromLTWH(
      borderWidth / 2,
      borderWidth / 2,
      size.width - borderWidth,
      size.height - borderWidth,
    );

    // 1) 기본 테두리
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..isAntiAlias = true;
    canvas.drawRect(rect, borderPaint);

    // 한국어 주석: 매우 은은한 네온 느낌을 위해
    // - 낮은 불투명도를 유지하고
    // - 블러 반경과 스트로크 두께를 단계적으로 키웁니다.
    final o1 = (0.60 * glowOpacity).clamp(0.0, 1.0); // 핵심 광도
    final o2 = (0.35 * glowOpacity).clamp(0.0, 1.0); // 중간 후광
    final o3 = (0.20 * glowOpacity).clamp(0.0, 1.0); // 먼 후광

    // 한국어 주석: 스트로크+블러 조합이 특정 엔진 경로에서 약해지는 문제를
    // 우회하기 위해, 글로우는 "도넛 형태의 채우기 + 블러"로 렌더링합니다.
    // 채우기+블러는 안정적으로 후광이 보입니다.

    // 링(도넛) 패스 생성 유틸 (DRY)
    Path ringPath(double stroke) {
      // 한국어 주석: 외곽/내곽 경계를 각각 반 두께만큼 inflate/deflate하여 링 생성
      final outer = rect.inflate(stroke / 2);
      final inner = rect.deflate(stroke / 2);
      final path = Path()..fillType = PathFillType.evenOdd;
      path.addRect(outer);
      path.addRect(inner);
      return path;
    }

    // 공통 글로우 페인트 팩토리 (KISS)
    Paint glowPaint(double alpha, double sigma) => Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

    // 2) 1차 글로우(강함)
    final path1 = ringPath(borderWidth + 4);
    canvas.drawPath(path1, glowPaint(o1, 14));

    // 3) 2차 글로우(중간)
    final path2 = ringPath(borderWidth + 10);
    canvas.drawPath(path2, glowPaint(o2, 28));

    // 4) 3차 글로우(먼 후광)
    final path3 = ringPath(borderWidth + 18);
    canvas.drawPath(path3, glowPaint(o3, 44));
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) {
    // 한국어 주석: 애니메이션 값/색상/두께 변경 시 리페인트
    return oldDelegate.glowOpacity != glowOpacity ||
        oldDelegate.color != color ||
        oldDelegate.borderWidth != borderWidth;
  }
}
