abstract final class AppConstants {
  static const String baseUrl = String.fromEnvironment(
    'APP_API_BASE_URL',
    defaultValue: '/api',
  );
  static const String existingAuthEndpoint =
      '/existing-interviewer/authentication';
  static const String existingUserEndpoint = '/existing-interviewer/user';
  static const String newInterviewerVerifyEndpoint = '/new-interviewer/verify';
  static const String iReachUpdateEndpoint = '/ireach/update';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
