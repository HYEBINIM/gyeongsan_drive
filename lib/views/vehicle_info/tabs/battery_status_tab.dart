import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/constants.dart';
import '../../../utils/login_required_utils.dart';
import '../../../view_models/vehicle_info/vehicle_info_viewmodel.dart';
import '../../../widgets/common/shimmer_wrapper.dart';
import '../../../widgets/vehicle_info/battery_status_info_grid.dart';
import '../../../widgets/vehicle_info/month_year_picker_bottom_sheet.dart';
import '../../../widgets/vehicle_info/month_year_selector.dart';
import '../../../widgets/vehicle_info/soh_comparison_card.dart';
import '../../../widgets/vehicle_info/soh_line_chart.dart';

/// 배터리 상태 탭 화면
class BatteryStatusTab extends StatelessWidget {
  const BatteryStatusTab({super.key});

  /// 년월 선택 BottomSheet 표시
  Future<void> _showMonthYearPicker(BuildContext context) async {
    final viewModel = Provider.of<VehicleInfoViewModel>(context, listen: false);

    // BottomSheet 표시 및 선택된 년월 받기
    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MonthYearPickerBottomSheet(
        initialYear: viewModel.selectedYear,
        initialMonth: viewModel.selectedMonth,
      ),
    );

    // BottomSheet가 닫힌 후 선택된 년월로 데이터 로드
    if (result != null && result['year'] != null && result['month'] != null) {
      await viewModel.selectYearMonth(result['year']!, result['month']!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleInfoViewModel>(
      builder: (context, viewModel, child) {
        final batteryData = viewModel.batteryData;
        final isBatteryLoading = viewModel.isBatteryLoading;
        final isBatteryProcessing = viewModel.isBatteryProcessing;
        final batteryErrorMessage = viewModel.batteryErrorMessage;
        final hasVehicle = viewModel.hasVehicle;

        // 한국어 주석: 초기 배터리 데이터 미로딩 문제 방지용 가드
        // - 차량이 있고(hasVehicle), 데이터가 없으며(batteryData == null),
        // - 현재 로딩 중이 아니고(!isBatteryLoading), 에러도 없을 때만 자동 로드
        // - 빌드 중 setState를 피하기 위해 다음 프레임에서 실행
        if (hasVehicle &&
            batteryData == null &&
            !isBatteryLoading &&
            batteryErrorMessage == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final vm = Provider.of<VehicleInfoViewModel>(
              context,
              listen: false,
            );
            if (vm.hasVehicle &&
                vm.batteryData == null &&
                !vm.isBatteryLoading) {
              vm.loadBatteryData();
            }
          });
        }

        // 로딩 중 - 스켈레톤 UI 표시
        if (isBatteryProcessing && batteryData == null) {
          return _buildProcessingContent(context);
        }

        // 로딩 중 - 스켈레톤 UI 표시
        if (isBatteryLoading && batteryData == null) {
          return _buildSkeletonContent(context);
        }

        // Stack 구조로 배경과 오버레이 레이어링
        return Stack(
          children: [
            // 배경: 데이터 있으면 실제 콘텐츠, 없으면 스켈레톤
            batteryData != null
                ? _buildContent(context, viewModel, batteryData)
                : _buildSkeletonContent(context),

            // 로딩 시 중앙 오버레이 (데이터가 있는 상태에서 재조회할 때)
            if (batteryData != null &&
                isBatteryLoading &&
                batteryErrorMessage == null)
              _buildLoadingOverlay(context, isProcessing: isBatteryProcessing),

            // 에러 시 오버레이
            if (batteryErrorMessage != null && hasVehicle)
              _buildErrorOverlay(context, viewModel, batteryErrorMessage),
          ],
        );
      },
    );
  }

  /// 실제 데이터 표시 콘텐츠
  Widget _buildContent(
    BuildContext context,
    VehicleInfoViewModel viewModel,
    batteryData,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => viewModel.refreshBatteryData(),
      color: colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1️⃣ 년월 선택 영역
              MonthYearSelector(
                year: viewModel.selectedYear,
                month: viewModel.selectedMonth,
                onMonthYearPressed: () => _showMonthYearPicker(context),
              ),
              const SizedBox(height: 12),

              // 2️⃣ SOH 차트 영역
              SOHLineChart(
                dailySOHList: batteryData.dailySOHList,
                averageSOH: batteryData.monthlyAverageSOH,
              ),
              const SizedBox(height: 12),

              // 3️⃣ 배터리 상태 영역
              BatteryStatusInfoGrid(batteryData: batteryData),
              const SizedBox(height: 12),

              // 4️⃣ 다른 상태 비교 영역
              SOHComparisonCard(batteryData: batteryData),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(
    BuildContext context, {
    required bool isProcessing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: AbsorbPointer(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            color: colorScheme.scrim.withValues(alpha: 0.18),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        isProcessing
                            ? '배터리 상태를 계산 중입니다...'
                            : '배터리 상태를 불러오는 중입니다...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppConstants.fontFamilySmall,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                '배터리 상태를 계산 중입니다',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '완료되면 결과를 자동으로 보여드립니다.',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: AppConstants.fontFamilySmall,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
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
          _buildSkeletonMonthYearSelector(colorScheme),
          const SizedBox(height: 12),
          _buildSkeletonCard(
            colorScheme: colorScheme,
            title: 'SOH 추이',
            height: 280,
          ),
          const SizedBox(height: 12),
          _buildSkeletonCard(
            colorScheme: colorScheme,
            title: '배터리 상태',
            height: 240,
          ),
          const SizedBox(height: 12),
          _buildSkeletonCard(
            colorScheme: colorScheme,
            title: '다른 차량 비교',
            height: 240,
          ),
        ],
      ),
    );
  }

  /// 스켈레톤 년월 선택기
  Widget _buildSkeletonMonthYearSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ShimmerWrapper(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  /// 공통 스켈레톤 카드
  Widget _buildSkeletonCard({
    required ColorScheme colorScheme,
    required String title,
    required double height,
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
                        onRetry: () => viewModel.refreshBatteryData(),
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
