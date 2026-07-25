import '../models/device_model.dart';

abstract interface class DeviceDataSource {
  Future<DeviceModel> validateDevice(String deviceId);
  Future<String> executeIReachUpdate(String deviceId, String sessionToken);
}
