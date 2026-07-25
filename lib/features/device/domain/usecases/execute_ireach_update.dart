import '../repositories/device_repository.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/usecases/use_case.dart';

final class ExecuteIReachUpdateParams {
  final String deviceId;
  final String sessionToken;
  const ExecuteIReachUpdateParams(this.deviceId, this.sessionToken);
}

class ExecuteIReachUpdate
    implements UseCase<String, ExecuteIReachUpdateParams> {
  final DeviceRepository _repository;
  const ExecuteIReachUpdate(this._repository);

  @override
  Future<Result<String>> call(ExecuteIReachUpdateParams params) =>
      _repository.executeIReachUpdate(params.deviceId, params.sessionToken);
}
