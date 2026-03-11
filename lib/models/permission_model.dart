import 'package:flutter/material.dart';

/// 권한 타입 enum
enum PermissionType {
  location, // 위치 권한
  notification, // 알림 권한
  microphone, // 마이크 권한
}

/// 권한 정보 모델
/// 각 권한 페이지에서 사용할 데이터를 담음
class PermissionModel {
  final PermissionType type; // 권한 타입
  final String title; // 권한 제목
  final String description; // 권한 설명
  final IconData icon; // 권한 아이콘

  const PermissionModel({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });
}
