import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 설정 화면의 섹션 헤더 공통 위젯
/// DRY 원칙: app_settings_screen과 notification_settings_screen에서 재사용
class SectionHeader extends StatelessWidget {
  /// 섹션 제목
  final String title;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    required this.title,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          fontFamily: AppConstants.fontFamilySmall,
        ),
      ),
    );
  }
}
