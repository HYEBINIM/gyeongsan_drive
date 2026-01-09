import 'package:flutter/material.dart';
// 놀거리 탭
import 'fun/fun_page.dart'; 
import 'package:firebase_core/firebase_core.dart';
// 네이버 지도 SDK
import 'package:flutter_naver_map/flutter_naver_map.dart';


// 사용자 정보: cupertino_icons: ^1.0.8

// main 함수를 Future<void>로 변경하고 async를 추가합니다.
void main() async {
  // 1. Flutter 엔진이 위젯을 초기화할 때까지 대기합니다.
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // 2. Firebase를 초기화합니다.
  try {
    await Firebase.initializeApp(
      // options: DefaultFirebaseOptions.currentPlatform, // firebase_cli 사용 시
    );
    print('Firebase 초기화 성공');
  } catch (e) {
    print('Firebase 초기화 실패: $e');
  }

  // 3. 네이버 지도 SDK를 초기화합니다.
  try {
    await NaverMapSdk.instance.initialize(
      // clientId: 't14lkvxmuw', // ⚠️ 여기에 실제 Client ID를 입력하세요!
      onAuthFailed: (error) {
        print('네이버 지도 인증 실패: $error');
      },
    );
    print('네이버 지도 초기화 성공');
  } catch (e) {
    print('네이버 지도 초기화 실패: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigation App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // debug 배너 제거
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 현재 선택된 탭의 인덱스
  int _selectedIndex = 0;

  // 탭에 표시될 위젯 목록
  final List<Widget> _widgetOptions = <Widget>[
    const PlaceholderPage(title: '홈'),
    const PlaceholderPage(title: '길찾기'),
    const PlaceholderPage(title: '차량정보'),
    const PlaceholderPage(title: '지역정보'),
    const FunPage(), // '놀거리' 탭에 분리된 FunPage 위젯 사용
    const PlaceholderPage(title: '안전귀가'),
    const PlaceholderPage(title: '도로정보'),
  ];

  // 탭 변경 시 호출될 함수
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 글자 크기를 통일하기 위한 공통 스타일 정의
  final TextStyle _commonLabelStyle = const TextStyle(
    fontSize: 12.0, // 원하는 글자 크기 지정
    fontWeight: FontWeight.normal, // 선택 시 굵게 변하는 기본 동작 방지 (선택 사항)
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 현재 선택된 탭의 본문 표시
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),

      // 하단 탭 바 (BottomNavigationBar)
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue, 
        unselectedItemColor: Colors.grey,
        // 비활성화된 탭의 라벨 표시
        showUnselectedLabels: true, 
        showSelectedLabels: true,
        currentIndex: _selectedIndex, 
        
        // **수정된 부분: 선택된 탭과 미선택된 탭의 글꼴 스타일 통일**
        selectedLabelStyle: _commonLabelStyle.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: _commonLabelStyle,
        
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route_outlined),
            activeIcon: Icon(Icons.route),
            label: '길찾기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: '차량정보',
          ),
          BottomNavigationBarItem(
            // 지역정보 아이콘
            icon: Icon(Icons.public_outlined), 
            activeIcon: Icon(Icons.public),
            label: '지역정보',
          ),
          BottomNavigationBarItem(
            // 놀거리 아이콘
            icon: Icon(Icons.celebration_outlined), 
            activeIcon: Icon(Icons.celebration),
            label: '놀거리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security_outlined),
            activeIcon: Icon(Icons.security),
            label: '안전귀가',
          ),
          BottomNavigationBarItem(
            // 도로정보 아이콘 (신호등/교차로)
            icon: Icon(Icons.signpost_outlined), 
            activeIcon: Icon(Icons.signpost),
            label: '도로정보',
          ),
        ],
        // 탭 클릭 이벤트 처리
        onTap: _onItemTapped,
      ),
    );
  }
}

// 각 탭에 표시될 임시 페이지 위젯 (놀거리 탭 제외)
class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // 배경색을 흰색으로 통일하여 깔끔하게 유지
      child: Center(
        child: Text(
          '$title 페이지',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
      ),
    );
  }
}