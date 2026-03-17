// lib/fun/navigation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

/// 실시간 내비게이션 화면
class NavigationScreen extends StatefulWidget {
  final String destinationName;
  final double destinationLat;
  final double destinationLng;

  const NavigationScreen({
    super.key,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  NaverMapController? _mapController;
  
  // 디자인 상수
  static const Color _primaryColor = Color(0xFF00C853);
  static const Color _accentColor = Color(0xFFFF5252);
  static const Color _textPrimaryColor = Color(0xFF212121);
  
  // 네비게이션 데이터
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  String? _routeDistance;
  String? _routeDuration;
  int? _remainingDistance; // 미터
  int? _remainingDuration; // 초
  List<NLatLng> _routeCoords = [];
  NPathOverlay? _routePath;
  NMarker? _currentLocationMarker;
  NMarker? _destinationMarker;
  
  bool _isLoading = true;
  String? _errorMessage;

  // 네이버 클라우드 API 키
  static const String _naverClientId = 't14lkvxmuw';
  static const String _naverClientSecret = 'niNPCTn2zud0jHMwfLpNVvDarGdmxlEGjyjqLIGM';

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  /// 내비게이션 초기화
  Future<void> _initializeNavigation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. 현재 위치 가져오기
      final position = await _getCurrentPosition();
      if (position == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '현재 위치를 가져올 수 없습니다.';
        });
        return;
      }

      setState(() {
        _currentPosition = position;
      });

      // 2. 경로 가져오기
      await _fetchRoute(position);

      // 3. 실시간 위치 추적 시작
      _startLocationTracking();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('초기화 오류: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '내비게이션을 시작할 수 없습니다.';
      });
    }
  }

  /// 현재 위치 가져오기
  Future<Position?> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('위치 서비스가 비활성화되어 있습니다.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('위치 권한이 거부되었습니다.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('위치 권한이 영구적으로 거부되었습니다.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('위치 가져오기 오류: $e');
      return null;
    }
  }

  /// 네이버 Directions 15 API로 경로 가져오기
  Future<void> _fetchRoute(Position startPosition) async {
    try {
      print('=== Directions 15 API 경로 요청 시작 ===');
      print('출발지: ${startPosition.latitude}, ${startPosition.longitude}');
      print('목적지: ${widget.destinationLat}, ${widget.destinationLng}');
      
      // ✅ 올바른 도메인: maps.apigw.ntruss.com
      final url = Uri.parse(
        'https://maps.apigw.ntruss.com/map-direction-15/v1/driving?'
        'start=${startPosition.longitude},${startPosition.latitude}&'
        'goal=${widget.destinationLng},${widget.destinationLat}&'
        'option=trafast'
      );

      print('요청 URL: $url');

      final response = await http.get(
        url,
        headers: {
          'x-ncp-apigw-api-key-id': _naverClientId,
          'x-ncp-apigw-api-key': _naverClientSecret,
        },
      );

      print('응답 상태 코드: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('응답 코드: ${data['code']}');
        print('응답 메시지: ${data['message']}');
        
        if (data['code'] == 0 && data['route'] != null) {
          print('✅ 경로 데이터 수신 성공');
          _parseRouteData(data);
        } else {
          // API 응답 코드별 처리
          String errorMsg = '';
          switch (data['code']) {
            case 1:
              errorMsg = '출발지와 도착지가 동일합니다.';
              break;
            case 2:
              errorMsg = '출발지 또는 도착지가 도로 주변이 아닙니다.';
              break;
            case 3:
              errorMsg = '자동차 길찾기 결과를 제공할 수 없습니다.';
              break;
            case 4:
              errorMsg = '경유지가 도로 주변이 아닙니다.';
              break;
            case 5:
              errorMsg = '경로가 너무 멉니다 (1500km 이상).';
              break;
            default:
              errorMsg = data['message'] ?? '경로를 찾을 수 없습니다.';
          }
          print('❌ API 오류: $errorMsg');
          _showErrorSnackBar('$errorMsg 직선 경로를 표시합니다.');
          _useStraightRoute(startPosition);
        }
      } else if (response.statusCode == 401) {
        print('❌ 인증 오류 (401): API 키를 확인하세요');
        print('응답 본문: ${response.body}');
        _showErrorSnackBar('API 인증 오류입니다. 직선 경로를 표시합니다.');
        _useStraightRoute(startPosition);
      } else if (response.statusCode == 403) {
        print('❌ 권한 오류 (403): API 사용 권한을 확인하세요');
        print('응답 본문: ${response.body}');
        _showErrorSnackBar('API 권한 오류입니다. 직선 경로를 표시합니다.');
        _useStraightRoute(startPosition);
      } else {
        print('❌ HTTP 오류: ${response.statusCode}');
        print('응답 본문: ${response.body}');
        _showErrorSnackBar('경로 조회 실패. 직선 경로를 표시합니다.');
        _useStraightRoute(startPosition);
      }
    } catch (e, stackTrace) {
      print('❌ 경로 요청 예외: $e');
      print('스택 트레이스: $stackTrace');
      _showErrorSnackBar('네트워크 오류. 직선 경로를 표시합니다.');
      _useStraightRoute(startPosition);
    }
  }

  /// 경로 데이터 파싱 (Directions 15 API 응답 구조)
  void _parseRouteData(Map<String, dynamic> data) {
    try {
      print('=== 경로 파싱 시작 ===');
      
      if (data['route'] == null) {
        print('❌ route 데이터가 없습니다');
        if (_currentPosition != null) {
          _useStraightRoute(_currentPosition!);
        }
        return;
      }

      // trafast, traoptimal, tracomfort 중 사용 가능한 경로 찾기
      Map<String, dynamic>? routeOption;
      if (data['route']['trafast'] != null && 
          (data['route']['trafast'] as List).isNotEmpty) {
        routeOption = data['route']['trafast'][0];
        print('✅ trafast 경로 사용');
      } else if (data['route']['traoptimal'] != null && 
                 (data['route']['traoptimal'] as List).isNotEmpty) {
        routeOption = data['route']['traoptimal'][0];
        print('✅ traoptimal 경로 사용');
      } else if (data['route']['tracomfort'] != null && 
                 (data['route']['tracomfort'] as List).isNotEmpty) {
        routeOption = data['route']['tracomfort'][0];
        print('✅ tracomfort 경로 사용');
      }

      if (routeOption == null) {
        print('❌ 경로 옵션 데이터가 없습니다');
        if (_currentPosition != null) {
          _useStraightRoute(_currentPosition!);
        }
        return;
      }

      final summary = routeOption['summary'];

      // 거리와 시간
      final distance = summary['distance'] as int; // 미터
      final duration = summary['duration'] as int; // 밀리초

      print('총 거리: ${distance}m (${_formatDistance(distance)})');
      print('예상 시간: ${duration}ms (${_formatDuration(duration ~/ 1000)})');

      setState(() {
        _routeDistance = _formatDistance(distance);
        _routeDuration = _formatDuration(duration ~/ 1000);
        _remainingDistance = distance;
        _remainingDuration = duration ~/ 1000;
      });

      // 경로 좌표 추출 (Directions 15는 path 필드에 [경도, 위도] 배열로 제공)
      final List<NLatLng> coords = [];
      
      if (routeOption['path'] != null) {
        print('✅ path 데이터 발견');
        final pathList = routeOption['path'] as List;
        print('path 좌표 개수: ${pathList.length}');
        
        for (var coord in pathList) {
          if (coord is List && coord.length >= 2) {
            final lng = (coord[0] as num).toDouble();
            final lat = (coord[1] as num).toDouble();
            coords.add(NLatLng(lat, lng));
          }
        }
      }

      print('추출된 좌표 개수: ${coords.length}');

      if (coords.isEmpty) {
        print('❌ 좌표 추출 실패');
        if (_currentPosition != null) {
          _useStraightRoute(_currentPosition!);
        }
        return;
      }

      setState(() {
        _routeCoords = coords;
      });

      print('✅ 경로 파싱 완료 - 실제 도로 경로 ${coords.length}개 좌표 사용');
      _drawRouteOnMap();
    } catch (e, stackTrace) {
      print('❌ 경로 파싱 오류: $e');
      print('스택 트레이스: $stackTrace');
      if (_currentPosition != null) {
        _useStraightRoute(_currentPosition!);
      }
    }
  }

  /// 직선 경로 사용 (API 실패 시)
  void _useStraightRoute(Position startPosition) {
    print('=== 직선 경로 사용 ===');
    
    final distance = Geolocator.distanceBetween(
      startPosition.latitude,
      startPosition.longitude,
      widget.destinationLat,
      widget.destinationLng,
    ).round();

    print('직선 거리: ${distance}m');

    setState(() {
      _routeDistance = _formatDistance(distance);
      _routeDuration = '직선거리';
      _remainingDistance = distance;
      _routeCoords = [
        NLatLng(startPosition.latitude, startPosition.longitude),
        NLatLng(widget.destinationLat, widget.destinationLng),
      ];
    });

    _drawRouteOnMap();
  }

  /// 지도에 경로 그리기
  Future<void> _drawRouteOnMap() async {
    if (_mapController == null || _routeCoords.isEmpty) {
      print('❌ 지도 컨트롤러 또는 경로 좌표 없음');
      return;
    }

    try {
      print('=== 경로 그리기 시작 ===');
      print('경로 좌표 개수: ${_routeCoords.length}');
      
      // 기존 경로 제거
      if (_routePath != null) {
        await _mapController!.deleteOverlay(_routePath!.info);
      }

      // 새 경로 그리기
      _routePath = NPathOverlay(
        id: 'route_path',
        coords: _routeCoords,
        width: 10,
        color: _primaryColor,
        outlineColor: Colors.white,
        outlineWidth: 2,
      );
      await _mapController!.addOverlay(_routePath!);
      print('✅ 경로 오버레이 추가 완료');

      // 현재 위치 마커
      if (_currentPosition != null) {
        if (_currentLocationMarker != null) {
          await _mapController!.deleteOverlay(_currentLocationMarker!.info);
        }

        _currentLocationMarker = NMarker(
          id: 'current_location',
          position: NLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        );
        await _mapController!.addOverlay(_currentLocationMarker!);
        print('✅ 현재 위치 마커 추가 완료');
      }

      // 목적지 마커
      if (_destinationMarker == null) {
        _destinationMarker = NMarker(
          id: 'destination',
          position: NLatLng(widget.destinationLat, widget.destinationLng),
        );
        
        final infoWindow = NInfoWindow.onMarker(
          id: _destinationMarker!.info.id,
          text: widget.destinationName,
        );
        
        await _mapController!.addOverlay(_destinationMarker!);
        _destinationMarker!.openInfoWindow(infoWindow);
        print('✅ 목적지 마커 추가 완료');
      }

      // 카메라를 경로에 맞추기
      _fitCameraToRoute();
    } catch (e, stackTrace) {
      print('❌ 경로 그리기 오류: $e');
      print('스택 트레이스: $stackTrace');
    }
  }

  /// 카메라를 경로에 맞추기
  Future<void> _fitCameraToRoute() async {
    if (_mapController == null || _currentPosition == null) return;

    try {
      final bounds = NLatLngBounds(
        southWest: NLatLng(
          _currentPosition!.latitude < widget.destinationLat
              ? _currentPosition!.latitude
              : widget.destinationLat,
          _currentPosition!.longitude < widget.destinationLng
              ? _currentPosition!.longitude
              : widget.destinationLng,
        ),
        northEast: NLatLng(
          _currentPosition!.latitude > widget.destinationLat
              ? _currentPosition!.latitude
              : widget.destinationLat,
          _currentPosition!.longitude > widget.destinationLng
              ? _currentPosition!.longitude
              : widget.destinationLng,
        ),
      );

      final cameraUpdate = NCameraUpdate.fitBounds(
        bounds,
        padding: const EdgeInsets.all(100),
      );
      await _mapController!.updateCamera(cameraUpdate);
      print('✅ 카메라 조정 완료');
    } catch (e) {
      print('❌ 카메라 조정 오류: $e');
    }
  }

  /// 실시간 위치 추적 시작
  void _startLocationTracking() {
    print('=== 위치 추적 시작 ===');
    
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10미터마다 업데이트
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateCurrentLocation(position);
    });
  }

  /// 현재 위치 업데이트
  Future<void> _updateCurrentLocation(Position position) async {
    setState(() {
      _currentPosition = position;
    });

    // 남은 거리 계산
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.destinationLat,
      widget.destinationLng,
    ).round();

    setState(() {
      _remainingDistance = distance;
    });

    // 현재 위치 마커 업데이트
    if (_mapController != null && _currentLocationMarker != null) {
      _currentLocationMarker!.setPosition(
        NLatLng(position.latitude, position.longitude),
      );

      // 카메라를 현재 위치로 부드럽게 이동
      try {
        final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(position.latitude, position.longitude),
        );
        await _mapController!.updateCamera(cameraUpdate);
      } catch (e) {
        print('카메라 업데이트 오류: $e');
      }
    }

    // 목적지 도착 확인 (50m 이내)
    if (distance < 50) {
      _showArrivalDialog();
    }
  }

  /// 도착 다이얼로그 표시
  void _showArrivalDialog() {
    _positionStream?.cancel();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          '목적지 도착',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '${widget.destinationName}에 도착했습니다!',
          style: const TextStyle(
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
              Navigator.pop(context); // 내비게이션 화면 닫기
            },
            child: const Text(
              '확인',
              style: TextStyle(
                color: _primaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 거리 포맷
  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '${meters}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// 시간 포맷
  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}초';
    } else if (seconds < 3600) {
      return '${(seconds / 60).round()}분';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}시간 ${minutes}분';
    }
  }

  /// 에러 스낵바 표시
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: _accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
              SizedBox(height: 16),
              Text(
                '경로를 찾고 있습니다...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _textPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _textPrimaryColor,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: _accentColor,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: _textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeNavigation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '다시 시도',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 네이버 지도
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: _currentPosition != null
                  ? NCameraPosition(
                      target: NLatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 15,
                      bearing: 0,
                      tilt: 0,
                    )
                  : NCameraPosition(
                      target: NLatLng(
                        widget.destinationLat,
                        widget.destinationLng,
                      ),
                      zoom: 15,
                      bearing: 0,
                      tilt: 0,
                    ),
              mapType: NMapType.navi,
              activeLayerGroups: [NLayerGroup.building, NLayerGroup.transit],
              locale: const Locale('ko'),
            ),
            onMapReady: (controller) async {
              _mapController = controller;
              print('✅ 지도 준비 완료');
              await _drawRouteOnMap();
            },
          ),

          // 상단 정보 카드
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  // 목적지 정보
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.destinationName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.directions_car,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_remainingDistance != null ? _formatDistance(_remainingDistance!) : _routeDistance ?? '계산중'}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${_remainingDuration != null ? _formatDuration(_remainingDuration!) : _routeDuration ?? ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 현재 위치 버튼
          Positioned(
            bottom: 60,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  onTap: () async {
                    if (_mapController != null && _currentPosition != null) {
                      try {
                        final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
                          target: NLatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          zoom: 16,
                        );
                        await _mapController!.updateCamera(cameraUpdate);
                      } catch (e) {
                        print('카메라 이동 오류: $e');
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 56,
                    height: 56,
                    child: const Center(
                      child: Icon(
                        Icons.my_location,
                        color: _primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}