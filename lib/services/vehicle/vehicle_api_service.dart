import '../../models/vehicle_data_model.dart';
import '../mcp/mcp_vehicle_client.dart';

/// 차량 실시간 데이터 API 서비스
class VehicleApiService {
  final McpVehicleClient _mcpClient;

  VehicleApiService({McpVehicleClient? mcpClient})
    : _mcpClient = mcpClient ?? McpVehicleClient();

  /// MT_ID로 실시간 차량 데이터 조회
  Future<VehicleData?> getRealTimeCarInfo({
    required String mtId,
    int interval = 10,
  }) async {
    try {
      final normalizedMtId = mtId.trim();
      if (normalizedMtId.isEmpty) {
        throw const FormatException('mt_id 값이 비어 있습니다.');
      }

      final normalizedInterval = interval.clamp(1, 60).toInt();
      final payload = await _mcpClient.callTool(
        'get_car_info',
        <String, dynamic>{
          'mt_id': normalizedMtId,
          'interval': normalizedInterval.toString(),
        },
      );

      final dataField = payload['data'];
      Map<String, dynamic>? targetData;

      if (dataField is List && dataField.isNotEmpty) {
        targetData = _asMap(dataField.first);
      } else if (dataField is Map) {
        targetData = _asMap(dataField);
      }

      targetData ??= _asMap(payload);

      if (targetData == null || targetData.isEmpty) {
        return null;
      }

      final vehicleResponse = VehicleDataResponse.fromJson({
        'data': [targetData],
      });

      if (vehicleResponse.data.isNotEmpty) {
        return vehicleResponse.data.first;
      }

      return null;
    } on McpVehicleClientException catch (e) {
      if (_isNetworkError(e.message)) {
        throw '네트워크 연결 오류: ${e.message}';
      }
      throw '차량 데이터 조회 실패: $e';
    } on FormatException catch (e) {
      throw '데이터 형식 오류: ${e.message}';
    } catch (e) {
      throw '차량 데이터 조회 실패: $e';
    }
  }

  bool _isNetworkError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('failed to establish sse connection') ||
        normalized.contains('socket') ||
        normalized.contains('connection') ||
        normalized.contains('timed out waiting for endpoint') ||
        normalized.contains('transport disconnected');
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic nestedValue) {
        return MapEntry(key.toString(), nestedValue);
      });
    }
    return null;
  }
}
