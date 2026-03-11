import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../view_models/vehicle_registration/vehicle_registration_viewmodel.dart';
import '../../view_models/home/home_viewmodel.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/vehicle_registration/vehicle_info_preview.dart';
import '../../utils/constants.dart';
import 'vehicle_selection_sheet.dart';

/// 차량 등록 화면
class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({super.key});

  @override
  State<VehicleRegistrationScreen> createState() =>
      _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final TextEditingController _vehicleNumberController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 ViewModel 초기화 (이전 조회 데이터 제거)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleRegistrationViewModel>().reset();
    });
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    // 화면 종료 시 ViewModel 상태 초기화
    context.read<VehicleRegistrationViewModel>().reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Consumer<VehicleRegistrationViewModel>(
          builder: (context, viewModel, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  const Text(
                    '차량을 등록해주세요',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppConstants.fontFamilyBig,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 안내 문구
                  Text(
                    '차량번호 뒷자리를 입력하면\n자동으로 정보를 가져옵니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 차량번호 입력 필드 (뒷 4자리만 입력)
                  CustomTextField(
                    label: '차량번호 뒷 4자리',
                    hint: '예: 3597',
                    controller: _vehicleNumberController,
                    errorText: viewModel.isValidated ? null : null,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      viewModel.setVehicleNumber(value);
                    },
                    enabled:
                        !viewModel.isLoading &&
                        !viewModel.isValidating &&
                        !viewModel.isFinalizingRegistration,
                  ),
                  const SizedBox(height: 24),

                  // 차량 정보 미리보기 (조회 성공 시)
                  if (viewModel.isValidated &&
                      viewModel.vehicleInfo != null) ...[
                    VehicleInfoPreview(vehicleInfo: viewModel.vehicleInfo!),
                    const SizedBox(height: 24),
                  ],

                  // 에러 메시지
                  if (viewModel.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              viewModel.errorMessage!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 조회/등록 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _getButtonAction(context, viewModel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getButtonColor(context, viewModel),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _buildButtonChild(context, viewModel),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 버튼 액션 결정
  VoidCallback? _getButtonAction(
    BuildContext context,
    VehicleRegistrationViewModel viewModel,
  ) {
    if (viewModel.isLoading ||
        viewModel.isValidating ||
        viewModel.isFinalizingRegistration) {
      return null;
    }

    // 한국어 주석: 조회 단계에서는 차량번호가 4자리 숫자가 아니면 버튼 비활성
    if (!viewModel.isValidated && !viewModel.isVehicleNumberValid) {
      return null;
    }

    if (viewModel.isValidated) {
      // 조회 완료 → 등록 액션
      return () => _handleRegister(context, viewModel);
    } else {
      // 조회 전 → 검증 및 차량 선택 액션
      return () => _handleValidate(context, viewModel);
    }
  }

  /// 차량번호 검증 및 중복 차량 선택 처리
  Future<void> _handleValidate(
    BuildContext context,
    VehicleRegistrationViewModel viewModel,
  ) async {
    final results = await viewModel.validateVehicleNumber();

    if (!mounted) {
      return;
    }

    if (results == null || results.isEmpty) {
      // 한국어 주석: 결과가 없거나 단일 차량인 경우는 ViewModel에서 이미 처리됨
      return;
    }

    // 한국어 주석: 동일한 뒷 4자리를 가진 차량이 여러 대인 경우, 선택 바텀시트 표시
    if (!mounted) return;

    final currentContext = context;
    await showModalBottomSheet<void>(
      context: currentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return VehicleSelectionSheet(
          results: results,
          onVehicleSelected: (selectedInfo) {
            viewModel.selectVehicle(selectedInfo);
            Navigator.pop(sheetContext);
          },
        );
      },
    );
  }

  /// 등록 처리
  Future<void> _handleRegister(
    BuildContext context,
    VehicleRegistrationViewModel viewModel,
  ) async {
    // 후속 처리 시작 (ViewModel에서 상태 관리)
    viewModel.setFinalizingRegistration(true);

    try {
      final success = await viewModel.registerVehicle();

      if (success && mounted) {
        // HomeViewModel 차량 정보만 갱신 (최적화: 전체 초기화 대신 경량 갱신)
        if (context.mounted) {
          await context.read<HomeViewModel>().refreshVehicleOnly();
        }

        // 성공 다이얼로그 표시 후 HomeScreen으로 이동
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '차량 등록 완료',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppConstants.fontFamilyBig,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '차량이 성공적으로 등록되었습니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      viewModel.reset(); // ViewModel 상태 초기화
                      _vehicleNumberController.clear(); // 입력 필드 초기화
                      Navigator.pop(context); // 다이얼로그 닫기
                      Navigator.pop(context); // 차량등록 화면 닫기
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      // 후속 처리 완료 (ViewModel에서 상태 관리)
      viewModel.setFinalizingRegistration(false);
    }
  }

  /// 버튼 색상 결정
  Color _getButtonColor(
    BuildContext context,
    VehicleRegistrationViewModel viewModel,
  ) {
    if (viewModel.isLoading ||
        viewModel.isValidating ||
        viewModel.isFinalizingRegistration) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
    }

    if (viewModel.isValidated && viewModel.vehicleInfo != null) {
      return Theme.of(context).colorScheme.primary;
    }

    if (!viewModel.isVehicleNumberValid) {
      // 한국어 주석: 차량번호가 4자리 숫자가 아니면 버튼 비활성 색상 유지
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
    }

    return Theme.of(context).colorScheme.primary;
  }

  /// 버튼 자식 위젯 생성
  Widget _buildButtonChild(
    BuildContext context,
    VehicleRegistrationViewModel viewModel,
  ) {
    if (viewModel.isValidating ||
        viewModel.isLoading ||
        viewModel.isFinalizingRegistration) {
      // 한국어 주석: 조회/등록/후속 처리 중에는 스피너만 표시
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      );
    }

    if (viewModel.isValidated && viewModel.vehicleInfo != null) {
      return const Text('내 차량으로 등록');
    }

    return const Text('차량 정보 조회');
  }
}
