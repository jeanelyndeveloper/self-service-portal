import '../entities/device_entity.dart';
import '../../../../core/errors/result.dart';

abstract interface class DeviceRepository {
  Future<Result<DeviceEntity>> validateDevice(String deviceId);
  Future<Result<String>> executeIReachUpdate(
      String deviceId, String sessionToken);
}
