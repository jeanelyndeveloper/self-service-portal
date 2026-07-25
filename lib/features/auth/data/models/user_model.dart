import '../../domain/entities/user_entity.dart';

class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String userType;
  final String? email;
  final String? deviceId;
  final String? deviceType;
  final String? devicePin;
  final String? project;
  final String? sessionToken;

  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.userType,
    this.email,
    this.deviceId,
    this.deviceType,
    this.devicePin,
    this.project,
    this.sessionToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    final id =
        user['userId'] ?? user['id'] ?? user['username'] ?? user['surveyor'];
    final username =
        user['username'] ?? user['userId'] ?? user['id'] ?? user['surveyor'];
    final displayName = user['displayName'] ??
        user['name'] ??
        user['fullName'] ??
        user['full_name'] ??
        user['surveyorName'] ??
        user['firstName'] ??
        username;
    final assignedDevice = user['assignedDevice'] ??
        user['assigned_device'] ??
        user['device'] ??
        user['laptop'];
    final assignedDeviceMap =
        assignedDevice is Map<String, dynamic> ? assignedDevice : null;

    if (id == null || username == null) {
      throw const FormatException(
          'Authentication response did not include user details.');
    }

    return UserModel(
      id: id.toString(),
      username: username.toString(),
      displayName: displayName.toString(),
      userType: user['userType'] as String? ?? 'existing',
      email: _stringValue(
          user['email'] ?? user['emailAddress'] ?? user['email_address']),
      deviceId: _stringValue(user['deviceId'] ??
          user['device_id'] ??
          user['assignedDeviceId'] ??
          user['assigned_device_id'] ??
          assignedDeviceMap?['id'] ??
          assignedDeviceMap?['deviceId'] ??
          assignedDeviceMap?['computerName'] ??
          user['computerNumber'] ??
          user['computer_number'] ??
          user['computerName'] ??
          user['computer_name'] ??
          user['computer']),
      deviceType: _stringValue(user['deviceType'] ??
          user['device_type'] ??
          user['assignedDeviceType'] ??
          assignedDeviceMap?['type'] ??
          assignedDeviceMap?['deviceType']),
      devicePin: _stringValue(user['devicePin'] ??
          user['device_pin'] ??
          user['pin'] ??
          user['pinNumber'] ??
          user['pin_number'] ??
          assignedDeviceMap?['pin'] ??
          assignedDeviceMap?['devicePin']),
      project: _stringValue(user['project'] ??
          user['projectName'] ??
          user['project_name'] ??
          user['study']),
      sessionToken: _stringValue(user['sessionToken']),
    );
  }

  static String? _stringValue(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  UserEntity toEntity() => UserEntity(
        id: id,
        username: username,
        displayName: displayName,
        type: userType == 'new'
            ? UserType.newInterviewer
            : UserType.existingInterviewer,
        email: email,
        deviceId: deviceId,
        deviceType: deviceType,
        devicePin: devicePin,
        project: project,
        sessionToken: sessionToken,
      );
}
