import 'dart:convert';
import 'dart:io';

const _defaultTarget = 'https://smstg.ipsos.co.nz';
const _defaultBoApiBaseUrl = 'https://boapistg.ipsos.co.nz';
const _defaultPort = 8787;
const _boSessionTtl = Duration(minutes: 25);

String? _boSessionToken;
DateTime? _boSessionTokenCreatedAt;

Future<void> main(List<String> args) async {
  final target = Uri.parse(
    _argValue(args, '--target') ??
        Platform.environment['DEV_API_PROXY_TARGET'] ??
        _defaultTarget,
  );
  final port = int.parse(
    _argValue(args, '--port') ??
        Platform.environment['DEV_API_PROXY_PORT'] ??
        '$_defaultPort',
  );

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Proxying http://localhost:$port -> $target');

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

  final username = Platform.environment['BO_API_ADMIN_USERNAME'];
  final password = Platform.environment['BO_API_ADMIN_PASSWORD'];
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
  final template = Platform.environment['BO_API_SURVEYOR_FILTER_PATH_TEMPLATE'];
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
    Platform.environment['BO_API_BASE_URL'] ?? _defaultBoApiBaseUrl,
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
