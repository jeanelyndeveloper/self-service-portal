abstract final class AppConstants {
  static const String baseUrl = String.fromEnvironment(
    'APP_API_BASE_URL',
    defaultValue: 'http://localhost:8787',
  );

  // Existing interviewers authenticate against the SMS API:
  // https://smstg.ipsos.co.nz/api/v1/Authentication
  // Existing interviewer profile lookup also uses the SMS API with
  // the returned token in the sm-authorize header:
  // https://smstg.ipsos.co.nz/api/v1/Users
  static const String existingAuthEndpoint = '/api/v1/Authentication';
  static const String existingUserEndpoint = '/api/v1/Users';

  // New interviewer verification is handled by the server-side proxy, which
  // authenticates to the BO API without exposing BO credentials to Flutter Web.
  static const String newInterviewerVerifyEndpoint = '/new-interviewer/verify';
  static const String iReachUpdateEndpoint = String.fromEnvironment(
    'IREACH_UPDATE_ENDPOINT',
    defaultValue: '/update-ireach',
  );
  static const String iReachUpdateStatusEndpoint = String.fromEnvironment(
    'IREACH_UPDATE_STATUS_ENDPOINT',
    defaultValue: '/update-ireach/status',
  );
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
