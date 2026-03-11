import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 약관 동의 체크박스 위젯
/// 재사용 가능한 약관 동의 체크박스 컴포넌트
class TermsCheckbox extends StatelessWidget {
  final String label; // 체크박스 옆에 표시될 텍스트
  final bool value; // 체크 상태
  final ValueChanged<bool?> onChanged; // 체크 상태 변경 콜백
  final bool isRequired; // 필수 항목 여부
  final VoidCallback? onDetailTap; // 상세보기 탭 콜백 (optional)
  final bool hasDetail; // 상세보기 버튼 표시 여부

  const TermsCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isRequired = false,
    this.onDetailTap,
    this.hasDetail = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // 체크박스
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 라벨 텍스트
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.87),
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ),
        ),

        // 필수 표시
        if (isRequired)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '(필수)',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // 상세보기 버튼 (또는 고정 공간)
        SizedBox(
          width: 20,
          height: 20,
          child: hasDetail
              ? GestureDetector(
                  onTap: onDetailTap,
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
