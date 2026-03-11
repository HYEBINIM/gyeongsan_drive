import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 권한 페이지 공통 템플릿 위젯
/// DRY 원칙에 따라 중복 코드 제거
class PermissionPageTemplate extends StatelessWidget {
  final IconData icon; // 권한 아이콘
  final String title; // 권한 제목
  final String description; // 권한 설명
  final String buttonText; // 버튼 텍스트
  final VoidCallback onButtonPressed; // 버튼 클릭 콜백
  final int currentPage; // 현재 페이지 번호 (1부터 시작)
  final int totalPages; // 전체 페이지 수

  const PermissionPageTemplate({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onButtonPressed,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // 진행 표시기
              Text(
                '$currentPage / $totalPages',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),

              const Spacer(),

              // 권한 아이콘
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 60, color: colorScheme.primary),
              ),

              const SizedBox(height: 40),

              // 권한 제목
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontFamily: AppConstants.fontFamilyBig,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // 권한 설명
              Text(
                description,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.secondary,
                  height: 1.5,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // 다음 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onButtonPressed,
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppConstants.fontFamilySmall,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
