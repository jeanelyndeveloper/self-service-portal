import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_client.dart';
import '../models/device_model.dart';
import 'device_data_source.dart';

class DeviceRemoteDataSource implements DeviceDataSource {
  final NetworkClient _client;
  const DeviceRemoteDataSource(this._client);

  static const _statusPollDelay = Duration(seconds: 3);
  static const _statusPollAttempts = 100;

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
  Future<String> executeIReachUpdate(
      String deviceId, String sessionToken) async {
    final computerName = deviceId.trim().toUpperCase();
    late final Response<Map<String, dynamic>> response;
    try {
      response = await _client.post<Map<String, dynamic>>(
        AppConstants.iReachUpdateEndpoint,
        data: {
          'computerName': computerName,
        },
        headers: {
          'sm-authorize': sessionToken,
        },
      );
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = responseData is Map
          ? responseData['message'] ?? responseData['error']
          : null;
      final safeMessage = message?.toString().trim();
      if (safeMessage != null && safeMessage.isNotEmpty) {
        if (safeMessage.contains('RMM_')) {
          throw Exception(
            'The update service is not configured. Please contact the Help Desk.',
          );
        }
        throw Exception(safeMessage);
      }
      rethrow;
    }

    final data = response.data;
    final initialStatus = _extractStatus(data);
    if (initialStatus == 'success') {
      return _extractMessage(data) ??
          'I-Reach has been updated. You can now reopen it.';
    }
    if (initialStatus == 'failed') {
      throw Exception(_extractMessage(data) ??
          'The update could not be completed. Please contact the Help Desk.');
    }

    final executionId = _extractExecutionId(data);
    if (executionId == null) {
      return _extractMessage(data) ??
          'The update request was sent. Please contact the Help Desk if I-Reach does not update.';
    }

    return _pollUpdateStatus(executionId);
  }

  Future<String> _pollUpdateStatus(String executionId) async {
    for (var attempt = 0; attempt < _statusPollAttempts; attempt++) {
      await Future<void>.delayed(_statusPollDelay);

      final response = await _client.get<Map<String, dynamic>>(
        '${AppConstants.iReachUpdateStatusEndpoint}/$executionId',
      );
      final data = response.data;
      final status = _extractStatus(data);

      if (status == 'success') {
        return _extractMessage(data) ??
            'I-Reach has been updated. You can now reopen it.';
      }
      if (status == 'failed') {
        throw Exception(_extractMessage(data) ??
            'The update could not be completed. Please contact the Help Desk.');
      }
    }

    throw Exception(
      'The update is taking longer than expected. Please contact the Help Desk.',
    );
  }

  String? _extractExecutionId(Map<String, dynamic>? data) {
    final value = data?['executionId'] ??
        data?['execution_id'] ??
        data?['id'] ??
        data?['jobId'] ??
        data?['job_id'];
    return value?.toString();
  }

  String? _extractStatus(Map<String, dynamic>? data) {
    final value = data?['status'] ?? data?['state'] ?? data?['result'];
    return value?.toString().trim().toLowerCase();
  }

  String? _extractMessage(Map<String, dynamic>? data) {
    final value = data?['message'] ?? data?['statusMessage'] ?? data?['error'];
    final message = value?.toString().trim();
    return message == null || message.isEmpty ? null : message;
  }
}
