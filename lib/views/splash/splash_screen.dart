import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/splash/splash_viewmodel.dart';
import '../../utils/constants.dart';

/// 스플래시 화면 UI
/// 앱 시작 시 로고들을 표시하고 자동으로 홈 화면으로 이동
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 화면이 빌드된 후 타이머 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SplashViewModel>().startSplashTimer(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFBFBFB),
      body: SafeArea(
        child: Stack(
          children: [
            // 중앙 로고 (GIF 애니메이션)
            Center(
              child: Image.asset(
                AppConstants.logoGifPath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            // 좌측 상단 MSIT 로고
            Positioned(
              top: AppConstants.topLogoPadding,
              left: AppConstants.topLogoPadding,
              child: Image.asset(
                AppConstants.msitLogoPath,
                width: AppConstants.topLogoSize,
                height: AppConstants.topLogoSize,
                fit: BoxFit.contain,
              ),
            ),
            // 우측 상단 NIA 로고
            Positioned(
              top: AppConstants.topLogoPadding,
              right: AppConstants.topLogoPadding,
              child: Image.asset(
                AppConstants.niaLogoPath,
                width: AppConstants.topLogoSize,
                height: AppConstants.topLogoSize,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
