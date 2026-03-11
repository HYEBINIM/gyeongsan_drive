import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../models/navigation/navigation_state.dart';
import '../../utils/constants.dart';

/// 통합 상단 네비게이션 패널 위젯
/// - 이미지와 같은 파란 배경, 교통수단 아이콘, 입력 박스를 한 파일에서 제공
/// - TransportModeBar 와 LocationInputCard 를 하나로 합침 (DRY/KISS)
class LocationInputCard extends StatelessWidget {
  // 표시 문자열
  final String startAddress; // 출발지 주소
  final String destinationName; // 도착지 이름

  // 동작 콜백
  final TransportMode selectedMode; // 현재 선택된 교통수단
  final ValueChanged<TransportMode> onModeChanged; // 교통수단 변경
  final VoidCallback onSwap; // 출발지/도착지 교환
  final VoidCallback onClose; // 닫기

  // 선택 기능 (선택 사항)
  final VoidCallback? onMoreOptions; // 더보기(…)

  const LocationInputCard({
    super.key,
    required this.startAddress,
    required this.destinationName,
    required this.selectedMode,
    required this.onModeChanged,
    required this.onSwap,
    required this.onClose,
    this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      // 전체 패널은 상단에 붙어 표시되므로 좌우 여백만 살짝 부여
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      color: colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 좌측: 아이콘 바 + 입력 카드
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTransportBar(colorScheme),
                const SizedBox(height: 8),
                _buildInputPanel(context, colorScheme),
              ],
            ),
          ),
          // 우측: 닫기(X) / 교환(↕) / 더보기(…)
          SizedBox(
            width: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 닫기 버튼 (상단)
                InkResponse(
                  onTap: onClose,
                  radius: 20,
                  child: Icon(
                    Remix.close_line,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 24),
                // 교환 버튼 (중앙 근처)
                Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: onSwap,
                    radius: 24,
                    child: Icon(
                      Remix.arrow_up_down_line,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 더보기 버튼 (우측 하단 아이콘)
                InkResponse(
                  onTap: onMoreOptions,
                  radius: 20,
                  child: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 상단 교통수단 아이콘 바
  Widget _buildTransportBar(ColorScheme colorScheme) {
    // 아이콘은 이미지와 동일하게 자동차, 도보, 자전거 순
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildModeIcon(
          icon: Remix.car_fill,
          mode: TransportMode.car,
          colorScheme: colorScheme,
        ),
        const SizedBox(width: 22),
        _buildModeIcon(
          icon: Remix.walk_fill,
          mode: TransportMode.walk,
          colorScheme: colorScheme,
        ),
        const SizedBox(width: 22),
        _buildModeIcon(
          icon: Remix.bike_fill,
          mode: TransportMode.bike,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  /// 단일 교통수단 아이콘 빌더
  Widget _buildModeIcon({
    required IconData icon,
    required TransportMode mode,
    required ColorScheme colorScheme,
  }) {
    final bool isSelected = selectedMode == mode;

    // 선택 시: 흰색 elongated hole 배경 + 파란 아이콘
    // 비선택 시: 흰색 아이콘만
    // 확대 효과 없이 동일한 크기 유지
    return InkResponse(
      onTap: () => onModeChanged(mode),
      radius: 24,
      child: Container(
        width: 56,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(borderRadius: BorderRadius.circular(20))
            : null,
        child: Icon(
          icon,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
          size: 20,
        ),
      ),
    );
  }

  /// 주소 입력 카드(흰색 박스 + 경계선)
  Widget _buildInputPanel(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputText(startAddress),
          const SizedBox(height: 10),
          Builder(
            builder: (context) => Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          _buildInputText(destinationName),
        ],
      ),
    );
  }

  /// 한 줄 텍스트(어두운 색)
  Widget _buildInputText(String text) {
    return Builder(
      builder: (context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
          height: 1.2,
          fontFamily: AppConstants.fontFamilySmall,
        ),
      ),
    );
  }
}
