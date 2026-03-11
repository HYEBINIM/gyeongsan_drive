import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import '../../models/navigation/route_model.dart';
import '../../utils/constants.dart';

/// 경로 지도 플레이스홀더 위젯
/// 실제 지도 대신 출발/도착 마커를 시각적으로 표시
class RouteMapPlaceholder extends StatelessWidget {
  final LocationInfo? start; // 출발지
  final LocationInfo? destination; // 도착지
  final RouteModel? route; // 경로 정보

  const RouteMapPlaceholder({
    super.key,
    required this.start,
    required this.destination,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Stack(
        children: [
          // 배경 (지도 스타일)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.surfaceContainerLow,
                ],
              ),
            ),
          ),

          // 경로 라인 (간단한 시각적 표현)
          if (route != null)
            CustomPaint(
              size: Size(
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height,
              ),
              painter: _RouteLinePainter(colorScheme.primary),
            ),

          // 중앙: 마커 표시 영역
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 출발지 마커
                _buildMarker(
                  context: context,
                  label: '출발',
                  color: colorScheme.primary,
                  placeName: start?.placeName ?? '출발지',
                ),
                const SizedBox(height: 80),

                // 도착지 마커
                _buildMarker(
                  context: context,
                  label: '도착',
                  color: Colors.red[600]!,
                  placeName: destination?.placeName ?? '도착지',
                  isDestination: true,
                ),
              ],
            ),
          ),

          // 우측 하단: 지도 컨트롤 버튼 (플레이스홀더)
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                _buildMapControl(Remix.stack_fill, colorScheme),
                const SizedBox(height: 8),
                _buildMapControl(Remix.navigation_fill, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 마커 빌더
  Widget _buildMarker({
    required BuildContext context,
    required String label,
    required Color color,
    required String placeName,
    bool isDestination = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 마커 아이콘
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.scrim.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDestination ? Remix.map_pin_fill : Remix.record_circle_fill,
                color: isDestination ? Colors.white : colorScheme.onPrimary,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isDestination ? Colors.white : colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 장소명
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: colorScheme.scrim.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            placeName,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.87),
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ),
      ],
    );
  }

  /// 지도 컨트롤 버튼 빌더
  Widget _buildMapControl(IconData icon, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 20,
        color: colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }
}

/// 경로 라인을 그리는 Custom Painter
class _RouteLinePainter extends CustomPainter {
  final Color lineColor;

  _RouteLinePainter(this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.6)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 간단한 곡선 경로 그리기
    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.35);

    // 베지어 곡선으로 경로 표현
    path.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.45,
      size.width * 0.5,
      size.height * 0.6,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
