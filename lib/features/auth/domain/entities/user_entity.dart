class UserEntity {
  final String id;
  final String username;
  final String displayName;
  final UserType type;
  final String? deviceId;

  const UserEntity({
    required this.id,
    required this.username,
    required this.displayName,
    required this.type,
    this.deviceId,
  });
}

enum UserType { newInterviewer, existingInterviewer }
