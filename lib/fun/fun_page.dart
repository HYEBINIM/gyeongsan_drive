// lib/fun/fun_page.dart
import 'package:flutter/material.dart';
import 'current_location_tab.dart';
import 'bus_tab.dart';

class FunPage extends StatelessWidget {
  const FunPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          toolbarHeight: 0, // ⭐ 상단 AppBar 영역 제거
          bottom: TabBar(
            indicatorColor: const Color(0xFF00C853),
            indicatorWeight: 3,
            labelColor: const Color(0xFF00C853),
            unselectedLabelColor: const Color(0xFF757575),
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(
                height: 44, // ⭐ 핵심: 탭 높이 줄이기
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 16),
                    SizedBox(width: 4),
                    Text('현위치에서 떠나기'),
                  ],
                ),
              ),
              Tab(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_bus, size: 16),
                    SizedBox(width: 4),
                    Text('버스타고 떠나기'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            CurrentLocationTab(),
            BusTab(),
          ],
        ),
      ),
    );
  }
}
