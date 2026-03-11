import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 한국어 주석: 여러 대의 차량 중 하나를 선택하기 위한 바텀시트
class VehicleSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> results;
  final Function(Map<String, dynamic>) onVehicleSelected;

  const VehicleSelectionSheet({
    super.key,
    required this.results,
    required this.onVehicleSelected,
  });

  @override
  State<VehicleSelectionSheet> createState() => _VehicleSelectionSheetState();
}

class _VehicleSelectionSheetState extends State<VehicleSelectionSheet> {
  int? selectedVehicleIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                '등록할 차량을 선택해주세요',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.results.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final info = widget.results[index];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedVehicleIndex = index;
                      });
                    },
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: _buildVehicleOptionCard(
                      context,
                      info,
                      isSelected: selectedVehicleIndex == index,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedVehicleIndex != null
                    ? () {
                        widget.onVehicleSelected(
                          widget.results[selectedVehicleIndex!],
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: selectedVehicleIndex != null
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  foregroundColor: selectedVehicleIndex != null
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                  disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                  disabledForegroundColor: colorScheme.onSurface.withValues(
                    alpha: 0.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 한국어 주석: 중복된 차량 목록에서 각 차량을 표시하는 카드
  Widget _buildVehicleOptionCard(
    BuildContext context,
    Map<String, dynamic> vehicleInfo, {
    bool isSelected = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // 한국어 주석: 체크 아이콘 (선택 상태 표시)
        Icon(
          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isSelected ? colorScheme.primary : colorScheme.outline,
          size: 24,
        ),
        const SizedBox(width: 12),
        // 한국어 주석: 차량 정보 카드
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 1.0)
                    : colorScheme.primary.withValues(alpha: 0.3),
                width: isSelected ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  context,
                  '차량번호',
                  vehicleInfo['vehicleNumber'] as String? ?? '-',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  '모델명',
                  vehicleInfo['modelName'] as String? ?? '-',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  '제조사',
                  vehicleInfo['manufacturer'] as String? ?? '-',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ),
      ],
    );
  }
}
