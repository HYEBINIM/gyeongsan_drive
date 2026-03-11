import 'package:flutter/material.dart';
import '../../models/vehicle_info_model.dart';
import '../../utils/constants.dart';

/// 차량 삭제 확인 바텀 시트
class DeleteVehicleBottomSheet extends StatelessWidget {
  final VehicleInfo vehicle;
  final VoidCallback onConfirm;

  const DeleteVehicleBottomSheet({
    super.key,
    required this.vehicle,
    required this.onConfirm,
  });

  /// 바텀 시트 표시
  static Future<bool?> show(
    BuildContext context,
    VehicleInfo vehicle,
    VoidCallback onConfirm,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          DeleteVehicleBottomSheet(vehicle: vehicle, onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 한국어 주석: 뒤로가기 버튼으로 바텀시트 닫기 허용
    return PopScope(
      canPop: true,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들 바
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 16),

              // 경고 아이콘
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),

              const SizedBox(height: 16),

              // 제목
              Text(
                '차량 삭제',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: AppConstants.fontFamilyBig,
                ),
              ),

              const SizedBox(height: 16),

              // 차량 정보 (아이콘 제거)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // 아이콘 없이 차량번호만 표시
                    Text(
                      vehicle.vehicleNumber,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle.modelName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 경고 메시지
              Text(
                '이 차량을 정말 삭제하시겠습니까?',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                '삭제된 차량은 복구할 수 없습니다',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.error,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // 버튼 영역
              Row(
                children: [
                  // 취소 버튼
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 삭제 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        '삭제',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 안전 여백 (키보드 등)
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
