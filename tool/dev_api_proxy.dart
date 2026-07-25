import 'dart:convert';
import 'dart:io';

const _defaultTarget = 'https://smstg.ipsos.co.nz';
const _defaultBoApiBaseUrl = 'https://boapistg.ipsos.co.nz';
const _defaultPort = 8787;
const _boSessionTtl = Duration(minutes: 25);

String? _boSessionToken;
DateTime? _boSessionTokenCreatedAt;
final Map<String, String> _smsSessionUsers = {};
final Map<String, String> _smsSessionComputers = {};
final Map<String, String> _runtimeEnvironment = {...Platform.environment};

Future<void> main(List<String> args) async {
  _loadLocalEnvironment();
  final target = Uri.parse(
    _argValue(args, '--target') ??
        _runtimeEnvironment['DEV_API_PROXY_TARGET'] ??
        _defaultTarget,
  );
  final port = int.parse(
    _argValue(args, '--port') ??
        _runtimeEnvironment['DEV_API_PROXY_PORT'] ??
        '$_defaultPort',
  );

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Proxying http://localhost:$port -> $target');
  final rmmConfigured = const [
    'RMM_API_BASE_URL',
    'RMM_SYSTEM_TOKEN',
    'RMM_IREACH_SCRIPT_ID',
  ].every((key) => _runtimeEnvironment[key]?.trim().isNotEmpty == true);
  stdout.writeln(
    'I-Reach update service: ${rmmConfigured ? 'configured' : 'not configured'}',
  );

  await for (final request in server) {
    await _handleRequest(request, target);
  }
}

Future<void> _handleRequest(HttpRequest request, Uri target) async {
  _setCorsHeaders(request.response, request);

  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  if (request.uri.path == '/new-interviewer/verify') {
    await _handleNewInterviewerVerification(request);
    return;
  }

  if (request.uri.path == '/api/v1/Authentication') {
    await _handleExistingInterviewerAuthentication(request, target);
    return;
  }

  if (request.uri.path == '/api/v1/Users') {
    await _handleExistingInterviewerProfile(request, target);
    return;
  }

  if (request.uri.path == '/update-ireach') {
    await _handleIReachUpdate(request);
    return;
  }

  if (request.uri.path.startsWith('/update-ireach/status/')) {
    await _handleIReachUpdateStatus(request);
    return;
  }

  final targetUri = target.replace(
    path: _joinPaths(target.path, request.uri.path),
    query: request.uri.query,
  );

  final client = HttpClient();
  try {
    final proxyRequest = await client.openUrl(request.method, targetUri);
    _copyRequestHeaders(request, proxyRequest);
    await proxyRequest.addStream(request);

    final proxyResponse = await proxyRequest.close();
    request.response.statusCode = proxyResponse.statusCode;
    proxyResponse.headers.forEach((name, values) {
      if (!_isHopByHopHeader(name) && name.toLowerCase() != 'set-cookie') {
        request.response.headers.set(name, values);
      }
    });
    _setCorsHeaders(request.response, request);

    await request.response.addStream(proxyResponse);
  } catch (error) {
    request.response.statusCode = HttpStatus.badGateway;
    request.response.headers.contentType = ContentType.json;
    request.response.write('{"error":"Dev API proxy failed: $error"}');
  } finally {
    client.close(force: true);
    await request.response.close();
  }
}

Future<void> _handleExistingInterviewerAuthentication(
  HttpRequest request,
  Uri target,
) async {
  if (request.method != 'POST') {
    await _writeJson(
      request.response,
      HttpStatus.methodNotAllowed,
      {'error': 'Only POST is supported for authentication.'},
    );
    return;
  }

  try {
    final body = await utf8.decoder.bind(request).join();
    final payload = jsonDecode(body);
    final username = payload is Map<String, dynamic>
        ? payload['username']?.toString().trim()
        : null;
    final password = payload is Map<String, dynamic>
        ? payload['password']?.toString()
        : null;
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      await _writeJson(
        request.response,
        HttpStatus.badRequest,
        {'error': 'Username and password are required.'},
      );
      return;
    }

    final uri = target.replace(path: _joinPaths(target.path, request.uri.path));
    final client = HttpClient();
    try {
      final outgoing = await client.postUrl(uri);
      outgoing.headers
        ..set(HttpHeaders.acceptHeader, 'text/plain')
        ..set(HttpHeaders.contentTypeHeader, ContentType.json.mimeType);
      outgoing.write(jsonEncode({
        'username': username,
        'password': password,
      }));
      final incoming = await outgoing.close();
      final responseBody = await utf8.decoder.bind(incoming).join();
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('The authentication response was invalid.');
      }
      if (incoming.statusCode >= 200 && incoming.statusCode < 300) {
        final session = _extractBoSessionToken(decoded);
        if (session != null && session.isNotEmpty) {
          _smsSessionUsers[session] = username;
        }
      }
      await _writeJson(request.response, incoming.statusCode, decoded);
    } finally {
      client.close(force: true);
    }
  } catch (_) {
    await _writeJson(
      request.response,
      HttpStatus.badGateway,
      {'error': 'Authentication could not be completed.'},
    );
  }
}

Future<void> _handleExistingInterviewerProfile(
  HttpRequest request,
  Uri target,
) async {
  if (request.method != 'GET') {
    await _writeJson(
      request.response,
      HttpStatus.methodNotAllowed,
      {'error': 'Only GET is supported for interviewer profiles.'},
    );
    return;
  }

  final session = request.headers.value('sm-authorize');
  if (session == null || session.trim().isEmpty) {
    await _writeJson(
      request.response,
      HttpStatus.unauthorized,
      {'error': 'An interviewer session is required.'},
    );
    return;
  }
  final username = _smsSessionUsers[session];
  if (username == null) {
    await _writeJson(
      request.response,
      HttpStatus.unauthorized,
      {'error': 'The interviewer session has expired. Please log in again.'},
    );
    return;
  }

  final client = HttpClient();
  try {
    final uri = target.replace(
      path: _joinPaths(target.path, request.uri.path),
      query: request.uri.query,
    );
    final outgoing = await client.getUrl(uri);
    outgoing.headers
      ..set(HttpHeaders.acceptHeader, 'text/plain')
      ..set('sm-authorize', session);
    final incoming = await outgoing.close();
    final responseBody = await utf8.decoder.bind(incoming).join();
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'The interviewer profile response was invalid.',
      );
    }
    if (incoming.statusCode < 200 || incoming.statusCode >= 300) {
      await _writeJson(
        request.response,
        incoming.statusCode,
        {'error': 'The interviewer profile could not be retrieved.'},
      );
      return;
    }

    final records = decoded['data'];
    final safeRecords = records is List
        ? records
            .whereType<Map<String, dynamic>>()
            .where((record) =>
                record['surveyor']?.toString().toLowerCase() ==
                username.toLowerCase())
            .map(_safeInterviewerProfile)
            .toList()
        : records is Map<String, dynamic>
            ? _safeInterviewerProfile(records)
            : records;
    final matchedProfile = safeRecords is List && safeRecords.isNotEmpty
        ? safeRecords.first
        : safeRecords;
    if (matchedProfile is Map<String, dynamic>) {
      final computerName =
          matchedProfile['computerNumber']?.toString().trim().toUpperCase();
      if (computerName != null && computerName.isNotEmpty) {
        _smsSessionComputers[session] = computerName;
      }
    }
    await _writeJson(
      request.response,
      HttpStatus.ok,
      {
        'code': decoded['code'] ?? 0,
        'data': safeRecords,
        'errorMessage': decoded['errorMessage'] ?? '',
      },
    );
  } catch (_) {
    await _writeJson(
      request.response,
      HttpStatus.badGateway,
      {'error': 'The interviewer profile could not be retrieved.'},
    );
  } finally {
    client.close(force: true);
  }
}

Map<String, dynamic> _safeInterviewerProfile(Map<String, dynamic> record) => {
      for (final key in const [
        'surveyor',
        'surveyorName',
        'firstName',
        'lastName',
        'email',
        'computerNumber',
        'ireachVersion',
        'lastSync',
      ])
        if (record[key] != null) key: record[key],
    };

Future<void> _handleIReachUpdate(HttpRequest request) async {
  if (request.method != 'POST') {
    await _writeJson(
      request.response,
      HttpStatus.methodNotAllowed,
      {'error': 'Only POST is supported for I-Reach updates.'},
    );
    return;
  }

  final session = request.headers.value('sm-authorize');
  final assignedComputer =
      session == null ? null : _smsSessionComputers[session];
  if (session == null || assignedComputer == null) {
    await _writeJson(
      request.response,
      HttpStatus.unauthorized,
      {
        'status': 'failed',
        'message': 'Your session has expired. Please log in again.',
      },
    );
    return;
  }

  try {
    final body = await utf8.decoder.bind(request).join();
    final payload = jsonDecode(body);
    final computerName = payload is Map<String, dynamic>
        ? payload['computerName']?.toString().trim().toUpperCase()
        : null;
    if (computerName == null ||
        !RegExp(r'^[A-Z0-9][A-Z0-9._-]{2,63}$').hasMatch(computerName)) {
      await _writeJson(
        request.response,
        HttpStatus.badRequest,
        {'error': 'A valid computer name is required.'},
      );
      return;
    }
    if (computerName != assignedComputer) {
      await _writeJson(
        request.response,
        HttpStatus.forbidden,
        {
          'status': 'failed',
          'message':
              'The requested device does not match your assigned computer. Please contact the Help Desk.',
        },
      );
      return;
    }

    final rmmBaseUrl = _requiredEnvironmentValue('RMM_API_BASE_URL');
    final apiKey = _requiredEnvironmentValue('RMM_SYSTEM_TOKEN');
    final scriptId =
        int.tryParse(_requiredEnvironmentValue('RMM_IREACH_SCRIPT_ID'));
    if (scriptId == null) {
      throw StateError('RMM_IREACH_SCRIPT_ID must be a number.');
    }

    final agents = await _sendRmmRequest(
      method: 'GET',
      baseUrl: rmmBaseUrl,
      path: '/agents/',
      systemToken: apiKey,
    );
    final agentId = _findAgentIdByHostname(agents, computerName);
    if (agentId == null) {
      await _writeJson(
        request.response,
        HttpStatus.notFound,
        {
          'status': 'failed',
          'message':
              'No managed device was found for $computerName. Please contact the Help Desk.',
        },
      );
      return;
    }

    await _sendRmmRequest(
      method: 'POST',
      baseUrl: rmmBaseUrl,
      path: '/agents/${Uri.encodeComponent(agentId)}/runscript/',
      systemToken: apiKey,
      body: {
        'output': 'wait',
        'emails': <String>[],
        'emailMode': 'default',
        'custom_field': null,
        'save_all_output': false,
        'script': scriptId,
        'args': <String>[],
        'env_vars': <String>[],
        'run_as_user': false,
        'timeout': 90,
      },
    );
    await _writeJson(
      request.response,
      HttpStatus.ok,
      {
        'status': 'success',
        'message': 'I-Reach has been updated. You can now reopen it.',
      },
    );
  } on StateError catch (error) {
    await _writeJson(
      request.response,
      HttpStatus.serviceUnavailable,
      {'error': error.message},
    );
  } on FormatException catch (error) {
    await _writeJson(
      request.response,
      HttpStatus.badRequest,
      {'error': error.message},
    );
  } catch (_) {
    await _writeJson(
      request.response,
      HttpStatus.badGateway,
      {
        'status': 'failed',
        'message':
            'The update could not be started. Please contact the Help Desk.'
      },
    );
  }
}

Future<void> _handleIReachUpdateStatus(HttpRequest request) async {
  if (request.method != 'GET') {
    await _writeJson(
      request.response,
      HttpStatus.methodNotAllowed,
      {'error': 'Only GET is supported for I-Reach update status.'},
    );
    return;
  }

  try {
    final executionId =
        request.uri.pathSegments.isEmpty ? '' : request.uri.pathSegments.last;
    if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(executionId)) {
      await _writeJson(
        request.response,
        HttpStatus.badRequest,
        {'error': 'A valid execution ID is required.'},
      );
      return;
    }

    final statusTemplate =
        _requiredEnvironmentValue('RMM_UPDATE_STATUS_PATH_TEMPLATE');
    final response = await _sendRmmJson(
      method: 'GET',
      baseUrl: _requiredEnvironmentValue('RMM_API_BASE_URL'),
      path: statusTemplate.replaceAll(
        '{executionId}',
        Uri.encodeComponent(executionId),
      ),
      systemToken: _requiredEnvironmentValue('RMM_SYSTEM_TOKEN'),
    );
    await _writeJson(request.response, HttpStatus.ok, response);
  } on StateError catch (error) {
    await _writeJson(
      request.response,
      HttpStatus.serviceUnavailable,
      {'error': error.message},
    );
  } catch (_) {
    await _writeJson(
      request.response,
      HttpStatus.badGateway,
      {
        'status': 'failed',
        'message':
            'The update status could not be retrieved. Please contact the Help Desk.'
      },
    );
  }
}

Future<Map<String, dynamic>> _sendRmmJson({
  required String method,
  required String baseUrl,
  required String path,
  required String systemToken,
  Map<String, dynamic>? body,
}) async {
  final decoded = await _sendRmmRequest(
    method: method,
    baseUrl: baseUrl,
    path: path,
    systemToken: systemToken,
    body: body,
  );
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'The device platform returned an unexpected response.',
    );
  }
  return decoded;
}

Future<dynamic> _sendRmmRequest({
  required String method,
  required String baseUrl,
  required String path,
  required String systemToken,
  Map<String, dynamic>? body,
}) async {
  final baseUri = Uri.parse(baseUrl);
  final relativeUri = Uri.parse(path);
  final uri = baseUri.replace(
    path: _joinPaths(baseUri.path, relativeUri.path),
    query: relativeUri.hasQuery ? relativeUri.query : null,
  );
  final client = HttpClient();
  try {
    final outgoing = await client.openUrl(method, uri);
    outgoing.headers
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..set(HttpHeaders.contentTypeHeader, ContentType.json.mimeType)
      ..set(
        _runtimeEnvironment['RMM_TOKEN_HEADER'] ?? 'X-API-KEY',
        (_runtimeEnvironment['RMM_TOKEN_PREFIX'] ?? '').isEmpty
            ? systemToken
            : '${_runtimeEnvironment['RMM_TOKEN_PREFIX']}$systemToken',
      );
    if (body != null) {
      outgoing.write(jsonEncode(body));
    }

    final incoming = await outgoing.close();
    final responseBody = await utf8.decoder.bind(incoming).join();
    final decoded = responseBody.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody);
    if (incoming.statusCode < 200 || incoming.statusCode >= 300) {
      throw HttpException(
        'The device platform rejected the request.',
        uri: uri,
      );
    }
    return decoded;
  } finally {
    client.close(force: true);
  }
}

String? _findAgentIdByHostname(dynamic response, String computerName) {
  final records = response is List
      ? response
      : response is Map<String, dynamic> && response['results'] is List
          ? response['results'] as List
          : const [];
  final normalizedComputerName = computerName.toUpperCase();
  for (final record in records.whereType<Map<String, dynamic>>()) {
    final hostname = record['hostname']?.toString().trim().toUpperCase();
    final agentId = record['agent_id']?.toString().trim();
    if (hostname == normalizedComputerName &&
        agentId != null &&
        agentId.isNotEmpty) {
      return agentId;
    }
  }
  return null;
}

String _requiredEnvironmentValue(String name) {
  final value = _runtimeEnvironment[name];
  if (value == null || value.trim().isEmpty) {
    throw StateError('$name is not configured on the API proxy.');
  }
  return value.trim();
}

void _loadLocalEnvironment() {
  final file = File('.env');
  if (!file.existsSync()) {
    return;
  }

  final lines = file.readAsLinesSync();
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final separator = trimmed.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    final key = trimmed.substring(0, separator).trim();
    var value = trimmed.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    _runtimeEnvironment.putIfAbsent(key, () => value);
  }
}

Future<void> _handleNewInterviewerVerification(HttpRequest request) async {
  if (request.method != 'POST') {
    await _writeJson(
      request.response,
      HttpStatus.methodNotAllowed,
      {'error': 'Only POST is supported for new interviewer verification.'},
    );
    return;
  }

  try {
    final body = await utf8.decoder.bind(request).join();
    final payload = jsonDecode(body);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Request body must be a JSON object.');
    }

    final email = payload['email']?.toString().trim().toLowerCase();
    final lastFourDigits = payload['lastFourDigits']?.toString().trim();
    if (email == null || email.isEmpty) {
      await _writeJson(
        request.response,
        HttpStatus.badRequest,
        {'error': 'Email is required.'},
      );
      return;
    }
    if (lastFourDigits == null ||
        !RegExp(r'^\d{4}$').hasMatch(lastFourDigits)) {
      await _writeJson(
        request.response,
        HttpStatus.badRequest,
        {'error': 'Last 4 digits of mobile number are required.'},
      );
      return;
    }

    final boClient = HttpClient();
    try {
      final token = await _getBoSessionToken(boClient);
      final surveyor = await _findSurveyorByEmail(boClient, token, email);
      if (surveyor == null) {
        await _writeJson(
          request.response,
          HttpStatus.notFound,
          {'error': 'No interviewer record was found for that email address.'},
        );
        return;
      }

      final mobile = _firstTextValue(surveyor, const [
        'cellphone',
        'cellphone2',
        'mobile',
        'phone',
        'phoneWork',
        'phoneHome',
      ]);
      if (!_matchesLastFourDigits(mobile, lastFourDigits)) {
        await _writeJson(
          request.response,
          HttpStatus.unauthorized,
          {'error': 'The mobile digits did not match our records.'},
        );
        return;
      }

      final surveyorId = _firstTextValue(surveyor, const ['surveyor']);
      final iReachDevice = surveyorId == null
          ? null
          : await _findIReachDevice(boClient, token, surveyorId);

      await _writeJson(
        request.response,
        HttpStatus.ok,
        _verifiedNewInterviewerPayload(surveyor, iReachDevice, email),
      );
    } finally {
      boClient.close(force: true);
    }
  } on StateError catch (error) {
    await _writeJson(
      request.response,
      HttpStatus.internalServerError,
      {'error': error.message},
    );
  } on FormatException catch (error) {
    await _writeJson(
      request.response,
      HttpStatus.badRequest,
      {'error': error.message},
    );
  } catch (error) {
    await _writeJson(
      request.response,
      HttpStatus.badGateway,
      {'error': 'New interviewer verification failed: $error'},
    );
  }
}

Future<String> _getBoSessionToken(HttpClient client) async {
  final cachedToken = _boSessionToken;
  final createdAt = _boSessionTokenCreatedAt;
  if (cachedToken != null &&
      createdAt != null &&
      DateTime.now().difference(createdAt) < _boSessionTtl) {
    return cachedToken;
  }

  final username = _runtimeEnvironment['BO_API_ADMIN_USERNAME'];
  final password = _runtimeEnvironment['BO_API_ADMIN_PASSWORD'];
  if (username == null ||
      username.trim().isEmpty ||
      password == null ||
      password.isEmpty) {
    throw StateError(
      'Set BO_API_ADMIN_USERNAME and BO_API_ADMIN_PASSWORD on the server before verifying new interviewers.',
    );
  }

  final response = await _sendBoJson(
    client,
    method: 'POST',
    path: '/boapi/v1/Authentication',
    body: {
      'username': username.trim(),
      'password': password,
    },
    headers: const {
      HttpHeaders.acceptHeader: 'text/plain',
    },
  );

  final token = _extractBoSessionToken(response);
  if (token == null || token.isEmpty) {
    throw StateError('BO API authentication did not return a session token.');
  }

  _boSessionToken = token;
  _boSessionTokenCreatedAt = DateTime.now();
  return token;
}

Future<Map<String, dynamic>?> _findSurveyorByEmail(
  HttpClient client,
  String token,
  String email,
) async {
  final filterPath = _surveyorFilterPath(email);
  final response = await _sendBoJson(
    client,
    method: 'GET',
    path: filterPath,
    headers: {
      'sm-bo-authorize': token,
    },
  );
  final records = _extractDataList(response);
  final normalizedEmail = email.toLowerCase();

  for (final record in records) {
    final recordEmail = _firstTextValue(record, const [
      'email',
      'smsEmail',
    ])?.toLowerCase();
    if (recordEmail == normalizedEmail) {
      return record;
    }
  }

  return records.isEmpty ? null : records.first;
}

Future<Map<String, dynamic>?> _findIReachDevice(
  HttpClient client,
  String token,
  String surveyor,
) async {
  final response = await _sendBoJson(
    client,
    method: 'GET',
    path:
        '/boapi/v1/GPSDevice/GetIReachDataGPSDevice/1/10/${Uri.encodeComponent(surveyor)}',
    headers: {
      'sm-bo-authorize': token,
    },
  );
  final records = _extractDataList(response);
  return records.isEmpty ? null : records.first;
}

String _surveyorFilterPath(String email) {
  final encodedEmail = Uri.encodeComponent(email);
  final template = _runtimeEnvironment['BO_API_SURVEYOR_FILTER_PATH_TEMPLATE'];
  if (template != null && template.trim().isNotEmpty) {
    return template.replaceAll('{email}', encodedEmail);
  }

  return '/boapi/v1/Surveyor/filter/1/10/$encodedEmail/%20/0/%20';
}

Future<Map<String, dynamic>> _sendBoJson(
  HttpClient client, {
  required String method,
  required String path,
  Map<String, dynamic>? body,
  Map<String, String> headers = const {},
}) async {
  final baseUrl = Uri.parse(
    _runtimeEnvironment['BO_API_BASE_URL'] ?? _defaultBoApiBaseUrl,
  );
  final uri = baseUrl.replace(
    path: _joinPaths(baseUrl.path, path),
  );

  final request = await client.openUrl(method, uri);
  request.headers
    ..set(HttpHeaders.acceptHeader,
        headers[HttpHeaders.acceptHeader] ?? 'application/json')
    ..set(HttpHeaders.contentTypeHeader, ContentType.json.mimeType);
  headers.forEach(request.headers.set);

  if (body != null) {
    request.write(jsonEncode(body));
  }

  final response = await request.close();
  final responseBody = await utf8.decoder.bind(response).join();
  final json = responseBody.trim().isEmpty
      ? <String, dynamic>{}
      : jsonDecode(responseBody);
  if (json is! Map<String, dynamic>) {
    throw const FormatException(
        'BO API returned an unexpected response shape.');
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final message = json['errorMessage'] ?? json['error'] ?? responseBody;
    throw HttpException(
      'BO API request failed (${response.statusCode}): $message',
      uri: uri,
    );
  }

  return json;
}

String? _extractBoSessionToken(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is Map<String, dynamic>) {
    return _firstTextValue(data, const ['session', 'token', 'accessToken']);
  }
  return _firstTextValue(response, const ['session', 'token', 'accessToken']);
}

List<Map<String, dynamic>> _extractDataList(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is List) {
    return data.whereType<Map<String, dynamic>>().toList();
  }
  if (data is Map<String, dynamic>) {
    return [data];
  }
  return const [];
}

Map<String, dynamic> _verifiedNewInterviewerPayload(
  Map<String, dynamic> surveyor,
  Map<String, dynamic>? iReachDevice,
  String email,
) {
  final surveyorId = _firstTextValue(surveyor, const ['surveyor']) ?? email;
  final displayName = _firstTextValue(surveyor, const [
        'surveyorName',
        'name',
      ]) ??
      [
        _firstTextValue(surveyor, const ['firstName']),
        _firstTextValue(surveyor, const ['lastName']),
      ].whereType<String>().join(' ').trim();
  final computerNumber = _firstTextValue(surveyor, const ['computerNumber']);
  final deviceName =
      _firstTextValue(iReachDevice ?? const {}, const ['deviceName']);

  return {
    'id': surveyorId,
    'username': surveyorId,
    'displayName': displayName.isEmpty ? surveyorId : displayName,
    'userType': 'new',
    'email': _firstTextValue(surveyor, const ['email', 'smsEmail']) ?? email,
    'mobile': _firstTextValue(surveyor, const ['cellphone', 'cellphone2']),
    'deviceId': computerNumber ?? deviceName,
    'deviceType': _deviceTypeFrom(computerNumber, deviceName),
    'project': _firstTextValue(surveyor, const ['projectName']),
    'assignedDevice': {
      if (deviceName != null) 'deviceId': deviceName,
      if (iReachDevice != null) ...iReachDevice,
    },
  };
}

String _deviceTypeFrom(String? computerNumber, String? deviceName) {
  final combined = '${computerNumber ?? ''} ${deviceName ?? ''}'.toLowerCase();
  if (combined.contains('tab') || combined.contains('android')) {
    return 'Android tablet';
  }
  if (combined.contains('lt') ||
      combined.contains('laptop') ||
      computerNumber != null) {
    return 'Windows laptop';
  }
  return 'Assigned device';
}

String? _firstTextValue(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value != null) {
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
  }
  return null;
}

bool _matchesLastFourDigits(String? phoneNumber, String expectedLastFour) {
  if (phoneNumber == null) {
    return false;
  }
  final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
  return digitsOnly.endsWith(expectedLastFour);
}

Future<void> _writeJson(
  HttpResponse response,
  int statusCode,
  Map<String, dynamic> body,
) async {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}

void _copyRequestHeaders(HttpRequest source, HttpClientRequest target) {
  source.headers.forEach((name, values) {
    if (!_isHopByHopHeader(name) &&
        name.toLowerCase() != 'host' &&
        name.toLowerCase() != 'origin') {
      target.headers.set(name, values);
    }
  });
}

void _setCorsHeaders(HttpResponse response, HttpRequest request) {
  final origin = request.headers.value('origin') ?? '*';
  final requestedHeaders = request.headers
          .value('access-control-request-headers') ??
      'authorization, content-type, sm-authorize, x-requested-with, x-session-token';

  response.headers
    ..set(HttpHeaders.accessControlAllowOriginHeader, origin)
    ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, POST, OPTIONS')
    ..set(HttpHeaders.accessControlAllowHeadersHeader, requestedHeaders)
    ..set(HttpHeaders.accessControlAllowCredentialsHeader, 'true')
    ..set(HttpHeaders.varyHeader, 'Origin');
}

bool _isHopByHopHeader(String name) {
  return const {
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
  }.contains(name.toLowerCase());
}

String _joinPaths(String basePath, String requestPath) {
  final cleanBase = basePath.endsWith('/')
      ? basePath.substring(0, basePath.length - 1)
      : basePath;
  final cleanRequest =
      requestPath.startsWith('/') ? requestPath : '/$requestPath';
  return '$cleanBase$cleanRequest';
}

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index == args.length - 1) {
    return null;
  }
  return args[index + 1];
}
