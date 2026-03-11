import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import '../../models/place_model.dart';
import '../../models/navigation/route_model.dart';
import '../../routes/app_routes.dart';
import '../../utils/constants.dart';

/// 장소 항목 카드 위젯
class PlaceItemCard extends StatelessWidget {
  final PlaceModel place;
  final VoidCallback? onTap;

  const PlaceItemCard({super.key, required this.place, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 장소명 + 카테고리명 (같은 줄)
            Row(
              children: [
                // 장소명 (파란색)
                Text(
                  place.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                    fontFamily: AppConstants.fontFamilyBig,
                  ),
                ),
                const SizedBox(width: 6),
                // 카테고리명 (회색, 작은 글씨)
                Text(
                  _getCategoryName(place.category),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontFamily: AppConstants.fontFamilySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 운영상태 (시간 포함)
            _buildOperatingStatusWidget(
              colorScheme,
              place.category,
              place.isOpen,
              place.openingHours,
            ),
            const SizedBox(height: 4),

            // 거리 · 주소
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _formatDistance(place.distanceKm),
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                  TextSpan(
                    text: ' · ${place.address}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // 하단 버튼들
            _buildActionButtons(context, colorScheme),
          ],
        ),
      ),
    );
  }

  /// 카테고리명 가져오기
  String _getCategoryName(String categoryId) {
    final category = AppConstants.placeCategories.firstWhere(
      (cat) => cat['id'] == categoryId,
      orElse: () => {'id': '', 'name': '기타'},
    );
    return category['name'] as String;
  }

  /// 운영상태 위젯 생성 (시간 포함, 색상 분리)
  /// 예: "운영중 · 23시에 운영 종료", "영업중 · 21시에 영업 종료", "운영종료"
  Widget _buildOperatingStatusWidget(
    ColorScheme colorScheme,
    String categoryId,
    bool isOpen,
    String? openingHours,
  ) {
    // 운영/영업 용어 결정
    final statusTerm = categoryId == 'restaurant' ? '영업' : '운영';

    // 운영 종료 상태
    if (!isOpen) {
      return Text(
        '$statusTerm종료',
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
          fontFamily: AppConstants.fontFamilySmall,
        ),
      );
    }

    // 시간 정보 없을 때
    if (openingHours == null || openingHours.isEmpty) {
      return Text(
        '$statusTerm중',
        style: TextStyle(
          fontSize: 13,
          color: Colors.green[600], // 의미적 색상 유지
          fontFamily: AppConstants.fontFamilySmall,
        ),
      );
    }

    // 24시간 운영
    if (openingHours.contains('24시간')) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$statusTerm중',
              style: TextStyle(
                fontSize: 13,
                color: Colors.green[600], // 의미적 색상 유지
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
            TextSpan(
              text: ' · 24시간 $statusTerm',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ],
        ),
      );
    }

    // "운영중 · 23시에 운영 종료" 형식
    // openingHours는 "23시까지" 형식이므로 "23시"만 추출
    final hourText = openingHours.replaceAll('까지', '');
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$statusTerm중',
            style: TextStyle(
              fontSize: 13,
              color: Colors.green[600], // 의미적 색상 유지
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
          TextSpan(
            text: ' · $hourText에 $statusTerm 종료',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// 거리 포맷팅 (1km 미만은 m 단위)
  String _formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '${meters}m';
    }
    return '${distanceKm.toStringAsFixed(1)}km';
  }

  /// 액션 버튼들 빌더 (카테고리별 버튼 표시 제어)
  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme) {
    // 주차장, 화장실은 전화 버튼 없이 길찾기만 표시
    final hidePhoneButton =
        place.category == 'parking' || place.category == 'restroom';

    if (hidePhoneButton) {
      return _buildActionButton(
        colorScheme: colorScheme,
        icon: Remix.navigation_fill,
        label: '길찾기',
        onTap: () => _navigateToPlace(context),
      );
    }

    // 나머지 카테고리는 전화 + 길찾기 버튼 표시
    return Row(
      children: [
        // 전화 버튼
        Expanded(
          child: _buildActionButton(
            colorScheme: colorScheme,
            icon: Remix.phone_fill,
            label: '전화',
            onTap: () => _makePhoneCall(place.phoneNumber),
          ),
        ),
        const SizedBox(width: 8),
        // 길찾기 버튼
        Expanded(
          child: _buildActionButton(
            colorScheme: colorScheme,
            icon: Remix.navigation_fill,
            label: '길찾기',
            onTap: () => _navigateToPlace(context),
          ),
        ),
      ],
    );
  }

  /// 액션 버튼 빌더
  Widget _buildActionButton({
    required ColorScheme colorScheme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurface),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 전화 걸기 (전화 앱 열기)
  Future<void> _makePhoneCall(String? phoneNumber) async {
    // 전화번호가 없는 경우
    if (phoneNumber == null || phoneNumber.isEmpty) {
      debugPrint('❌ 전화번호가 없습니다');
      return;
    }

    // 전화번호에서 하이픈 제거
    final cleanPhoneNumber = phoneNumber.replaceAll('-', '');

    // tel: URI 스킴 생성
    final uri = Uri(scheme: 'tel', path: cleanPhoneNumber);

    try {
      // 전화 앱을 실행할 수 있는지 확인
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('❌ 전화 앱을 실행할 수 없습니다: $phoneNumber');
      }
    } catch (e) {
      debugPrint('❌ 전화 걸기 실패: $e');
    }
  }

  /// 길찾기 화면으로 이동
  void _navigateToPlace(BuildContext context) {
    // 도착지 정보 생성
    final destination = LocationInfo(
      address: place.address,
      placeName: place.name,
      coordinates: LatLng(place.latitude, place.longitude),
    );

    // 길안내 화면으로 이동 (출발지는 현재 위치로 자동 설정)
    Navigator.pushNamed(
      context,
      AppRoutes.navigation,
      arguments: {'destination': destination},
    );

    debugPrint('✅ 길찾기 화면으로 이동: ${place.name}');
  }
}
