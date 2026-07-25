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
    final normalizedEmail = email.trim();
    final normalizedLastFourDigits = lastFourDigits.trim();
    final response = await _client.post<Map<String, dynamic>>(
      AppConstants.newInterviewerVerifyEndpoint,
      data: {
        'email': normalizedEmail,
        'lastFourDigits': normalizedLastFourDigits,
      },
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Unable to verify your interviewer record.');
    }
    _verifyNewInterviewerPhone(data, normalizedLastFourDigits);

    return UserModel.fromJson({
      ...data,
      'userType': 'new',
      'email': data['email'] ?? normalizedEmail,
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

    final userData = await _fetchUserProfileOrFallback(
      token,
      normalizedUsername,
    );

    return UserModel.fromJson({
      ...userData,
      'username': userData['username'] ?? normalizedUsername,
      'sessionToken': token,
    });
  }

  Future<Map<String, dynamic>> _fetchUserProfileOrFallback(
    String token,
    String username,
  ) async {
    try {
      return await _fetchUserProfile(token, username);
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) {
        rethrow;
      }

      return _authenticatedUserFallback(username);
    }
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
    final userResponse = await _client.get<dynamic>(
      AppConstants.existingUserEndpoint,
      headers: _tokenHeaders(token),
    );
    final userData = _extractUserRecord(userResponse.data, username);
    if (userData != null) {
      return userData;
    }

    throw Exception(
      'User profile could not be retrieved. Please contact Helpdesk for assistance.',
    );
  }

  Map<String, String> _tokenHeaders(String token) => {
        'sm-authorize': token,
      };

  void _verifyNewInterviewerPhone(
    Map<String, dynamic> data,
    String expectedLastFourDigits,
  ) {
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    final mobile = user['mobile'] ??
        user['mobileNumber'] ??
        user['mobile_number'] ??
        user['phone'] ??
        user['phoneNumber'] ??
        user['phone_number'];

    if (mobile == null) {
      return;
    }

    final digitsOnly = mobile.toString().replaceAll(RegExp(r'\D'), '');
    if (!digitsOnly.endsWith(expectedLastFourDigits)) {
      throw Exception('The mobile digits did not match our records.');
    }
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

  Map<String, dynamic>? _extractUserRecord(dynamic data, String username) {
    if (data is Map<String, dynamic>) {
      final nestedUser = data['user'] ?? data['data'] ?? data['result'];
      if (nestedUser is Map<String, dynamic>) {
        return _withUsername(nestedUser, username);
      }
      if (nestedUser is List) {
        return _findMatchingUser(nestedUser, username);
      }

      final users = data['users'] ?? data['items'] ?? data['records'];
      final selectedUser = _findMatchingUser(users, username);
      if (selectedUser != null) {
        return selectedUser;
      }

      return _withUsername(data, username);
    }

    final selectedUser = _findMatchingUser(data, username);
    if (selectedUser != null) {
      return selectedUser;
    }

    return null;
  }

  Map<String, dynamic>? _findMatchingUser(dynamic users, String username) {
    if (users is! List) {
      return null;
    }

    final normalizedUsername = username.toLowerCase();
    for (final item in users.whereType<Map<String, dynamic>>()) {
      final itemUsername = (item['username'] ??
              item['userName'] ??
              item['login'] ??
              item['surveyor'] ??
              item['email'])
          ?.toString();
      if (itemUsername != null &&
          itemUsername.toLowerCase() == normalizedUsername) {
        return _withUsername(item, username);
      }
    }

    final firstWithComputer =
        users.whereType<Map<String, dynamic>>().firstWhere(
              (item) =>
                  item['computerNumber'] != null ||
                  item['computerName'] != null ||
                  item['computer'] != null,
              orElse: () => const {},
            );

    return firstWithComputer.isEmpty
        ? null
        : _withUsername(firstWithComputer, username);
  }

  Map<String, dynamic> _withUsername(
      Map<String, dynamic> user, String username) {
    return {
      ...user,
      'username': user['username'] ?? user['userName'] ?? username,
    };
  }

  Map<String, dynamic> _authenticatedUserFallback(String username) => {
        'id': username,
        'username': username,
        'displayName': username,
        'userType': 'existing',
      };
}
