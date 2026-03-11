import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/constants.dart';
import '../../../utils/login_required_utils.dart';
import '../../../view_models/vehicle_info/vehicle_info_viewmodel.dart';
import '../../../widgets/common/shimmer_wrapper.dart';
import '../../../widgets/vehicle_info/average_score_card.dart';
import '../../../widgets/vehicle_info/circular_score_card.dart';
import '../../../widgets/vehicle_info/custom_date_range_bottom_sheet.dart';
import '../../../widgets/vehicle_info/date_range_selector.dart';
import '../../../widgets/vehicle_info/driving_habits_card.dart';
import '../../../widgets/vehicle_info/ranking_card.dart';
import '../../../widgets/vehicle_info/weekly_score_chart.dart';

/// 운전점수 탭 화면
class DrivingScoreTab extends StatelessWidget {
  const DrivingScoreTab({super.key});

  /// 날짜 범위 선택 BottomSheet 표시 (최대 7일 제한)
  Future<void> _showDateRangePicker(BuildContext context) async {
    final viewModel = Provider.of<VehicleInfoViewModel>(context, listen: false);
    final scoreData = viewModel.scoreData;

    if (scoreData == null) return;

    // 커스텀 BottomSheet 표시 및 선택된 날짜 범위 받기
    final result = await showModalBottomSheet<Map<String, DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomDateRangeBottomSheet(
        initialStartDate: scoreData.startDate,
        initialEndDate: scoreData.endDate,
      ),
    );

    // BottomSheet가 닫힌 후 선택된 날짜로 데이터 로드
    if (result != null &&
        result['startDate'] != null &&
        result['endDate'] != null) {
      await viewModel.selectDateRange(result['startDate']!, result['endDate']!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleInfoViewModel>(
      builder: (context, viewModel, child) {
        final scoreData = viewModel.scoreData;
        final isLoading = viewModel.isLoading;
        final errorMessage = viewModel.errorMessage;
        final hasVehicle = viewModel.hasVehicle;

        // 로딩 중 - 스켈레톤 UI 표시
        if (isLoading && scoreData == null) {
          return _buildSkeletonContent(context);
        }

        // Stack 구조로 배경과 오버레이 레이어링
        return Stack(
          children: [
            // 배경: 데이터 있으면 실제 콘텐츠, 없으면 스켈레톤
            scoreData != null
                ? _buildContent(context, viewModel, scoreData, isLoading)
                : _buildSkeletonContent(context),

            // 에러 시 오버레이
            if (errorMessage != null && hasVehicle)
              _buildErrorOverlay(context, viewModel, errorMessage),
          ],
        );
      },
    );
  }

  /// 실제 데이터 표시 콘텐츠
  Widget _buildContent(
    BuildContext context,
    VehicleInfoViewModel viewModel,
    scoreData,
    bool isLoading,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => viewModel.refreshData(),
      color: colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단: 원형 차트 + 평균 점수 + 순위
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 원형 점수 카드 (왼쪽)
                    Expanded(
                      flex: 1,
                      child: CircularScoreCard(score: scoreData.myScore),
                    ),
                    const SizedBox(width: 12),
                    // 오른쪽 카드들
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // 평균 점수 카드
                          Expanded(
                            child: AverageScoreCard(
                              averageScore: scoreData.averageScore,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 상위 % 카드
                          Expanded(
                            child: RankingCard(
                              rankingPercentile: scoreData.rankingPercentile,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 날짜 범위 선택기
              DateRangeSelector(
                startDate: scoreData.startDate,
                endDate: scoreData.endDate,
                onDateRangePressed: () => _showDateRangePicker(context),
              ),
              const SizedBox(height: 12),
              // 주간 점수 막대 그래프 (클릭 가능) - 로딩 오버레이 포함
              Stack(
                children: [
                  WeeklyScoreChart(
                    weeklyScores: scoreData.weeklyScores,
                    onDateSelected: (date) => viewModel.selectDate(date),
                    selectedDate: viewModel.selectedDate,
                  ),
                  // 로딩 중일 때 반투명 오버레이 표시
                  if (isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // 운전 습관 통계 카드 (선택된 날짜 데이터) - 로딩 오버레이 포함
              Stack(
                children: [
                  DrivingHabitsCard(
                    drivingHabits: viewModel.selectedDayHabits,
                    selectedDate: viewModel.selectedDate,
                  ),
                  // 로딩 중일 때 반투명 오버레이 표시
                  if (isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 스켈레톤 UI - 전체 레이아웃
  Widget _buildSkeletonContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSkeletonScoreCards(colorScheme),
          const SizedBox(height: 12),
          _buildSkeletonDateSelector(colorScheme),
          const SizedBox(height: 12),
          _buildSkeletonChart(colorScheme),
          const SizedBox(height: 12),
          _buildSkeletonHabitsCard(colorScheme),
        ],
      ),
    );
  }

  /// 스켈레톤 점수 카드들
  Widget _buildSkeletonScoreCards(ColorScheme colorScheme) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 원형 차트 스켈레톤
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 실제 제목 표시
                  Text(
                    '내 운전점수',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppConstants.fontFamilySmall,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 원형 차트 스켈레톤
                  ShimmerWrapper(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 오른쪽 카드들
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: _buildSkeletonScoreCard(
                    colorScheme: colorScheme,
                    title: '평균 점수',
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildSkeletonRankingCard(colorScheme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 스켈레톤 평균 점수 카드
  Widget _buildSkeletonScoreCard({
    required ColorScheme colorScheme,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 실제 제목 표시
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontFamily: AppConstants.fontFamilySmall,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          // 점수 값 스켈레톤
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShimmerWrapper(
                child: Container(
                  width: 50,
                  height: 30,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '점',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: AppConstants.fontFamilySmall,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 스켈레톤 랭킹 카드
  Widget _buildSkeletonRankingCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 실제 제목 표시
          Text(
            '상위',
            style: TextStyle(
              fontSize: 14,
              fontFamily: AppConstants.fontFamilySmall,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          // 퍼센트 값 스켈레톤
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShimmerWrapper(
                child: Container(
                  width: 50,
                  height: 30,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '%',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: AppConstants.fontFamilySmall,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 프로그레스 바 스켈레톤
          ShimmerWrapper(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // 하위 ~ 상위 라벨 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '하위',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '상위',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 스켈레톤 날짜 선택기
  Widget _buildSkeletonDateSelector(ColorScheme colorScheme) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShimmerWrapper(
            child: Container(
              width: 150,
              height: 16,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 스켈레톤 차트
  Widget _buildSkeletonChart(ColorScheme colorScheme) {
    return _buildSkeletonCard(
      colorScheme: colorScheme,
      title: '주간 운전 점수',
      height: 200,
    );
  }

  /// 스켈레톤 운전 습관 카드
  Widget _buildSkeletonHabitsCard(ColorScheme colorScheme) {
    return _buildSkeletonCard(
      colorScheme: colorScheme,
      title: '운전 습관 통계',
      height: 180,
    );
  }

  /// 공통 스켈레톤 카드
  Widget _buildSkeletonCard({
    required ColorScheme colorScheme,
    required String title,
    double? height,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 실제 제목 표시
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: AppConstants.fontFamilySmall,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ShimmerWrapper(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 오버레이
  Widget _buildErrorOverlay(
    BuildContext context,
    VehicleInfoViewModel viewModel,
    String errorMessage,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // 배경 흐림 효과
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(color: colorScheme.scrim.withValues(alpha: 0.7)),
        ),

        // 중앙 카드
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: AppConstants.fontFamilySmall,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await LoginRequiredUtils.handlePrimaryAction(
                        context: context,
                        errorMessage: errorMessage,
                        onRetry: () => viewModel.refreshData(),
                        returnRoute: AppRoutes.mainNavigation,
                        returnArguments: 1, // 차량정보 탭으로 복귀
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      LoginRequiredUtils.resolvePrimaryButtonLabel(
                        errorMessage,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
