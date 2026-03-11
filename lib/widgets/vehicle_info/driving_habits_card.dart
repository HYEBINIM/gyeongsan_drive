import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/driving_score_model.dart';
import '../../utils/constants.dart';

/// 운전 습관 통계 카드 위젯
class DrivingHabitsCard extends StatelessWidget {
  final DrivingHabits? drivingHabits;
  final DateTime? selectedDate;

  const DrivingHabitsCard({
    super.key,
    required this.drivingHabits,
    this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    // 데이터가 없으면 빈 컨테이너 반환
    if (drivingHabits == null) {
      return const SizedBox.shrink();
    }

    final habits = drivingHabits!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 날짜 + 주행거리
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 날짜
              Text(
                '${DateFormat('M/d').format(selectedDate ?? DateTime.now())} 주행거리',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              // 주행거리
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${habits.distance}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppConstants.fontFamilyBig,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.87),
                    ),
                  ),
                  Text(
                    'km',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: AppConstants.fontFamilySmall,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.87),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 구분선
          Divider(
            color: Theme.of(context).colorScheme.primary,
            thickness: 1,
            height: 1,
          ),
          const SizedBox(height: 12),
          // 하단: 운전 습관 통계 그리드
          _buildHabitsGrid(habits),
        ],
      ),
    );
  }

  /// 운전 습관 통계 그리드 위젯 (2열 레이아웃)
  Widget _buildHabitsGrid(DrivingHabits habits) {
    // 운전 습관 항목 리스트 (7개: 좌측 4개 + 우측 3개 - 모두 다른 색상)
    final habitItems = [
      // 좌측 4개
      _HabitItem(
        label: '급좌회전',
        count: habits.suddenLeftTurn,
        color: const Color(0xFF00BCD4), // 청록색 (Teal)
      ),
      _HabitItem(
        label: '급유턴',
        count: habits.suddenTurn,
        color: const Color(0xFF4CAF50), // 초록색 (Green)
      ),
      _HabitItem(
        label: '급감속',
        count: habits.suddenBraking,
        color: const Color(0xFF9C27B0), // 보라색 (Purple)
      ),
      _HabitItem(
        label: '급정지',
        count: habits.suddenHorn, // 급경적 데이터 사용
        color: const Color(0xFFF44336), // 빨간색 (Red)
      ),
      // 우측 3개
      _HabitItem(
        label: '급우회전',
        count: habits.suddenRightTurn,
        color: const Color(0xFF8BC34A), // 라임색 (Light Green)
      ),
      _HabitItem(
        label: '급가속',
        count: habits.suddenAcceleration,
        color: const Color(0xFFFF9800), // 주황색 (Orange)
      ),
      _HabitItem(
        label: '급출발',
        count: habits.suddenStart,
        color: const Color(0xFFE91E63), // 분홍색 (Pink)
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 좌측 컬럼 (4개)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHabitItem(habitItems[0]), // 급좌회전
              const SizedBox(height: 8),
              _buildHabitItem(habitItems[1]), // 급유턴
              const SizedBox(height: 8),
              _buildHabitItem(habitItems[2]), // 급감속
              const SizedBox(height: 8),
              _buildHabitItem(habitItems[3]), // 급정지
            ],
          ),
        ),
        const SizedBox(width: 12),
        // 우측 컬럼 (3개)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHabitItem(habitItems[4]), // 급우회전
              const SizedBox(height: 8),
              _buildHabitItem(habitItems[5]), // 급가속
              const SizedBox(height: 8),
              _buildHabitItem(habitItems[6]), // 급출발
            ],
          ),
        ),
      ],
    );
  }

  /// 개별 운전 습관 항목 위젯
  Widget _buildHabitItem(_HabitItem item) {
    return Row(
      children: [
        // 색상 동그라미
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        // 라벨
        Builder(
          builder: (context) => Text(
            item.label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: AppConstants.fontFamilySmall,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        const Spacer(), // 남은 공간 차지
        // 횟수 (우측 끝)
        Builder(
          builder: (context) => Text(
            '${item.count}회',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: AppConstants.fontFamilySmall,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.87),
            ),
          ),
        ),
      ],
    );
  }
}

/// 운전 습관 항목 데이터 클래스
class _HabitItem {
  final String label;
  final int count;
  final Color color;

  _HabitItem({required this.label, required this.count, required this.color});
}
