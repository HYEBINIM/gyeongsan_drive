import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/destination_search_result.dart';
import '../../models/navigation/route_model.dart' show LocationInfo;
import '../../models/safe_home_settings.dart';
import '../../routes/app_routes.dart';
import '../../utils/constants.dart';
import '../../utils/login_required_utils.dart';
import '../../utils/snackbar_utils.dart';
import '../../view_models/navigation/navigation_viewmodel.dart';
import '../../view_models/safe_home/safe_home_settings_viewmodel.dart';
import '../../widgets/safe_home/anomaly_detection_bottom_sheet.dart';
import '../../widgets/safe_home/destination_search_bottom_sheet.dart';
import '../../widgets/safe_home/emergency_contacts_bottom_sheet.dart';
import '../../widgets/safe_home/password_bottom_sheet.dart';
import '../../widgets/safe_home/time_picker_bottom_sheet.dart';

/// 안전귀가 설정 화면 UI
class SafeHomeSettingsScreen extends StatefulWidget {
  const SafeHomeSettingsScreen({super.key});

  @override
  State<SafeHomeSettingsScreen> createState() => _SafeHomeSettingsScreenState();
}

class _SafeHomeSettingsScreenState extends State<SafeHomeSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 설정 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SafeHomeSettingsViewModel>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('안전 귀가 설정'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      backgroundColor: colorScheme.surfaceContainerHighest,
      body: Consumer<SafeHomeSettingsViewModel>(
        builder: (context, viewModel, child) {
          // 로딩 중
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 에러 발생
          if (viewModel.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    viewModel.errorMessage!,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await LoginRequiredUtils.handlePrimaryAction(
                        context: context,
                        errorMessage: viewModel.errorMessage,
                        onRetry: () async {
                          viewModel.clearError();
                          await viewModel.initialize();
                        },
                        returnRoute: AppRoutes.safeHomeSettings,
                      );
                    },
                    child: Text(
                      LoginRequiredUtils.resolvePrimaryButtonLabel(
                        viewModel.errorMessage,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // 설정 화면
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // 기본 설정 섹션
              _SectionHeader(title: '기본 설정'),
              _SettingSection(
                children: [
                  _SettingListTile(
                    title: '목적지',
                    subtitle: '귀가할 목적지를 설정합니다',
                    titleColor: colorScheme.onSurface,
                    subtitleColor: colorScheme.outline,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          viewModel.destination ?? '미설정',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.outline),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () => _selectDestination(context, viewModel),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  _SettingListTile(
                    title: '도착 시간',
                    subtitle: '도착 예정 시간을 설정합니다',
                    titleColor: colorScheme.onSurface,
                    subtitleColor: colorScheme.outline,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (viewModel.arrivalTime != null)
                          _TimeChip(time: viewModel.arrivalTime!),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () => _selectArrivalTime(context, viewModel),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 안전 설정 섹션
              _SectionHeader(title: '안전 설정'),
              _SettingSection(
                children: [
                  _SettingListTile(
                    title: '이상 감지 기준',
                    subtitle: '물리적 감지 및 지연 기준을 설정합니다',
                    titleColor: colorScheme.onSurface,
                    subtitleColor: colorScheme.outline,
                    onTap: () => _showAnomalyDetectionSettings(context),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  _AutoReportSwitchTile(viewModel: viewModel),
                ],
              ),

              const SizedBox(height: 16),

              // 보안 설정 섹션
              _SectionHeader(title: '보안 설정'),
              _SettingSection(
                children: [
                  _SettingListTile(
                    title: '보안 암호',
                    subtitle: '비상시 사용할 4자리 숫자 암호를 설정합니다',
                    titleColor: colorScheme.onSurface,
                    subtitleColor: colorScheme.outline,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          viewModel.isPasswordSet ? '설정됨' : '미설정',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.outline),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () => _showPasswordSettings(context, viewModel),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  _SettingListTile(
                    title: '비상 지인 연락망',
                    subtitle: '위급 상황시 연락할 분들을 관리합니다',
                    titleColor: colorScheme.onSurface,
                    subtitleColor: colorScheme.outline,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${viewModel.emergencyContacts.length}명',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.outline),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () =>
                        _showEmergencyContactsSettings(context, viewModel),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  /// 목적지 선택 Bottom Sheet 표시
  Future<void> _selectDestination(
    BuildContext context,
    SafeHomeSettingsViewModel viewModel,
  ) async {
    final result = await showModalBottomSheet<SearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DestinationSearchBottomSheet(),
    );

    if (result != null && mounted) {
      try {
        await viewModel.selectDestination(result);
        if (!mounted) return;

        // 한국어 주석: 목적지 저장 성공 시 도보 최단 경로 재탐색
        // 주의: setTransportMode 호출은 기존 목적지로 calculateRoute()가 먼저 실행될 수 있어
        //       레이스 컨디션이 발생합니다. calculateShortestWalkingForSafeHome 내부에서
        //       교통수단을 도보로 고정하므로, 별도의 setTransportMode 호출을 제거합니다. (KISS)
        final navVm = context.read<NavigationViewModel>();
        final route = await navVm.calculateShortestWalkingForSafeHome(
          destination: LocationInfo(
            address: result.address,
            placeName: result.placeName,
            coordinates: LatLng(result.lat, result.lng),
          ),
        );

        if (!mounted) return;

        // 한국어 주석: 경로 계산 성공 시 도착 시간을 자동 업데이트
        if (route != null) {
          final eta = DateTime.now().add(
            Duration(minutes: route.estimatedMinutes),
          );
          await viewModel.setArrivalTime(TimeOfDay.fromDateTime(eta));
        }
        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            '목적지가 ${result.placeName}(으)로 설정되었습니다',
          );
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(context, '목적지 설정 실패: $e');
        }
      }
    }
  }

  /// 도착 시간 선택 바텀시트 표시
  Future<void> _selectArrivalTime(
    BuildContext context,
    SafeHomeSettingsViewModel viewModel,
  ) async {
    final initialTime = viewModel.arrivalTimeOfDay ?? TimeOfDay.now();

    final selectedTime = await TimePickerBottomSheet.show(
      context,
      initialTime: initialTime,
    );

    if (selectedTime != null && mounted) {
      // async 작업 전에 context 사용하여 포맷팅
      // ignore: use_build_context_synchronously
      final formattedTime = selectedTime.format(context);

      try {
        await viewModel.setArrivalTime(selectedTime);
        if (mounted) {
          SnackBarUtils.showInfo(context, '도착 시간이 $formattedTime로 설정되었습니다');
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(context, '도착 시간 설정 실패: $e');
        }
      }
    }
  }

  /// 이상 감지 기준 설정 Bottom Sheet 표시
  void _showAnomalyDetectionSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AnomalyDetectionBottomSheet(),
    );
  }

  /// 보안 암호 설정 Bottom Sheet 표시
  Future<void> _showPasswordSettings(
    BuildContext context,
    SafeHomeSettingsViewModel viewModel,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => PasswordBottomSheet(
        isPasswordSet: viewModel.isPasswordSet,
        onSetPassword: (pin) async {
          try {
            await viewModel.setPassword(pin);
            if (context.mounted) {
              Navigator.of(context).pop();
              SnackBarUtils.showSuccess(context, '보안 암호가 설정되었습니다');
            }
          } catch (e) {
            rethrow; // Bottom Sheet에서 에러 처리
          }
        },
        onVerifyPassword: (pin) => viewModel.verifyPassword(pin),
        onDeletePassword: (pin) async {
          try {
            await viewModel.deletePassword(pin);
            if (context.mounted) {
              Navigator.of(context).pop();
              SnackBarUtils.showSuccess(context, '보안 암호가 삭제되었습니다');
            }
          } catch (e) {
            rethrow; // Bottom Sheet에서 에러 처리
          }
        },
      ),
    );
  }

  /// 비상 지인 연락망 관리 Bottom Sheet 표시
  Future<void> _showEmergencyContactsSettings(
    BuildContext context,
    SafeHomeSettingsViewModel viewModel,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmergencyContactsBottomSheet(
        initialContacts: viewModel.emergencyContacts,
        onAdd: (name, phone) async {
          await viewModel.addEmergencyContact(
            EmergencyContact(name: name, phone: phone),
          );
        },
        onRemove: (index) => viewModel.removeEmergencyContact(index),
      ),
    );
  }
}

/// 섹션 헤더 위젯
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w400,
          fontFamily: AppConstants.fontFamilySmall,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// 설정 섹션 그룹 위젯 (둥근 모서리 컨테이너)
class _SettingSection extends StatelessWidget {
  final List<Widget> children;

  const _SettingSection({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }
}

/// 설정 항목 ListTile 위젯
class _SettingListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? subtitleColor;

  const _SettingListTile({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: titleColor ?? colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontFamily: AppConstants.fontFamilySmall,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: subtitleColor ?? colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontFamily: AppConstants.fontFamilySmall,
        ),
      ),
      trailing:
          trailing ??
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    );
  }
}

/// 시간 표시 칩 위젯
class _TimeChip extends StatelessWidget {
  final String time;

  const _TimeChip({required this.time});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        time,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontFamily: AppConstants.fontFamilySmall,
        ),
      ),
    );
  }
}

/// 자동신고 토글 스위치 위젯
class _AutoReportSwitchTile extends StatelessWidget {
  final SafeHomeSettingsViewModel viewModel;

  const _AutoReportSwitchTile({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      title: Text(
        '자동신고',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontFamily: AppConstants.fontFamilySmall,
        ),
      ),
      subtitle: Text(
        '이상 감지시 자동으로 여부를 설정합니다',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.outline,
          fontSize: 12,
          fontFamily: AppConstants.fontFamilySmall,
        ),
      ),
      value: viewModel.autoReport,
      activeThumbColor: colorScheme.primary,
      onChanged: (value) => viewModel.toggleAutoReport(value),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    );
  }
}
