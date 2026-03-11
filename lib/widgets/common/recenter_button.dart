import 'package:flutter/material.dart';

/// 지도 중심을 현재 위치로 이동하는 버튼
/// - guidance_screen과 safe_home_screen에서 재사용
/// - 추적 모드가 활성화되면 자동으로 숨김
class RecenterButton extends StatelessWidget {
  /// 지도 추적 모드 활성화 여부
  /// true면 버튼 숨김, false면 버튼 표시
  final bool isFollowingLocation;

  /// 버튼 클릭 시 실행할 콜백
  /// - centerMapOnCurrentLocation() 호출
  /// - 지도 애니메이션 이동 로직 포함
  final VoidCallback onPressed;

  /// 하단 오프셋 (기본값: 100px)
  /// - guidance_screen: 100px (bottom_bar 위)
  /// - safe_home_screen: 원하는 위치로 조정 가능
  final double bottomOffset;

  const RecenterButton({
    super.key,
    required this.isFollowingLocation,
    required this.onPressed,
    this.bottomOffset = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    // 추적 중이면 버튼 숨김
    if (isFollowingLocation) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      bottom: bottomOffset,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.center,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(24),
          color: colorScheme.surfaceContainerHighest,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.near_me, color: colorScheme.onSurface, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '내 위치로',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
