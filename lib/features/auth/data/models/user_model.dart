import '../../domain/entities/user_entity.dart';

class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String userType;
  final String? deviceId;

  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.userType,
    this.deviceId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    final id = user['userId'] ?? user['id'] ?? user['username'];
    final username = user['username'] ?? user['userId'] ?? user['id'];
    final displayName = user['displayName'] ??
        user['name'] ??
        user['fullName'] ??
        user['full_name'] ??
        user['firstName'] ??
        username;

    if (id == null || username == null) {
      throw const FormatException(
          'Authentication response did not include user details.');
    }

    return UserModel(
      id: id as String,
      username: username as String,
      displayName: displayName as String,
      userType: user['userType'] as String? ?? 'existing',
      deviceId: (user['deviceId'] ??
          user['device_id'] ??
          user['assignedDeviceId'] ??
          user['assigned_device_id'] ??
          user['computerName'] ??
          user['computer_name'] ??
          user['computer']) as String?,
    );
  }

  UserEntity toEntity() => UserEntity(
        id: id,
        username: username,
        displayName: displayName,
        type: userType == 'new'
            ? UserType.newInterviewer
            : UserType.existingInterviewer,
        deviceId: deviceId,
      );
}
