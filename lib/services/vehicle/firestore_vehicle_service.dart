import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../models/vehicle_info_model.dart';

/// Firestore에서 사용자의 차량 정보를 관리하는 서비스
/// RTDB에서 마이그레이션됨
class FirestoreVehicleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'eastapp-dev',
  );

  /// 사용자의 활성화된 차량 정보 조회
  ///
  /// [userId] 사용자 ID
  /// [forceServer] true면 로컬 캐시를 무시하고 서버에서 최신 데이터를 가져옴
  Future<VehicleInfo?> getUserActiveVehicle(
    String userId, {
    bool forceServer = false,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get(
            forceServer
                ? const GetOptions(source: Source.server)
                : const GetOptions(),
          );

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final vehicle = VehicleInfo.fromJson(doc.id, doc.data());
        return vehicle;
      }

      return null;
    } catch (e) {
      throw '차량 정보 조회 실패: $e';
    }
  }

  /// 사용자의 모든 차량 목록 조회
  ///
  /// [forceServer]가 true인 경우 로컬 캐시를 무시하고 서버에서 최신 데이터를 가져옵니다.
  Future<List<VehicleInfo>> getUserVehicles(
    String userId, {
    bool forceServer = false,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .get(
            forceServer
                ? const GetOptions(source: Source.server)
                : const GetOptions(),
          );

      return snapshot.docs.map((doc) {
        return VehicleInfo.fromJson(doc.id, doc.data());
      }).toList();
    } catch (e) {
      throw '차량 목록 조회 실패: $e';
    }
  }

  /// 차량번호로 MT_ID 조회 (vehicleMappings에서)
  Future<Map<String, dynamic>?> getVehicleMappingByNumber(
    String vehicleNumber,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('vehicleMappings')
          .doc(vehicleNumber)
          .get();

      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    } catch (e) {
      throw '차량 매핑 조회 실패: $e';
    }
  }

  /// 한국어 주석: 전체 차량번호(예: 경북16바3597)로 단일 차량 조회
  /// 데이터베이스 구조상 문서 ID가 차량번호이므로 doc(vehicleNumber)로 바로 조회
  Future<Map<String, dynamic>?> getVehicleByFullNumber(
    String vehicleNumber,
  ) async {
    try {
      final doc = await _firestore.collection('cars').doc(vehicleNumber).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      if (data == null) {
        return null;
      }

      final regNo = (data['regNo'] as String?) ?? doc.id;
      return _buildVehicleInfoMap(regNo, data);
    } catch (e) {
      throw '차량 검색 실패: $e';
    }
  }

  /// 부분 차량번호로 첫 번째 차량 정보 검색 (cars 컬렉션에서)
  ///
  /// 한국어 주석: 기존 단일 결과 버전 (하위 호환용)
  Future<Map<String, dynamic>?> searchVehicleByPartialNumber(
    String partialNumber,
  ) async {
    final results = await searchVehiclesByPartialNumber(partialNumber);
    if (results.isEmpty) {
      return null;
    }
    return results.first;
  }

  /// 부분 차량번호로 차량 정보 목록 검색 (cars 컬렉션에서)
  /// 예: "3597" 입력 → "경북16바3597" 등 여러 대 매칭 가능
  ///
  /// last4 필드(차량번호 뒷 4자리)에 대한 인덱스 쿼리만 사용합니다.
  /// 최적화: 캐시 우선 조회로 반복 검색 시 성능 향상
  Future<List<Map<String, dynamic>>> searchVehiclesByPartialNumber(
    String partialNumber,
  ) async {
    try {
      final trimmed = partialNumber.trim();
      final isFourDigits = RegExp(r'^\d{4}$').hasMatch(trimmed);

      // 한국어 주석: 방어적 코드 - 4자리 숫자가 아니면 바로 빈 리스트 반환
      if (!isFourDigits) {
        return <Map<String, dynamic>>[];
      }

      // 최적화: 먼저 로컬 캐시에서 조회 시도
      QuerySnapshot<Map<String, dynamic>> last4Snapshot;
      try {
        last4Snapshot = await _firestore
            .collection('cars')
            .where('last4', isEqualTo: trimmed)
            .get(const GetOptions(source: Source.cache));

        // 캐시에 데이터가 있으면 바로 반환
        if (last4Snapshot.docs.isNotEmpty) {
          return last4Snapshot.docs.map((doc) {
            final data = doc.data();
            final regNo = (data['regNo'] as String?) ?? doc.id;
            return _buildVehicleInfoMap(regNo, data);
          }).toList();
        }
      } catch (_) {
        // 캐시 조회 실패 시 서버 조회로 진행
      }

      // 캐시에 없으면 서버에서 조회
      last4Snapshot = await _firestore
          .collection('cars')
          .where('last4', isEqualTo: trimmed)
          .get(const GetOptions(source: Source.server));

      return last4Snapshot.docs.map((doc) {
        final data = doc.data();
        final regNo = (data['regNo'] as String?) ?? doc.id;
        return _buildVehicleInfoMap(regNo, data);
      }).toList();
    } catch (e) {
      throw '차량 검색 실패: $e';
    }
  }

  /// 차량번호에서 지역명 추출 (예: "경북16바3597" → "경북")
  String _extractRegion(String vehicleNumber) {
    final koreanRegex = RegExp(r'^[가-힣]+');
    final match = koreanRegex.firstMatch(vehicleNumber);
    return match?.group(0) ?? '';
  }

  /// 연료타입 문자열에서 순수 타입명 추출 (예: "전기[FU04]" → "전기")
  String _extractFuelType(String fuelName) {
    final bracketIndex = fuelName.indexOf('[');
    if (bracketIndex > 0) {
      return fuelName.substring(0, bracketIndex);
    }
    return fuelName;
  }

  /// 제조사 문자열에서 순수 제조사명 추출 (예: "현대[HYU]" → "현대")
  String _extractManufacturer(String manufacturerName) {
    final bracketIndex = manufacturerName.indexOf('[');
    if (bracketIndex > 0) {
      return manufacturerName.substring(0, bracketIndex);
    }
    return manufacturerName;
  }

  /// 한국어 주석: cars 컬렉션의 원시 데이터에서 화면/로직에서 사용하는 차량 정보 맵 생성
  Map<String, dynamic> _buildVehicleInfoMap(
    String regNo,
    Map<String, dynamic> data,
  ) {
    return {
      'vehicleNumber': regNo,
      'region': _extractRegion(regNo),
      'modelName': data['modelName'] as String? ?? '',
      'manufacturer': _extractManufacturer(
        data['manufacturerKor'] as String? ?? '',
      ),
      'fuelType': _extractFuelType(data['fuelName'] as String? ?? ''),
      'mtId': data['mtId'] as String? ?? '',
      'vehicleType': data['vehicleType'] as String? ?? '',
    };
  }

  /// 사용자가 이미 동일한 차량번호를 등록했는지 확인
  ///
  /// [userId] 사용자 ID
  /// [vehicleNumber] 확인할 차량번호 (예: "경북16바3597")
  ///
  /// 반환: 이미 등록된 경우 true, 아니면 false
  Future<bool> isDuplicateVehicle(String userId, String vehicleNumber) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .where('vehicleNumber', isEqualTo: vehicleNumber)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw '중복 차량 확인 실패: $e';
    }
  }

  /// 사용자 차량 등록
  Future<String> registerUserVehicle(
    String userId,
    VehicleInfo vehicleInfo,
  ) async {
    try {
      // 중복 등록 검사
      final isDuplicate = await isDuplicateVehicle(
        userId,
        vehicleInfo.vehicleNumber,
      );
      if (isDuplicate) {
        throw '이미 등록된 차량입니다';
      }

      // 새 차량 등록 시 기존 활성 차량 비활성화
      // 최적화: 모든 차량 조회 대신 활성 차량만 직접 쿼리
      final activeVehiclesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .where('isActive', isEqualTo: true)
          .get();

      // Firestore Batch를 사용한 일괄 업데이트
      final batch = _firestore.batch();

      // 활성 차량 비활성화
      for (var doc in activeVehiclesSnapshot.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      // 새 차량 등록 (자동 ID 생성)
      final newVehicleRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .doc(); // 자동 ID 생성

      batch.set(newVehicleRef, vehicleInfo.toJson());

      // 일괄 커밋
      await batch.commit();

      return newVehicleRef.id;
    } catch (e) {
      throw '차량 등록 실패: $e';
    }
  }

  /// 활성 차량 변경
  Future<void> setActiveVehicle(String userId, String vehicleId) async {
    try {
      // 최적화: 활성 차량만 쿼리하여 비활성화
      final activeVehiclesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .where('isActive', isEqualTo: true)
          .get();

      // Firestore Batch를 사용한 일괄 업데이트
      final batch = _firestore.batch();

      // 기존 활성 차량 비활성화
      for (var doc in activeVehiclesSnapshot.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      // 새로 선택된 차량 활성화
      final newActiveVehicleRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .doc(vehicleId);

      batch.update(newActiveVehicleRef, {'isActive': true});

      await batch.commit();
    } catch (e) {
      throw '차량 활성화 실패: $e';
    }
  }

  /// 차량 정보 부분 업데이트
  Future<void> updateVehicleFields(
    String userId,
    String vehicleId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .doc(vehicleId)
          .update(updates);
    } catch (e) {
      throw '차량 정보 업데이트 실패: $e';
    }
  }

  /// 차량 삭제
  Future<void> deleteVehicle(String userId, String vehicleId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .doc(vehicleId)
          .delete();
    } catch (e) {
      throw '차량 삭제 실패: $e';
    }
  }
}
