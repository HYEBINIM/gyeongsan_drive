import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 년월 선택 BottomSheet
/// BottomSheet가 닫힐 때 {'year': int, 'month': int} Map을 반환
class MonthYearPickerBottomSheet extends StatefulWidget {
  final int initialYear;
  final int initialMonth;

  const MonthYearPickerBottomSheet({
    super.key,
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  State<MonthYearPickerBottomSheet> createState() =>
      _MonthYearPickerBottomSheetState();
}

class _MonthYearPickerBottomSheetState
    extends State<MonthYearPickerBottomSheet> {
  late int _selectedYear;
  late int _selectedMonth;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;

  // 선택 가능한 년도 범위 (2020년부터 올해까지)
  static final int _startYear = 2020;
  late final int _endYear;
  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
    _endYear = DateTime.now().year;
    _years = List.generate(_endYear - _startYear + 1, (i) => _startYear + i);

    // 초기 선택된 위치로 스크롤 컨트롤러 설정
    final yearIndex = _years.indexOf(_selectedYear);
    _yearController = FixedExtentScrollController(initialItem: yearIndex);
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  /// 적용 (BottomSheet를 닫으면서 선택된 년월 반환)
  void _apply() {
    Navigator.pop(context, {'year': _selectedYear, 'month': _selectedMonth});
  }

  /// 취소 (아무것도 반환하지 않고 닫기)
  void _cancel() {
    Navigator.pop(context);
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
            maxHeight: MediaQuery.of(context).size.height * 0.5, // 최대 높이 50%
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
                      onPressed: _cancel,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 년월 휠 선택기
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    // 년도 선택 휠
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: _yearController,
                        itemExtent: 50,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedYear = _years[index];
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (context, index) {
                            if (index < 0 || index >= _years.length) {
                              return null;
                            }
                            final year = _years[index];
                            final isSelected = year == _selectedYear;
                            return Center(
                              child: Text(
                                '$year년',
                                style: TextStyle(
                                  fontSize: isSelected ? 20 : 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontFamily: AppConstants.fontFamilySmall,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
                                ),
                              ),
                            );
                          },
                          childCount: _years.length,
                        ),
                      ),
                    ),

                    // 구분선
                    Container(
                      width: 1,
                      height: 150,
                      color: colorScheme.surfaceContainerHighest,
                    ),

                    // 월 선택 휠
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: _monthController,
                        itemExtent: 50,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedMonth = index + 1;
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (context, index) {
                            if (index < 0 || index >= 12) {
                              return null;
                            }
                            final month = index + 1;
                            final isSelected = month == _selectedMonth;
                            return Center(
                              child: Text(
                                '${month.toString().padLeft(2, '0')}월',
                                style: TextStyle(
                                  fontSize: isSelected ? 20 : 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontFamily: AppConstants.fontFamilySmall,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
                                ),
                              ),
                            );
                          },
                          childCount: 12,
                        ),
                      ),
                    ),
                  ],
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
                    // 취소 버튼
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _cancel,
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
                        onPressed: _apply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
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
