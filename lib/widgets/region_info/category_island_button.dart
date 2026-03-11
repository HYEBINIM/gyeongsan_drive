import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 지역정보 카테고리 아이랜드 버튼 위젯
/// 개별 아이랜드 스타일로 카테고리를 표시하고 선택 상태를 시각적으로 구분
class CategoryIslandButton extends StatelessWidget {
  final String categoryId;
  final String categoryName;
  final IconData categoryIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryIslandButton({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: isSelected ? 6 : 3,
              offset: Offset(0, isSelected ? 3 : 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Icon(
              categoryIcon,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withValues(alpha: 0.6),
              size: 18,
            ),
            const SizedBox(width: 5),
            // 텍스트
            Text(
              categoryName,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
