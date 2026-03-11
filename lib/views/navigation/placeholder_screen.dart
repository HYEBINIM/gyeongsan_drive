import 'package:flutter/material.dart';
import '../../widgets/common/common_app_bar.dart';
import '../../widgets/common/app_drawer.dart';
import '../../utils/constants.dart';

/// 임시 화면 위젯 (나중에 실제 화면으로 교체)
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: CommonAppBar(title: title),
        drawer: AppDrawer(),
        body: Center(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontFamily: AppConstants.fontFamilyBig,
            ),
          ),
        ),
      ),
    );
  }
}
