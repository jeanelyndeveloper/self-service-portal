import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/device_entity.dart';
import '../../domain/usecases/validate_device.dart';
import '../../domain/usecases/execute_ireach_update.dart';
import 'device_state.dart';
import 'device_providers.dart';

class DeviceNotifier extends Notifier<DeviceState> {
  @override
  DeviceState build() => const DeviceState.initial();

  Future<bool> validateDevice(String deviceId) async {
    state = state.copyWith(isValidating: true, clearError: true);
    final result = await ref
        .read(validateDeviceProvider)
        .call(ValidateDeviceParams(deviceId));
    switch (result) {
      case Success(:final data):
        state = state.copyWith(isValidating: false, device: data);
        return true;
      case Err(:final failure):
        state = state.copyWith(isValidating: false, error: failure.message);
        return false;
    }
  }

  void confirmAssignedDevice(String deviceId) {
    state = state.copyWith(
      device: DeviceEntity(
        deviceId: deviceId,
        type: DeviceType.unknown,
      ),
      clearError: true,
    );
  }

  Future<bool> executeIReachUpdate(String deviceId) async {
    state = state.copyWith(isUpdating: true, clearError: true);
    final result = await ref
        .read(executeIReachUpdateProvider)
        .call(ExecuteIReachUpdateParams(deviceId));
    switch (result) {
      case Success(:final data):
        state = state.copyWith(
            isUpdating: false, updateStarted: true, updateMessage: data);
        return true;
      case Err(:final failure):
        state = state.copyWith(isUpdating: false, error: failure.message);
        return false;
    }
  }

  void reset() => state = const DeviceState.initial();
}

final deviceNotifierProvider =
    NotifierProvider<DeviceNotifier, DeviceState>(DeviceNotifier.new);
