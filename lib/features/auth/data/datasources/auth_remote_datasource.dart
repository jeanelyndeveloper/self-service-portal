import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_client.dart';
import '../models/user_model.dart';
import 'auth_data_source.dart';

class AuthRemoteDataSource implements AuthDataSource {
  final NetworkClient _client;
  const AuthRemoteDataSource(this._client);

  @override
  Future<UserModel> authenticateNewInterviewer(
      String email, String lastFourDigits) async {
    final response = await _client.post<Map<String, dynamic>>(
      AppConstants.newInterviewerVerifyEndpoint,
      data: {
        'email': email.trim(),
        'lastFourDigits': lastFourDigits.trim(),
      },
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Unable to verify your interviewer record.');
    }

    return UserModel.fromJson({
      ...data,
      'userType': 'new',
    });
  }

  @override
  Future<UserModel> authenticateExistingInterviewer(
      String username, String password) async {
    final normalizedUsername = username.trim();
    final authResponse = await _postExistingInterviewerCredentials(
      normalizedUsername,
      password,
    );

    final authData = authResponse.data;
    if (authData == null) {
      throw Exception('Authentication response was empty. Please try again.');
    }

    final token = _extractToken(authData);
    if (token == null || token.isEmpty) {
      throw Exception('Authentication response did not include a token.');
    }

    final userData = await _fetchUserProfile(token, normalizedUsername);

    return UserModel.fromJson({
      ...userData,
      'username': userData['username'] ?? normalizedUsername,
    });
  }

  Future<Response<Map<String, dynamic>>> _postExistingInterviewerCredentials(
    String username,
    String password,
  ) async {
    return _client.post<Map<String, dynamic>>(
      AppConstants.existingAuthEndpoint,
      data: {
        'username': username,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> _fetchUserProfile(
    String token,
    String username,
  ) async {
    const userPaths = [
      AppConstants.existingUserEndpoint,
    ];

    for (final path in userPaths) {
      try {
        final userResponse = await _client.get<Map<String, dynamic>>(
          path,
          headers: {'X-Session-Token': token},
        );
        final userData = userResponse.data;
        if (userData != null) {
          return userData;
        }
      } on Exception {
        // Try the next likely casing while the exact staging user path settles.
      }
    }

    throw Exception(
      'User profile could not be retrieved. Please contact Helpdesk for assistance.',
    );
  }

  String? _extractToken(Map<String, dynamic> data) {
    final token = data['token'] ??
        data['session'] ??
        data['accessToken'] ??
        data['access_token'] ??
        data['authToken'];
    if (token is String) {
      return token;
    }

    final nested = data['authentication'] ?? data['data'];
    if (nested is Map<String, dynamic>) {
      return _extractToken(nested);
    }

    return null;
  }
}
