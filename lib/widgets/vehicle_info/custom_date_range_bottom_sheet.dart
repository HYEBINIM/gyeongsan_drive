import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';

/// 커스텀 날짜 범위 선택 BottomSheet (최대 7일 제한)
/// BottomSheet가 닫힐 때 {'startDate': DateTime, 'endDate': DateTime} Map을 반환
class CustomDateRangeBottomSheet extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;

  const CustomDateRangeBottomSheet({
    super.key,
    required this.initialStartDate,
    required this.initialEndDate,
  });

  @override
  State<CustomDateRangeBottomSheet> createState() =>
      _CustomDateRangeBottomSheetState();
}

class _CustomDateRangeBottomSheetState
    extends State<CustomDateRangeBottomSheet> {
  late DateTime _currentMonth;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  @override
  void initState() {
    super.initState();
    _selectedStartDate = widget.initialStartDate;
    _selectedEndDate = widget.initialEndDate;
    _currentMonth = DateTime(
      widget.initialStartDate.year,
      widget.initialStartDate.month,
    );
  }

  /// 이전 달로 이동
  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  /// 다음 달로 이동
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  /// 날짜 선택 처리
  void _onDateTap(DateTime date) {
    setState(() {
      if (_selectedStartDate == null || _selectedEndDate != null) {
        // 시작일 선택 (또는 재선택)
        _selectedStartDate = date;
        _selectedEndDate = null;
      } else {
        // 종료일 선택 (시작일 이후만 가능)
        _selectedEndDate = date;
      }
    });
  }

  /// 초기화
  void _reset() {
    setState(() {
      _selectedStartDate = null;
      _selectedEndDate = null;
    });
  }

  /// 적용 (BottomSheet를 닫으면서 선택된 날짜 범위 반환)
  void _apply() {
    if (_selectedStartDate != null && _selectedEndDate != null) {
      Navigator.pop(context, {
        'startDate': _selectedStartDate!,
        'endDate': _selectedEndDate!,
      });
    }
  }

  /// 날짜가 선택된 범위에 포함되는지 확인
  bool _isInRange(DateTime date) {
    if (_selectedStartDate == null || _selectedEndDate == null) {
      return false;
    }
    return date.isAfter(
          _selectedStartDate!.subtract(const Duration(days: 1)),
        ) &&
        date.isBefore(_selectedEndDate!.add(const Duration(days: 1)));
  }

  /// 날짜가 시작일인지 확인
  bool _isStartDate(DateTime date) {
    return _selectedStartDate != null &&
        date.year == _selectedStartDate!.year &&
        date.month == _selectedStartDate!.month &&
        date.day == _selectedStartDate!.day;
  }

  /// 날짜가 종료일인지 확인
  bool _isEndDate(DateTime date) {
    return _selectedEndDate != null &&
        date.year == _selectedEndDate!.year &&
        date.month == _selectedEndDate!.month &&
        date.day == _selectedEndDate!.day;
  }

  /// 날짜가 선택 가능한지 확인 (7일 제한)
  bool _isSelectable(DateTime date) {
    if (_selectedStartDate == null || _selectedEndDate != null) {
      return true;
    }
    // 시작일 이전 날짜는 선택 불가
    if (date.isBefore(_selectedStartDate!)) {
      return false;
    }
    // 시작일부터 +6일까지만 선택 가능 (총 7일)
    final daysDifference = date.difference(_selectedStartDate!).inDays;
    return daysDifference < 7;
  }

  /// 현재 월의 모든 날짜 생성
  List<DateTime?> _generateCalendarDays() {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );

    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0: 일요일, 6: 토요일

    final days = <DateTime?>[];

    // 이전 달의 빈 공간
    for (int i = 0; i < firstWeekday; i++) {
      days.add(null);
    }

    // 현재 달의 날짜
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }

    return days;
  }

  /// 선택된 기간 텍스트 생성
  String _getSelectedRangeText() {
    if (_selectedStartDate == null) {
      return '기간을 선택하세요';
    }
    if (_selectedEndDate == null) {
      return '${DateFormat('yyyy년 MM월 dd일').format(_selectedStartDate!)} ~ 종료일 선택';
    }

    final daysDifference =
        _selectedEndDate!.difference(_selectedStartDate!).inDays + 1;
    final startStr = DateFormat('yyyy년 MM월 dd일').format(_selectedStartDate!);
    final endStr = DateFormat('dd일').format(_selectedEndDate!);

    return '$startStr ~ $endStr ($daysDifference일)';
  }

  @override
  Widget build(BuildContext context) {
    // 테마 색상 스키마 가져오기
    final colorScheme = Theme.of(context).colorScheme;

    // 한국어 주석: 뒤로가기 버튼으로 바텀시트 닫기 허용
    return SafeArea(
      top: true,
      bottom: true,
      child: PopScope(
        canPop: true,
        child: Container(
          // 높이를 자동으로 내용물에 맞춤
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85, // 최대 높이 제한
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 내용물 크기에 맞춤
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '기간 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppConstants.fontFamilySmall,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 달력 영역
              // 한국어 주석: 갤럭시 폴드처럼 세로 공간이 작은 기기에서 오버플로우가 발생할 수 있어
              // 남은 공간을 유연하게 차지하도록 하고, 내용이 넘치면 스크롤되도록 처리한다.
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // 월 네비게이션
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _previousMonth,
                          ),
                          Text(
                            '${_currentMonth.year}년 ${_currentMonth.month}월',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: AppConstants.fontFamilySmall,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _nextMonth,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 요일 헤더
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['일', '월', '화', '수', '목', '금', '토']
                            .asMap()
                            .entries
                            .map((entry) {
                              final isWeekend =
                                  entry.key == 0 || entry.key == 6;
                              return Expanded(
                                child: Center(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: AppConstants.fontFamilySmall,
                                      color: isWeekend
                                          ? Colors.red[300]
                                          : colorScheme.onSurface.withValues(
                                              alpha: 0.7,
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(),
                      ),
                      const SizedBox(height: 8),

                      // 날짜 그리드
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 1,
                            ),
                        itemCount: _generateCalendarDays().length,
                        itemBuilder: (context, index) {
                          final date = _generateCalendarDays()[index];
                          if (date == null) {
                            return const SizedBox();
                          }

                          final isStartDate = _isStartDate(date);
                          final isEndDate = _isEndDate(date);
                          final isInRange = _isInRange(date);
                          final isSelectable = _isSelectable(date);

                          return GestureDetector(
                            onTap: isSelectable ? () => _onDateTap(date) : null,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isStartDate || isEndDate
                                    ? colorScheme.primary
                                    : isInRange
                                    ? colorScheme.primary.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: AppConstants.fontFamilySmall,
                                    color: !isSelectable
                                        ? colorScheme.onSurface.withValues(
                                            alpha: 0.3,
                                          )
                                        : isStartDate || isEndDate
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // 선택된 기간 표시
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            _getSelectedRangeText(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppConstants.fontFamilySmall,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 안내 문구
                      Text(
                        '적용을 눌러 기간을 적용하세요.',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: AppConstants.fontFamilySmall,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 하단 버튼
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.surfaceContainerHighest,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // 초기화 버튼
                    TextButton(
                      onPressed: _reset,
                      child: Text(
                        '초기화',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppConstants.fontFamilySmall,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 취소 버튼
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          foregroundColor: colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: AppConstants.fontFamilySmall,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 적용 버튼
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _selectedStartDate != null &&
                                _selectedEndDate != null
                            ? _apply
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          disabledBackgroundColor:
                              colorScheme.surfaceContainerHighest,
                          disabledForegroundColor: colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          '적용',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: AppConstants.fontFamilySmall,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ), // PopScope
    ); // SafeArea
  }
}
