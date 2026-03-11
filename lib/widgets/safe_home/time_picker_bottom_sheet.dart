import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 도착 시간 선택을 위한 커스텀 바텀시트
///
/// 이미지 디자인 기반:
/// - Date/Time 탭 전환
/// - 스크롤 가능한 시/분/AM-PM 선택기
/// - 중앙 선택 값 파란색 강조
/// - Confirm 버튼
class TimePickerBottomSheet extends StatefulWidget {
  /// 초기 시간 (기본값: 현재 시간)
  final TimeOfDay initialTime;

  /// 시간 선택 완료 시 콜백
  final void Function(TimeOfDay selectedTime) onConfirm;

  const TimePickerBottomSheet({
    super.key,
    required this.initialTime,
    required this.onConfirm,
  });

  @override
  State<TimePickerBottomSheet> createState() => _TimePickerBottomSheetState();

  /// 바텀시트 표시 헬퍼 메서드
  static Future<TimeOfDay?> show(
    BuildContext context, {
    required TimeOfDay initialTime,
  }) async {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimePickerBottomSheet(
        initialTime: initialTime,
        onConfirm: (selectedTime) {
          Navigator.of(context).pop(selectedTime);
        },
      ),
    );
  }
}

class _TimePickerBottomSheetState extends State<TimePickerBottomSheet> {
  late int _selectedHour;
  late int _selectedMinute;
  late DayPeriod _selectedPeriod;

  // 스크롤 컨트롤러
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;

  @override
  void initState() {
    super.initState();

    // 12시간 형식으로 변환
    final hour12 = widget.initialTime.hourOfPeriod == 0
        ? 12
        : widget.initialTime.hourOfPeriod;
    _selectedHour = hour12;
    _selectedMinute = widget.initialTime.minute;
    _selectedPeriod = widget.initialTime.period;

    // 스크롤 컨트롤러 초기화 (선택된 값으로 시작)
    _hourController = FixedExtentScrollController(
      initialItem: _selectedHour - 1, // 1~12 → 0~11 인덱스
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinute,
    );
    _periodController = FixedExtentScrollController(
      initialItem: _selectedPeriod == DayPeriod.am ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  /// Confirm 버튼 클릭 처리
  void _handleConfirm() {
    // 12시간 → 24시간 형식 변환
    int hour24;
    if (_selectedPeriod == DayPeriod.am) {
      hour24 = _selectedHour == 12 ? 0 : _selectedHour;
    } else {
      hour24 = _selectedHour == 12 ? 12 : _selectedHour + 12;
    }

    final selectedTime = TimeOfDay(hour: hour24, minute: _selectedMinute);
    widget.onConfirm(selectedTime);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 헤더: 타이틀 + 닫기 버튼
            _buildHeader(context, colorScheme),

            const SizedBox(height: 16),

            // 시간 선택기 (스크롤 휠)
            Expanded(child: _buildTimePicker(colorScheme)),

            const SizedBox(height: 16),

            // Confirm 버튼
            _buildConfirmButton(colorScheme),
          ],
        ),
      ),
    );
  }

  /// 헤더 영역 (타이틀 + 닫기 버튼)
  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            '도착 시간 설정',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// 시간 선택기 (스크롤 휠 3개: Hour, Minute, AM/PM)
  Widget _buildTimePicker(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Hour (1~12)
          Expanded(
            child: _buildScrollWheel(
              controller: _hourController,
              itemCount: 12,
              itemBuilder: (index) => (index + 1).toString(),
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedHour = index + 1;
                });
              },
              colorScheme: colorScheme,
            ),
          ),

          // Minute (0~59)
          Expanded(
            child: _buildScrollWheel(
              controller: _minuteController,
              itemCount: 60,
              itemBuilder: (index) => index.toString().padLeft(2, '0'),
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedMinute = index;
                });
              },
              colorScheme: colorScheme,
            ),
          ),

          // AM / PM
          Expanded(
            child: _buildScrollWheel(
              controller: _periodController,
              itemCount: 2,
              itemBuilder: (index) => index == 0 ? 'AM' : 'PM',
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedPeriod = index == 0 ? DayPeriod.am : DayPeriod.pm;
                });
              },
              colorScheme: colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  /// 스크롤 휠 빌더
  Widget _buildScrollWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int index) itemBuilder,
    required void Function(int index) onSelectedItemChanged,
    required ColorScheme colorScheme,
  }) {
    return SizedBox(
      height: 150,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 40, // 각 항목 높이
        perspective: 0.005, // 3D 효과 감소
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onSelectedItemChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            if (index < 0 || index >= itemCount) return null;

            // 현재 선택된 항목인지 확인
            final isSelected =
                controller.hasClients && controller.selectedItem == index;

            return Center(
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: colorScheme.primary, width: 2)
                      : null,
                ),
                child: Text(
                  itemBuilder(index),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            );
          },
          childCount: itemCount,
        ),
      ),
    );
  }

  /// Confirm 버튼
  Widget _buildConfirmButton(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _handleConfirm,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 0,
          ),
          child: const Text(
            '확인',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
