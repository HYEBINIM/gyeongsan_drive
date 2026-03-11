import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routes/app_routes.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/vehicle/firestore_vehicle_service.dart';
import '../../models/vehicle_info_model.dart';
import '../../utils/constants.dart';
import '../../widgets/common/app_drawer.dart';
import '../../view_models/home/home_viewmodel.dart';
import '../../view_models/vehicle_info/vehicle_info_viewmodel.dart';
import '../../view_models/profile/profile_viewmodel.dart';

/// 사용자 프로필 정보 화면
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreVehicleService _vehicleService = FirestoreVehicleService();

  // 차량 목록 Future를 State에 저장
  Future<List<VehicleInfo>>? _vehiclesFuture;

  @override
  void initState() {
    super.initState();
    // ProfileViewModel 초기화 및 이메일 동기화 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileViewModel = context.read<ProfileViewModel>();
      profileViewModel.initialize();
      profileViewModel.checkAndSyncEmail();
    });
    _loadVehicles();
  }

  /// 차량 목록 로드 (Future 생성)
  void _loadVehicles() {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isNotEmpty) {
      _vehiclesFuture = _vehicleService.getUserVehicles(userId);
    } else {
      _vehiclesFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileViewModel>(
      builder: (context, profileViewModel, _) {
        // 사용자 정보 가져오기 (ViewModel에서)
        final isAuthenticated = profileViewModel.isAuthenticated;
        final displayName = profileViewModel.displayName;
        final email = profileViewModel.email;
        final photoURL = profileViewModel.photoURL;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceBright,
          drawer: AppDrawer(),
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surfaceBright,
            elevation: 0,
            title: const Text(
              '내 정보',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontFamily: AppConstants.fontFamilyBig,
              ),
            ),
            centerTitle: true,
            leading: Builder(
              builder: (context) {
                if (!Navigator.canPop(context)) {
                  return IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  );
                }
                return const BackButton();
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.appSettings);
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 프로필 헤더 카드
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 프로필 아바타 (스쿼클 스타일에 가까운 둥근 모서리)
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onPrimary,
                        borderRadius: BorderRadius.circular(30),
                        image: photoURL != null
                            ? DecorationImage(
                                image: NetworkImage(photoURL),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: photoURL == null
                          ? Icon(
                              Icons.person_rounded,
                              size: 46,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),

                    if (isAuthenticated) ...[
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontFamily: AppConstants.fontFamilyBig,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.6),
                            fontFamily: AppConstants.fontFamilySmall,
                          ),
                        ),
                    ] else ...[
                      Text(
                        '로그인 후 내 정보를\n확인하실 수 있습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withValues(alpha: 0.7),
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.login);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '로그인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppConstants.fontFamilyBig,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 차량 정보 및 기타 섹션들도 카드 형태로 분리
              _buildVehicleSection(),

              const SizedBox(height: 16),

              _buildAccountSection(),

              const SizedBox(height: 16),

              _buildSupportSection(),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  /// 차량 정보 섹션 위젯
  Widget _buildVehicleSection() {
    return _buildSectionCard(
      title: '차량 정보',
      child: _vehiclesFuture == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                '로그인 후 차량 정보를 확인하실 수 있습니다.',
                style: TextStyle(
                  fontFamily: AppConstants.fontFamilySmall,
                  fontSize: 14,
                ),
              ),
            )
          : FutureBuilder<List<VehicleInfo>>(
              future: _vehiclesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      '오류: ${snapshot.error}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontFamily: AppConstants.fontFamilySmall,
                      ),
                    ),
                  );
                }

                final vehicles = snapshot.data ?? [];
                final activeVehicle = vehicles
                    .where((v) => v.isActive)
                    .firstOrNull;

                return Column(
                  children: [
                    if (activeVehicle != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.directions_car_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '현재 사용 차량',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer
                                          .withValues(alpha: 0.7),
                                      fontFamily: AppConstants.fontFamilySmall,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    activeVehicle.vehicleNumber,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSecondaryContainer,
                                      fontFamily: AppConstants.fontFamilyBig,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    activeVehicle.modelName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer
                                          .withValues(alpha: 0.8),
                                      fontFamily: AppConstants.fontFamilySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 차량 관리 / 등록 버튼
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              final homeViewModel = context
                                  .read<HomeViewModel>();
                              final vehicleInfoViewModel = context
                                  .read<VehicleInfoViewModel>();

                              Navigator.pushNamed(
                                context,
                                AppRoutes.vehicleManagement,
                              ).then((_) {
                                if (!mounted) return;
                                setState(() {
                                  _loadVehicles();
                                });
                                homeViewModel.initialize(force: true);
                                vehicleInfoViewModel.initialize();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: const Text(
                              '차량 관리',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: AppConstants.fontFamilySmall,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () {
                              final homeViewModel = context
                                  .read<HomeViewModel>();
                              final vehicleInfoViewModel = context
                                  .read<VehicleInfoViewModel>();

                              Navigator.pushNamed(
                                context,
                                AppRoutes.vehicleRegistration,
                              ).then((_) {
                                if (!mounted) return;
                                setState(() {
                                  _loadVehicles();
                                });
                                homeViewModel.initialize(force: true);
                                vehicleInfoViewModel.initialize();
                              });
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '새 차량 등록',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: AppConstants.fontFamilySmall,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// 계정 관리 섹션 위젯
  Widget _buildAccountSection() {
    if (_authService.currentUser == null) {
      return _buildSectionCard(
        title: '계정 관리',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            '로그인 후 계정 관리를 이용하실 수 있습니다.',
            style: TextStyle(
              fontFamily: AppConstants.fontFamilySmall,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return _buildSectionCard(
      title: '계정 관리',
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.person_rounded,
            title: '이름 변경',
            onTap: () => Navigator.pushNamed(context, AppRoutes.profileEdit),
          ),
          if (_authService.isEmailPasswordUser()) ...[
            const Divider(height: 1, indent: 56, endIndent: 16),
            _buildActionTile(
              icon: Icons.lock_outline_rounded,
              title: '비밀번호 변경',
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.changePassword),
            ),
            const Divider(height: 1, indent: 56, endIndent: 16),
            _buildActionTile(
              icon: Icons.email_outlined,
              title: '이메일 변경',
              onTap: () => Navigator.pushNamed(context, AppRoutes.changeEmail),
            ),
          ],
          const Divider(height: 1, indent: 56, endIndent: 16),
          _buildActionTile(
            icon: Icons.delete_outline_rounded,
            title: '계정 삭제',
            iconColor: Theme.of(context).colorScheme.error,
            textColor: Theme.of(context).colorScheme.error,
            onTap: () => Navigator.pushNamed(context, AppRoutes.deleteAccount),
          ),
        ],
      ),
    );
  }

  /// 고객 지원 섹션 위젯
  Widget _buildSupportSection() {
    return _buildSectionCard(
      title: '고객 지원',
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.campaign_rounded,
            title: '공지사항',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.announcementList),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _buildActionTile(
            icon: Icons.help_outline_rounded,
            title: '문의하기',
            onTap: () => Navigator.pushNamed(context, AppRoutes.inquiryList),
          ),
        ],
      ),
    );
  }

  /// 공통 스와이프 카드 레이아웃 위젯 (Fintech 스타일)
  Widget _buildSectionCard({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: AppConstants.fontFamilyBig,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }

  /// 공통 액션 타일 위젯 (스쿼클 배경에 아이콘 + 우측 꺾쇠)
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final effectiveIconColor =
        iconColor ?? Theme.of(context).colorScheme.primary;
    final iconBgColor = effectiveIconColor.withValues(alpha: 0.1);
    final effectiveTextColor =
        textColor ?? Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: effectiveIconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: effectiveTextColor,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.outlineVariant,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
