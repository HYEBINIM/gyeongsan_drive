import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../models/location_model.dart';
import '../../services/location/location_service.dart';
import '../../services/permission/permission_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/common_app_bar.dart';

/// 도로정보 화면
/// 네이버 지도 + 현재 위치 마커 + 실시간 위치 추적만 제공합니다.
class RoadInfoScreen extends StatefulWidget {
  const RoadInfoScreen({super.key});

  @override
  State<RoadInfoScreen> createState() => _RoadInfoScreenState();
}

class _RoadInfoScreenState extends State<RoadInfoScreen> {
  final LocationService _locationService = LocationService();
  final PermissionService _permissionService = PermissionService();

  NaverMapController? _mapController;
  NLocationTrackingMode? _lastTrackingMode;
  LocationModel? _initialLocation;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final granted = await _permissionService.requestLocationPermission();
      if (!granted) {
        throw '위치 권한이 필요합니다. 설정에서 위치 권한을 허용해주세요.';
      }

      final lastKnownLocation = await _locationService.getLastKnownLocation();
      final currentLocation = await _locationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        _initialLocation = lastKnownLocation ?? currentLocation;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _syncTrackingMode(NLocationTrackingMode targetMode) {
    if (_mapController == null || _lastTrackingMode == targetMode) return;
    _mapController!.setLocationTrackingMode(targetMode);
    _lastTrackingMode = targetMode;
  }

  @override
  void dispose() {
    _syncTrackingMode(NLocationTrackingMode.none);
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: const CommonAppBar(title: '도로정보'),
        drawer: AppDrawer(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _initializeLocation,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final location = _initialLocation;
    if (location == null) {
      return Center(
        child: FilledButton(
          onPressed: _initializeLocation,
          child: const Text('현재 위치 불러오기'),
        ),
      );
    }

    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(location.latitude, location.longitude),
          zoom: AppConstants.mapDefaultZoom,
        ),
        indoorEnable: true,
      ),
      onMapReady: (controller) async {
        if (!mounted) return;

        _mapController = controller;
        _syncTrackingMode(NLocationTrackingMode.follow);

        final locationOverlay = controller.getLocationOverlay();
        locationOverlay.setPosition(
          NLatLng(location.latitude, location.longitude),
        );
      },
    );
  }
}
