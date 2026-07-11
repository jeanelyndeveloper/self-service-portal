import '../../domain/entities/device_entity.dart';
import '../../domain/repositories/device_repository.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../datasources/device_data_source.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  final DeviceDataSource _dataSource;
  const DeviceRepositoryImpl(this._dataSource);

  @override
  Future<Result<DeviceEntity>> validateDevice(String deviceId) async {
    if (deviceId.length < 5) {
      return const Err(
          DeviceFailure('Device ID must be at least 5 characters'));
    }
    try {
      final model = await _dataSource.validateDevice(deviceId);
      return Success(model.toEntity());
    } on Exception catch (e) {
      return Err(DeviceFailure(_extractMessage(e)));
    }
  }

  @override
  Future<Result<String>> executeIReachUpdate(String deviceId) async {
    try {
      final message = await _dataSource.executeIReachUpdate(deviceId);
      return Success(message);
    } on Exception catch (e) {
      return Err(DeviceFailure(_extractMessage(e)));
    }
  }

  String _extractMessage(Exception e) =>
      switch (e.toString().replaceFirst('Exception: ', '')) {
        final message
            when message.contains('Device ID must') ||
                message.contains('Device could not') =>
          message,
        _ =>
          'We could not complete the device request. Please contact Helpdesk for assistance.',
      };
}
