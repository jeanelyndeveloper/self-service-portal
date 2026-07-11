import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_client.dart';
import '../models/device_model.dart';
import 'device_data_source.dart';

class DeviceRemoteDataSource implements DeviceDataSource {
  final NetworkClient _client;
  const DeviceRemoteDataSource(this._client);

  @override
  Future<DeviceModel> validateDevice(String deviceId) async {
    final normalizedDeviceId = deviceId.trim().toUpperCase();
    final response = await _client.get<Map<String, dynamic>>(
      '/devices/$normalizedDeviceId',
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Device could not be verified.');
    }

    return DeviceModel.fromJson({
      ...data,
      'deviceId': data['deviceId'] ?? normalizedDeviceId,
    });
  }

  @override
  Future<String> executeIReachUpdate(String deviceId) async {
    final response = await _client.post<Map<String, dynamic>>(
      AppConstants.iReachUpdateEndpoint,
      data: {
        'hostname': deviceId.trim().toUpperCase(),
      },
    );

    final data = response.data;
    final message = data?['message'] ?? data?['statusMessage'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    return 'I-Reach update started successfully on $deviceId';
  }
}
