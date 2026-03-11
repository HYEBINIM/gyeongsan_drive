import 'dart:async'; // 한국어 주석: 순차 전환 지연을 위한 Future.delayed 사용
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routes/app_routes.dart';
import '../../utils/constants.dart';
import '../../utils/login_required_utils.dart';
import '../../view_models/home/home_viewmodel.dart';
import '../../view_models/home/voice_command_viewmodel.dart';
import '../../main.dart';
import '../navigation/navigation_screen.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/common_app_bar.dart';
import '../../widgets/common/no_vehicle_overlay.dart';
import '../../widgets/common/shimmer_wrapper.dart';
import '../../widgets/home/battery_detail_card.dart';
import '../../widgets/home/battery_info_card.dart';
import '../../widgets/home/vehicle_info_card.dart';
import '../../widgets/home/voice_command_fab.dart';

/// 홈 화면 UI
/// 차량 실시간 정보를 표시하는 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 한국어 주석: 섹션별 순차 전환 플래그 (헤더 → 카드1 → 카드2 → 카드3)
  bool _showHeaderReal = false;
  bool _showCard1Real = false;
  bool _showCard2Real = false;
  bool _showCard3Real = false;
  @override
  void initState() {
    super.initState();

    // 화면 진입 시 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 한국어 주석: Provider가 앱 전역에 살아있을 수 있으므로 강제 초기화로 데이터 로드 보장
      context.read<HomeViewModel>().initialize(force: true);

      // 한국어 주석: 음성 길 안내 요청 발생 시 NavigationScreen으로 전환
      final voiceVm = context.read<VoiceCommandViewModel>();
      voiceVm.onNavigationRequested = (destination) {
        if (!mounted) return;
        final navState = navigatorKey.currentState;
        if (navState == null || !navState.mounted) return;
        navState.push(
          MaterialPageRoute(
            builder: (ctx) => NavigationScreen(
              start: null, // null → 현재 위치를 사용
              destination: destination,
            ),
          ),
        );
      };
    });
  }

  @override
  void dispose() {
    // 한국어 주석: 화면 폐기 시 콜백 해제하여 안전한 네비게이션 방지
    final voiceVm = context.read<VoiceCommandViewModel>();
    voiceVm.onNavigationRequested = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<HomeViewModel>(
        builder: (context, viewModel, child) {
          final colorScheme = Theme.of(context).colorScheme;

          // 한국어 주석: 데이터가 준비되면 순차 전환 스케줄 시작 (한 번만)
          _maybeStartStagedReveal(viewModel);

          return Scaffold(
            appBar: const CommonAppBar(title: ''),
            drawer: AppDrawer(),
            backgroundColor: colorScheme.surface,
            body: Stack(
              fit: StackFit.expand,
              children: [
                _buildUnifiedContent(context, viewModel),

                // 한국어 주석: 음성 명령 FAB 버튼 (우측 하단)
                // - 콘텐츠 위에 표시하되, 오버레이/다이얼로그보다 아래 레이어에 위치
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: VoiceCommandFAB(
                    onGetQueryPrefix: () async {
                      final voiceViewModel = context
                          .read<VoiceCommandViewModel>();
                      final cachedPrefix = voiceViewModel.vehicleQueryPrefix;
                      if (cachedPrefix != null) {
                        return cachedPrefix;
                      }

                      final homeViewModel = context.read<HomeViewModel>();
                      final mtId = homeViewModel.vehicleInfo?.mtId;

                      if (mtId == null || mtId.isEmpty) {
                        return null; // 에러는 FAB 내부에서 처리
                      }

                      return '차량 $mtId';
                    },
                  ),
                ),

                // 차량 미등록 시 오버레이 (로딩 중에는 표시하지 않음)
                if (!viewModel.isLoading && !viewModel.hasVehicle)
                  const NoVehicleOverlay(),

                // 에러 발생 시 오버레이 (로딩 중에는 표시하지 않음)
                if (!viewModel.isLoading && viewModel.errorMessage != null)
                  _buildErrorOverlay(context, viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  // 한국어 주석: 데이터 준비 후 섹션별 순차 노출 스케줄링
  void _maybeStartStagedReveal(HomeViewModel viewModel) {
    final hasInfo =
        viewModel.vehicleInfo != null && viewModel.errorMessage == null;
    final hasData =
        viewModel.vehicleData != null && viewModel.errorMessage == null;

    // 데이터가 모두 준비되지 않았거나 이미 시작했다면 무시
    if (!hasInfo || !hasData || _showHeaderReal) return;

    // 다음 프레임에 순차 활성화 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 한국어 주석: 헤더 즉시, 카드들은 150/350/700ms로 충분히 간격을 두어 순차 전환
      setState(() {
        _showHeaderReal = true;
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() {
          _showCard1Real = true;
        });
      });

      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _showCard2Real = true;
        });
      });

      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _showCard3Real = true;
        });
      });
    });
  }

  // 한국어 주석: 크기 변화를 최소화하는 안정적인 페이드 전환 섹션
  // - 스켈레톤과 실데이터를 같은 영역(Stack) 안에서 AnimatedOpacity로 교차 페이드
  // - 실데이터가 아직 없으면 SizedBox.shrink()로 대체하되, 스켈레톤이 영역을 유지
  Widget _buildStableFadeSection({
    required bool showReal,
    required Widget real,
    required Widget skeleton,
    Duration duration = const Duration(milliseconds: 150),
  }) {
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        // 실데이터 레이어
        AnimatedOpacity(
          opacity: showReal ? 1.0 : 0.0,
          duration: duration,
          curve: Curves.easeInOut,
          child: IgnorePointer(ignoring: !showReal, child: real),
        ),
        // 스켈레톤 레이어 (실데이터가 보일 때는 페이드 아웃하고 입력 차단)
        AnimatedOpacity(
          opacity: showReal ? 0.0 : 1.0,
          duration: duration,
          curve: Curves.easeInOut,
          child: IgnorePointer(ignoring: showReal, child: skeleton),
        ),
      ],
    );
  }

  /// 통합 콘텐츠: 단일 스크롤 트리 유지 (스켈레톤/실데이터 전환)
  Widget _buildUnifiedContent(BuildContext context, HomeViewModel viewModel) {
    final info = viewModel.vehicleInfo;
    final data = viewModel.vehicleData;
    final bool hasInfo = info != null && viewModel.errorMessage == null;
    final bool hasData = data != null && viewModel.errorMessage == null;

    return RefreshIndicator(
      // 한국어 주석: 항상 스크롤 가능하도록 하여 새로고침 활성화
      onRefresh: () => viewModel.refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: 페이드 전환 + 리페인트 경계로 깜빡임 최소화
            RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: hasInfo && _showHeaderReal
                    ? KeyedSubtree(
                        key: ValueKey('header_real'),
                        // ignore: unnecessary_non_null_assertion
                        child: _buildHeader(context, viewModel, info!),
                      )
                    : KeyedSubtree(
                        key: ValueKey('header_skeleton'),
                        child: _buildSkeletonHeader(),
                      ),
              ),
            ),
            const SizedBox(height: 4),

            // 차량 이미지: 항상 동일하게 표시하여 레이아웃 안정화
            _buildVehicleImage(),
            const SizedBox(height: 4),

            // 카드 1: 주행 정보 카드
            RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: hasData && _showCard1Real
                    ? KeyedSubtree(
                        key: ValueKey('card_vic_real'),
                        // ignore: unnecessary_non_null_assertion
                        child: VehicleInfoCard(data: data!),
                      )
                    : KeyedSubtree(
                        key: ValueKey('card_vic_skeleton'),
                        child: _buildSkeletonVehicleInfoCard(),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 카드 2: 배터리 정보 카드
            RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: hasData && _showCard2Real
                    ? KeyedSubtree(
                        key: ValueKey('card_bic_real'),
                        // ignore: unnecessary_non_null_assertion
                        child: BatteryInfoCard(data: data!),
                      )
                    : KeyedSubtree(
                        key: ValueKey('card_bic_skeleton'),
                        child: _buildSkeletonBatteryInfoCard(),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 카드 3: 배터리 세부 정보 카드 (옵션 A: 크기 유지 + Stack + AnimatedOpacity)
            RepaintBoundary(
              child: _buildStableFadeSection(
                // 한국어 주석: 실데이터 표시 여부(순차 전환 플래그까지 만족해야 페이드 인)
                showReal: hasData && _showCard3Real,
                // 한국어 주석: 실데이터 위젯(데이터가 준비된 경우에만 생성)
                real: hasData
                    // ignore: unnecessary_non_null_assertion
                    ? BatteryDetailCard(data: data!)
                    : const SizedBox.shrink(),
                // 한국어 주석: 스켈레톤 위젯
                skeleton: _buildSkeletonBatteryDetailCard(),
                // 한국어 주석: 페이드 시간
                duration: const Duration(milliseconds: 150),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 스켈레톤 헤더
  Widget _buildSkeletonHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerWrapper(
              child: Container(
                width: 120,
                height: 24,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ShimmerWrapper(
              child: Container(
                width: 200,
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
        ShimmerWrapper(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  /// 스켈레톤 주행 정보 카드
  Widget _buildSkeletonVehicleInfoCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSkeletonInfoItem('총 주행거리', 'km'),
          Container(width: 1, height: 40, color: colorScheme.outline),
          _buildSkeletonInfoItem('차량 속도', 'km/h'),
          Container(width: 1, height: 40, color: colorScheme.outline),
          _buildSkeletonInfoItem('배터리 잔량', '%'),
        ],
      ),
    );
  }

  /// 스켈레톤 배터리 정보 카드
  Widget _buildSkeletonBatteryInfoCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '배터리 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: AppConstants.fontFamilyBig,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSkeletonInfoItem('배터리 온도', '℃'),
              _buildSkeletonInfoItem('배터리 전압', 'v'),
              _buildSkeletonInfoItem('배터리 전류', 'A'),
              _buildSkeletonInfoItem('급속 충전 횟수', '회'),
            ],
          ),
        ],
      ),
    );
  }

  /// 스켈레톤 배터리 상세 카드
  Widget _buildSkeletonBatteryDetailCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '배터리 세부 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: AppConstants.fontFamilyBig,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSkeletonDetailItem('셀 Max 전압', 'v')),
              Expanded(child: _buildSkeletonDetailItem('셀 Min 전압', 'v')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSkeletonDetailItem('모듈 Max 온도', '°C')),
              Expanded(child: _buildSkeletonDetailItem('모듈 Min 온도', '°C')),
            ],
          ),
        ],
      ),
    );
  }

  /// 스켈레톤 세부 항목 (배터리 상세 카드용)
  Widget _buildSkeletonDetailItem(String label, String unit) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontFamily: AppConstants.fontFamilySmall,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShimmerWrapper(
              child: Container(
                width: 40,
                height: 20,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 스켈레톤 개별 항목
  Widget _buildSkeletonInfoItem(String label, String unit) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontFamily: AppConstants.fontFamilySmall,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ShimmerWrapper(
              child: Container(
                width: 50,
                height: 24,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 에러 오버레이
  Widget _buildErrorOverlay(BuildContext context, HomeViewModel viewModel) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Stack(
        children: [
          // 배경 흐림 효과 (전체 화면 커버)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: colorScheme.scrim.withValues(alpha: 0.3)),
            ),
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
                    color: colorScheme.scrim.withValues(alpha: 0.1),
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
                    viewModel.errorMessage ?? '알 수 없는 오류',
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: AppConstants.fontFamilySmall,
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
                          errorMessage: viewModel.errorMessage,
                          onRetry: () => viewModel.initialize(),
                          returnRoute: AppRoutes.mainNavigation,
                          returnArguments: 0, // 홈 탭으로 복귀
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        LoginRequiredUtils.resolvePrimaryButtonLabel(
                          viewModel.errorMessage,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 기존 _buildContent는 통합 콘텐츠로 대체됨

  /// 헤더
  Widget _buildHeader(BuildContext context, HomeViewModel viewModel, info) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.vehicleNumber,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: AppConstants.fontFamilyBig,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${info.manufacturer} | ${info.modelName} | ${info.fuelType}',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ],
        ),
        IconButton(
          icon: viewModel.isRefreshing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          onPressed: viewModel.isRefreshing
              ? null
              : () => viewModel.refreshData(),
        ),
      ],
    );
  }

  /// 차량 이미지
  Widget _buildVehicleImage() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Image.asset(
        'assets/vehicle/main_car.png',
        width: 350,
        height: 200,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 350,
            height: 200,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Icon(
              Icons.directions_car,
              size: 80,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          );
        },
      ),
    );
  }
}
