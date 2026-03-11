import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';
import '../../models/vehicle_data_model.dart';
import '../../utils/constants.dart';

/// 주행 정보 카드 위젯 (총 주행거리, 저장 속도, 배터리 잔량)
class VehicleInfoCard extends StatefulWidget {
  final VehicleData data;

  const VehicleInfoCard({super.key, required this.data});

  @override
  State<VehicleInfoCard> createState() => _VehicleInfoCardState();
}

class _VehicleInfoCardState extends State<VehicleInfoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _batteryAnimation;
  double _previousSOC = 0.0;

  @override
  void initState() {
    super.initState();
    _previousSOC = widget.data.displaySOC;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _batteryAnimation =
        Tween<double>(
          begin: widget.data.displaySOC,
          end: widget.data.displaySOC,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(VehicleInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.displaySOC != widget.data.displaySOC) {
      // 이전 값에서 새 값으로 부드럽게 전환
      _batteryAnimation =
          Tween<double>(
            begin: _previousSOC,
            end: widget.data.displaySOC,
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOut,
            ),
          );
      _previousSOC = widget.data.displaySOC;
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 테마 색상 스키마 가져오기
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        // 그림자 제거 및 플랫 스타일 적용
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildInfoItem(
              context,
              '총 주행거리',
              NumberFormat('#,###').format(widget.data.mileage),
              'km',
              Icons.directions_car_outlined,
            ),
          ),
          Expanded(
            child: _buildInfoItem(
              context,
              '차량 속도',
              widget.data.vehicleSpeed.toStringAsFixed(0),
              'km/h',
              Icons.speed,
            ),
          ),
          Expanded(
            child: _buildBatteryInfoItem(
              context,
              '배터리 잔량',
              widget.data.displaySOC.toStringAsFixed(0),
              '%',
            ),
          ),
        ],
      ),
    );
  }

  /// 정보 항목 위젯
  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, size: 24, color: colorScheme.primary.withValues(alpha: 0.8)),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontFamily: AppConstants.fontFamilySmall,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFamily: AppConstants.fontFamilyBig,
                  letterSpacing: -0.5,
                ),
              ),
              WidgetSpan(child: SizedBox(width: 2)),
              TextSpan(
                text: unit,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 배터리 잔량 항목 위젯 (애니메이션 포함)
  Widget _buildBatteryInfoItem(
    BuildContext context,
    String label,
    String value,
    String unit,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        AnimatedBuilder(
          animation: _batteryAnimation,
          builder: (context, child) {
            final currentSOC = _batteryAnimation.value;
            final animatedBatteryColor = _getBatteryColor(
              currentSOC,
              colorScheme,
            );

            return SizedBox(
              width: 24,
              height: 24,
              child: Stack(
                children: [
                  // 배터리 외곽선
                  Icon(
                    Remix.battery_line,
                    size: 24,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  // 배터리 채워지는 부분
                  ClipRect(
                    clipper: BatteryFillClipper(currentSOC / 100),
                    child: Icon(
                      Remix.battery_fill,
                      size: 24,
                      color: animatedBatteryColor,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontFamily: AppConstants.fontFamilySmall,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _batteryAnimation,
          builder: (context, child) {
            final currentSOC = _batteryAnimation.value;

            return RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: currentSOC.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      fontFamily: AppConstants.fontFamilyBig,
                      letterSpacing: -0.5,
                    ),
                  ),
                  WidgetSpan(child: SizedBox(width: 2)),
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// 배터리 잔량에 따른 색상 결정
  Color _getBatteryColor(double soc, ColorScheme scheme) {
    if (soc <= 20) return scheme.error; // 빨강 - 위험
    if (soc <= 50) return Colors.orange; // 주황 - 주의
    return scheme.primary; // 초록 - 정상
  }
}

/// 배터리 채워지는 효과를 위한 커스텀 클리퍼
class BatteryFillClipper extends CustomClipper<Rect> {
  final double fillLevel; // 0.0 ~ 1.0

  BatteryFillClipper(this.fillLevel);

  @override
  Rect getClip(Size size) {
    // 좌측에서 우측으로 채워지는 효과
    final double fillWidth = size.width * fillLevel;
    return Rect.fromLTRB(
      0, // 좌측 (시작점)
      0, // 상단
      fillWidth, // 우측 (채워진 만큼)
      size.height, // 하단
    );
  }

  @override
  bool shouldReclip(BatteryFillClipper oldClipper) {
    return oldClipper.fillLevel != fillLevel;
  }
}
