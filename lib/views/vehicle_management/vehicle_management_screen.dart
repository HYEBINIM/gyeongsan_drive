import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle_info_model.dart';
import '../../routes/app_routes.dart';
import '../../utils/constants.dart';
import '../../utils/login_required_utils.dart';
import '../../utils/snackbar_utils.dart';
import '../../view_models/vehicle_management/vehicle_management_viewmodel.dart';
import '../../widgets/vehicle_management/delete_vehicle_bottom_sheet.dart';

/// 차량 관리 화면
class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() =>
      _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 로드 시 차량 목록 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleManagementViewModel>().loadVehicles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('차량 관리'), centerTitle: true),
      body: SafeArea(
        child: Consumer<VehicleManagementViewModel>(
          builder: (context, viewModel, child) {
            // 로딩 상태
            if (viewModel.isLoading && viewModel.vehicles.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // 에러 상태
            if (viewModel.errorMessage != null && viewModel.vehicles.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '오류가 발생했습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.error,
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      viewModel.errorMessage ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await LoginRequiredUtils.handlePrimaryAction(
                          context: context,
                          errorMessage: viewModel.errorMessage,
                          onRetry: () => viewModel.loadVehicles(),
                          returnRoute: AppRoutes.vehicleManagement,
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        LoginRequiredUtils.resolvePrimaryButtonLabel(
                          viewModel.errorMessage,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // 빈 상태
            if (viewModel.vehicles.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 80,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '등록된 차량이 없습니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '우측 하단의 버튼을 눌러\n첫 번째 차량을 등록해보세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // 차량 목록
            return RefreshIndicator(
              onRefresh: () => viewModel.loadVehicles(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: viewModel.vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = viewModel.vehicles[index];
                  return _buildVehicleCard(context, viewModel, vehicle);
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 차량 등록 화면으로 이동
          await Navigator.pushNamed(context, AppRoutes.vehicleRegistration);
          // 등록 후 돌아왔을 때 목록 새로고침
          if (!mounted) return;
          context.read<VehicleManagementViewModel>().loadVehicles();
        },
        icon: const Icon(Icons.add),
        label: const Text(
          '차량 추가',
          style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
        ),
      ),
    );
  }

  /// 차량 카드 위젯
  Widget _buildVehicleCard(
    BuildContext context,
    VehicleManagementViewModel viewModel,
    VehicleInfo vehicle,
  ) {
    final isActive = vehicle.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          // 활성 차량이 아닌 경우에만 변경 가능
          if (!isActive) {
            final success = await viewModel.setActiveVehicle(vehicle.vehicleId);
            if (!mounted) return;
            if (success) {
              SnackBarUtils.showSuccess(
                context,
                '${vehicle.vehicleNumber}을(를) 사용 차량으로 설정했습니다',
              );
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 차량번호 + 배지 + 삭제 버튼
              Row(
                children: [
                  // 차량번호 (좌측 아이콘 제거)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              vehicle.vehicleNumber,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontFamily: AppConstants.fontFamilySmall,
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '사용중',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        fontFamily:
                                            AppConstants.fontFamilySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vehicle.modelName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontFamily: AppConstants.fontFamilySmall,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 삭제 버튼
                  IconButton(
                    onPressed: () {
                      DeleteVehicleBottomSheet.show(context, vehicle, () async {
                        final success = await viewModel.deleteVehicle(
                          vehicle.vehicleId,
                        );
                        if (!mounted) return;
                        if (success) {
                          SnackBarUtils.showSuccess(
                            context,
                            '${vehicle.vehicleNumber}이(가) 삭제되었습니다',
                          );
                        } else {
                          SnackBarUtils.showError(
                            context,
                            viewModel.errorMessage ?? '삭제에 실패했습니다',
                          );
                        }
                      });
                    },
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: '차량 삭제',
                  ),
                ],
              ),

              // 구분선 및 차량 상세 정보 제거됨

              // 비활성 차량 안내 표기 제거됨
            ],
          ),
        ),
      ),
    );
  }
}
