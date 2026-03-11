import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/vehicle_info/vehicle_info_viewmodel.dart';
import '../../widgets/common/common_app_bar.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/no_vehicle_overlay.dart';
import 'tabs/driving_score_tab.dart';
import 'tabs/battery_status_tab.dart';
import '../../utils/constants.dart';

/// 차량 정보 메인 화면
class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // ViewModel 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<VehicleInfoViewModel>(
        context,
        listen: false,
      );
      viewModel.initialize();
    });

    // 탭 변경 시 ViewModel 상태 업데이트
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final viewModel = Provider.of<VehicleInfoViewModel>(
          context,
          listen: false,
        );
        viewModel.selectTab(_tabController.index);

        // 한국어 주석: 배터리 탭(인덱스 1) 최초 진입 시 자동으로 데이터 로드
        // - 차량이 등록되어 있고(hasVehicle),
        // - 아직 배터리 데이터가 없으며(batteryData == null),
        // - 현재 로딩 중이 아닐 때에만(isBatteryLoading == false) 호출하여 중복 로딩 방지
        if (_tabController.index == 1 &&
            viewModel.hasVehicle &&
            viewModel.batteryData == null &&
            !viewModel.isBatteryLoading) {
          viewModel.loadBatteryData();
        } else if (_tabController.index != 1) {
          viewModel.cancelBatteryPolling(notify: false);
        }
      }
    });
  }

  @override
  void dispose() {
    final viewModel = Provider.of<VehicleInfoViewModel>(context, listen: false);
    viewModel.cancelBatteryPolling(notify: false);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const CommonAppBar(title: '차량정보'),
        drawer: AppDrawer(),
        body: Consumer<VehicleInfoViewModel>(
          builder: (context, viewModel, child) {
            return Stack(
              children: [
                Column(
                  children: [
                    // 탭바 영역: 상단 헤어라인 + 화이트 배경 + 커스텀 인디케이터
                    Container(
                      color: colorScheme.surface,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 상단 얇은 구분선 (이미지 상단 라인 재현)
                          Container(
                            height: 1,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.12,
                            ),
                          ),
                          TabBar(
                            controller: _tabController,
                            labelColor: colorScheme.primary, // 선택된 탭 색상
                            unselectedLabelColor: colorScheme.onSurface
                                .withValues(alpha: 0.6), // 비활성 탭 색상
                            // 라벨 패딩을 줄여 인디케이터가 라벨 하단에 딱 맞도록 조정
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            // 텍스트 길이와 상관없이 동일한 너비의 언더라인
                            indicatorSize: TabBarIndicatorSize.label,
                            indicator: UnderlineTabIndicator(
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 3,
                              ),
                            ),
                            labelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppConstants.fontFamilySmall,
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: AppConstants.fontFamilySmall,
                            ),
                            tabs: const [
                              Tab(
                                child: SizedBox(
                                  width: 80,
                                  child: Center(child: Text('운전점수')),
                                ),
                              ),
                              Tab(
                                child: SizedBox(
                                  width: 80,
                                  child: Center(child: Text('배터리 상태')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 탭 뷰
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: const [
                          DrivingScoreTab(), // 운전점수 탭
                          BatteryStatusTab(), // 배터리 상태 탭
                        ],
                      ),
                    ),
                  ],
                ),

                // 차량 미등록 오버레이
                if (!viewModel.isLoading && !viewModel.hasVehicle)
                  const NoVehicleOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }
}
