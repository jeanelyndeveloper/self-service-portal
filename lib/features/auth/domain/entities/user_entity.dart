class UserEntity {
  final String id;
  final String username;
  final String displayName;
  final UserType type;
  final String? email;
  final String? deviceId;
  final String? deviceType;
  final String? devicePin;
  final String? project;
  final String? sessionToken;

  const UserEntity({
    required this.id,
    required this.username,
    required this.displayName,
    required this.type,
    this.email,
    this.deviceId,
    this.deviceType,
    this.devicePin,
    this.project,
    this.sessionToken,
  });
}

enum UserType { newInterviewer, existingInterviewer }
