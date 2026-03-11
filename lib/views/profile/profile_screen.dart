import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routes/app_routes.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/vehicle/firestore_vehicle_service.dart';
import '../../models/vehicle_info_model.dart';
import '../../utils/constants.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/section_header.dart';
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
          drawer: AppDrawer(),
          appBar: AppBar(
            title: const Text('내 정보'),
            centerTitle: true,
            leading: Builder(
              builder: (context) {
                // 네비게이션 스택에서 pop할 수 없으면 (하단 탭에서 접속) 햄버거 메뉴 표시
                if (!Navigator.canPop(context)) {
                  return IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  );
                }
                // pop할 수 있으면 (Drawer에서 접속) 기본 뒤로가기 버튼 표시
                return const BackButton();
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.appSettings);
                },
              ),
            ],
          ),
          body: ListView(
            children: [
              // 프로필 헤더 영역
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Column(
                  // 수직(세로) 정렬: 아바타/이름/이메일이 한 컬럼에서 중앙 정렬되도록 설정
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 프로필 사진 (Stack 제거하여 단순화)
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: photoURL != null
                          ? NetworkImage(photoURL)
                          : null,
                      child: photoURL == null
                          ? Icon(
                              Icons.person,
                              size: 50,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),

                    if (isAuthenticated) ...[
                      // 사용자 이름 (우측 편집 아이콘 제거)
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontFamily: AppConstants.fontFamilyBig,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 이메일
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.8),
                            fontFamily: AppConstants.fontFamilySmall,
                          ),
                        ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        '로그인 후 내 정보를 확인하실 수 있습니다.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withValues(alpha: 0.8),
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            // 한국어 주석: 로그인 화면으로 이동
                            Navigator.pushNamed(context, AppRoutes.login);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            '로그인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: AppConstants.fontFamilyBig,
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 차량 정보 섹션 (아이콘 제거)
              const SectionHeader(
                title: '차량 정보',
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              ),
              _buildVehicleSection(),

              const Divider(height: 16),

              // 계정 관리 섹션 (아이콘 제거)
              const SectionHeader(
                title: '계정 관리',
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              ),
              _buildAccountSection(),

              const Divider(height: 16),

              // 고객 지원 섹션 (아이콘 제거)
              const SectionHeader(
                title: '고객 지원',
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              ),
              _buildSupportSection(),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// 차량 정보 섹션 위젯
  Widget _buildVehicleSection() {
    if (_vehiclesFuture == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('로그인 후 차량 정보를 확인하실 수 있습니다.'),
      );
    }

    return FutureBuilder<List<VehicleInfo>>(
      future: _vehiclesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('오류: ${snapshot.error}'),
          );
        }

        final vehicles = snapshot.data ?? [];
        final activeVehicle = vehicles.where((v) => v.isActive).firstOrNull;

        return Column(
          children: [
            // 현재 활성 차량 정보 (등록된 차량 수 항목 제거됨)
            if (activeVehicle != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '현재 사용 차량',
                            style: TextStyle(
                              fontSize: 12,
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                              fontFamily: AppConstants.fontFamilySmall,
                            ),
                          ),
                          Text(
                            activeVehicle.modelName,
                            style: TextStyle(
                              fontSize: 12,
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

            // 차량 관리 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // 차량 관리 화면으로 이동
                        final homeViewModel = context.read<HomeViewModel>();
                        final vehicleInfoViewModel = context
                            .read<VehicleInfoViewModel>();

                        Navigator.pushNamed(
                          context,
                          AppRoutes.vehicleManagement,
                        ).then((_) {
                          if (!mounted) return;
                          setState(() {
                            _loadVehicles(); // Future 재생성하여 FutureBuilder 재실행
                          });
                          homeViewModel.initialize(force: true);
                          vehicleInfoViewModel.initialize();
                        });
                      },
                      icon: const Icon(Icons.directions_car),
                      label: const Text(
                        '차량 관리',
                        style: TextStyle(
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final homeViewModel = context.read<HomeViewModel>();
                        final vehicleInfoViewModel = context
                            .read<VehicleInfoViewModel>();

                        Navigator.pushNamed(
                          context,
                          AppRoutes.vehicleRegistration,
                        ).then((_) {
                          if (!mounted) return;
                          setState(() {
                            _loadVehicles(); // Future 재생성하여 FutureBuilder 재실행
                          });
                          homeViewModel.initialize(force: true);
                          vehicleInfoViewModel.initialize();
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text(
                        '차량 등록',
                        style: TextStyle(
                          fontFamily: AppConstants.fontFamilySmall,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 계정 관리 섹션 위젯
  Widget _buildAccountSection() {
    // 한국어 주석: 비로그인 상태에서는 안내 문구만 표시
    if (_authService.currentUser == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('로그인 후 계정 관리를 이용하실 수 있습니다.'),
      );
    }

    return Column(
      children: [
        // 이름 변경 항목 (항상 표시)
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text(
            '이름 변경',
            style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // 프로필 편집 화면으로 이동
            Navigator.pushNamed(context, AppRoutes.profileEdit);
          },
        ),
        // 이메일 로그인 사용자만 비밀번호 변경 표시
        if (_authService.isEmailPasswordUser())
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text(
              '비밀번호 변경',
              style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.changePassword);
            },
          ),
        // 이메일 로그인 사용자만 이메일 변경 표시
        if (_authService.isEmailPasswordUser())
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text(
              '이메일 변경',
              style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.changeEmail);
            },
          ),
        // 계정 삭제 항목 (항상 표시)
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text(
            '계정 삭제',
            style: TextStyle(
              color: Colors.red,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.deleteAccount);
          },
        ),
      ],
    );
  }

  /// 고객 지원 섹션 위젯
  Widget _buildSupportSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.campaign),
          title: const Text(
            '공지사항',
            style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.announcementList);
          },
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text(
            '문의하기',
            style: TextStyle(fontFamily: AppConstants.fontFamilySmall),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.inquiryList);
          },
        ),
      ],
    );
  }
}
