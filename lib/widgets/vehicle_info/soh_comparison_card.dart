import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/battery_status_model.dart';
import '../../utils/constants.dart';

/// SOH 비교 카드 위젯 - 막대 그래프 형태
class SOHComparisonCard extends StatefulWidget {
  final BatteryStatusData batteryData;

  const SOHComparisonCard({super.key, required this.batteryData});

  @override
  State<SOHComparisonCard> createState() => _SOHComparisonCardState();
}

class _SOHComparisonCardState extends State<SOHComparisonCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 위젯이 빌드된 후 내 차량을 중앙으로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToMyVehicle();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 내 차량을 화면 중앙으로 스크롤
  void _scrollToMyVehicle() {
    if (!_scrollController.hasClients) return;

    final comparison = widget.batteryData.comparison;
    final mySOH = widget.batteryData.currentSOH;

    // 내 차량보다 SOH가 낮은 차량 개수 계산
    final lowerPeersCount = comparison.peers
        .where((peer) => peer.avgSoh <= mySOH)
        .length;

    // 각 막대의 너비 (width 70 + margin 16)
    const barWidth = 86.0;

    // 내 차량의 위치 계산 (인덱스 * 너비)
    final myVehiclePosition = lowerPeersCount * barWidth;

    // 화면 너비의 절반 - 막대 너비의 절반 = 중앙 오프셋
    final screenWidth = MediaQuery.of(context).size.width;
    final centerOffset = screenWidth / 2 - barWidth / 2;

    // 스크롤할 위치 계산
    final scrollPosition = myVehiclePosition - centerOffset;

    // 스크롤 가능한 범위 내에서만 스크롤
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetScroll = scrollPosition.clamp(0.0, maxScroll);

    // 애니메이션과 함께 스크롤
    _scrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 테마 색상 스키마 가져오기
    final colorScheme = Theme.of(context).colorScheme;

    final comparison = widget.batteryData.comparison;
    final mySOH = widget.batteryData.currentSOH;
    final myMileage = comparison.myMileage;

    // 내 차량 데이터
    final myVehicle = _VehicleComparisonData(
      label: '내 차량',
      soh: mySOH,
      mileage: myMileage,
      isMyVehicle: true,
    );

    // 비교 차량 데이터
    final peerVehicles = comparison.peers
        .asMap()
        .entries
        .map(
          (entry) => _VehicleComparisonData(
            label: '비교차량 ${entry.key + 1}',
            soh: entry.value.avgSoh,
            mileage: entry.value.avgMileage,
            isMyVehicle: false,
          ),
        )
        .toList();

    // 비교 차량들을 SOH로 정렬
    peerVehicles.sort((a, b) => a.soh.compareTo(b.soh));

    // 내 차량보다 SOH가 낮은 차량 (왼쪽)
    final lowerPeers = peerVehicles.where((v) => v.soh <= mySOH).toList();

    // 내 차량보다 SOH가 높은 차량 (오른쪽)
    final higherPeers = peerVehicles.where((v) => v.soh > mySOH).toList();

    // 최종 배치: 낮은 차량들 + 내 차량 + 높은 차량들
    final List<_VehicleComparisonData> vehicles = [
      ...lowerPeers,
      myVehicle,
      ...higherPeers,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
                '다른 차량 비교',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 5),
              Tooltip(
                message: '유사한 주행거리를 가진 차량들과의 배터리 건강도 비교',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                textStyle: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onPrimary,
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

          // 막대 그래프 영역
          SizedBox(
            height: 220,
            child: vehicles.isEmpty
                ? Center(
                    child: Text(
                      '비교 데이터가 없습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // 각 막대의 너비 계산 (width 70 + margin 16)
                      const barWidth = 86.0;
                      final totalWidth = vehicles.length * barWidth;

                      // 화면보다 작으면 중앙 정렬, 크면 스크롤
                      if (totalWidth <= constraints.maxWidth) {
                        return Center(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: vehicles
                                .map(
                                  (vehicle) =>
                                      _buildBarChart(vehicle, colorScheme),
                                )
                                .toList(),
                          ),
                        );
                      } else {
                        return SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: vehicles
                                .map(
                                  (vehicle) =>
                                      _buildBarChart(vehicle, colorScheme),
                                )
                                .toList(),
                          ),
                        );
                      }
                    },
                  ),
          ),

          // 구분선
          Divider(
            height: 20,
            thickness: 1,
            color: colorScheme.surfaceContainerHighest,
          ),

          // 비교 차량 평균 표시
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '비교 차량 평균: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
                Text(
                  '${comparison.allUserAverage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontFamily: AppConstants.fontFamilyBig,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 개별 막대 그래프 빌더
  Widget _buildBarChart(
    _VehicleComparisonData vehicle,
    ColorScheme colorScheme,
  ) {
    final isMyVehicle = vehicle.isMyVehicle;
    final barColor = isMyVehicle
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final textColor = isMyVehicle
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.7);

    // SOH 값에 따른 막대 높이 (80~100% 범위를 기준으로)
    final minSOH = 80.0;
    final maxSOH = 100.0;
    final normalizedSOH = ((vehicle.soh - minSOH) / (maxSOH - minSOH)).clamp(
      0.0,
      1.0,
    );
    final barHeight = 120 * normalizedSOH + 15; // 최소 15, 최대 135

    // 주행거리 포맷팅
    final mileageFormatter = NumberFormat('#,###');
    final formattedMileage = mileageFormatter.format(vehicle.mileage.round());

    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SOH 값
          Text(
            '${vehicle.soh.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: AppConstants.fontFamilyBig,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),

          // 막대
          Container(
            width: 36,
            height: barHeight,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
              boxShadow: isMyVehicle
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 8),

          // 차량 레이블
          Text(
            vehicle.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMyVehicle ? FontWeight.bold : FontWeight.normal,
              fontFamily: AppConstants.fontFamilySmall,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),

          // 주행거리
          Text(
            '$formattedMileage km',
            style: TextStyle(
              fontSize: 10,
              fontFamily: AppConstants.fontFamilySmall,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 차량 비교 데이터 클래스 (내부 사용)
class _VehicleComparisonData {
  final String label; // "내 차량" or "비교차량 N"
  final double soh; // SOH 값
  final double mileage; // 주행거리
  final bool isMyVehicle; // 내 차량 여부

  _VehicleComparisonData({
    required this.label,
    required this.soh,
    required this.mileage,
    required this.isMyVehicle,
  });
}
