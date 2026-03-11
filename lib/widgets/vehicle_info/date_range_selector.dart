import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';

/// 날짜 범위 선택기 위젯
class DateRangeSelector extends StatelessWidget {
  final DateTime startDate; // 시작 날짜
  final DateTime endDate; // 종료 날짜
  final VoidCallback onDateRangePressed; // 기간 선택 버튼 클릭 콜백

  const DateRangeSelector({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangePressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 날짜 포맷팅 (yyyy년 MM월 dd일 형식)
    final dateFormat = DateFormat('yyyy년 MM월 dd일');
    final startDateStr = dateFormat.format(startDate);
    final endDateStr = dateFormat.format(endDate);

    // 카드 형태로 감싸서 이미지와 동일한 깊이감/모서리 구현
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.scrim.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: onDateRangePressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 날짜 범위 텍스트
              Text(
                '$startDateStr ~ $endDateStr',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              // 드롭다운 아이콘
              Icon(
                Icons.arrow_drop_down,
                size: 28,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
