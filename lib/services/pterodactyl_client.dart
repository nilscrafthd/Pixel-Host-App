import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/pterodactyl_file.dart';
import '../models/pterodactyl_server.dart';
import '../models/server_resources.dart';

class PterodactylClient {
  PterodactylClient({required this.apiToken, http.Client? client})
      : _client = client ?? http.Client();

  final String apiToken;
  final http.Client _client;

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPanelUrl = AppConfig.panelUrl.endsWith('/')
        ? AppConfig.panelUrl.substring(0, AppConfig.panelUrl.length - 1)
        : AppConfig.panelUrl;
    return Uri.parse('$normalizedPanelUrl$path').replace(
        queryParameters: queryParameters
            ?.map((key, value) => MapEntry(key, value.toString())));
  }

  Map<String, String> get _headers => <String, String>{
        'Authorization': 'Bearer $apiToken',
        'Accept': 'Application/vnd.pterodactyl.v1+json',
        'Content-Type': 'application/json',
      };

  /// Authenticates with username and password and returns an API token.
  /// Throws [PterodactylApiException] on failure.
  static Future<String> loginWithCredentials({
    required String username,
    required String password,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final normalizedPanelUrl = AppConfig.panelUrl.endsWith('/')
        ? AppConfig.panelUrl.substring(0, AppConfig.panelUrl.length - 1)
        : AppConfig.panelUrl;

    try {
      final loginUri = Uri.parse('$normalizedPanelUrl/auth/login');

      // Step 1: GET the login page to obtain the CSRF cookie + token.
      final getResponse = await httpClient.get(
        loginUri,
        headers: <String, String>{
          'Accept': 'text/html,application/xhtml+xml',
        },
      );

      // Extract Set-Cookie header(s) so we can echo them back.
      final rawCookies = getResponse.headers['set-cookie'] ?? '';
      final cookieHeader = _parseCookiesForRequest(rawCookies);

      // Extract the CSRF token from the HTML (<meta name="csrf-token" content="...">)
      // or from the XSRF-TOKEN / pterodactyl_session cookie value itself.
      final csrfToken = _extractCsrfToken(getResponse.body, rawCookies);

      if (csrfToken == null || csrfToken.isEmpty) {
        throw const PterodactylApiException(
          0,
          'Could not retrieve CSRF token from the panel. '
          'Make sure the panel URL is correct.',
        );
      }

      // Step 2: POST credentials with the CSRF token.
      final postResponse = await httpClient.post(
        loginUri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-TOKEN': csrfToken,
          'X-Requested-With': 'XMLHttpRequest',
          if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          'Referer': loginUri.toString(),
        },
        body: jsonEncode(<String, String>{
          'user': username,
          'password': password,
        }),
      );

      if (postResponse.statusCode >= 200 && postResponse.statusCode < 300) {
        final decoded = jsonDecode(postResponse.body) as Map<String, dynamic>;
        final token = _extractTokenFromResponse(decoded);
        if (token != null && token.isNotEmpty) {
          return token;
        }

        throw const PterodactylApiException(
          200,
          'Login succeeded but no API token was returned. '
          'Please use the API token login instead.',
        );
      }

      final message = _extractErrorMessage(postResponse.body) ??
          'Login failed (${postResponse.statusCode})';
      throw PterodactylApiException(postResponse.statusCode, message);
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Parses a raw Set-Cookie header string into a Cookie request header value.
  /// Handles both comma-separated and multi-value formats.
  static String _parseCookiesForRequest(String rawSetCookie) {
    if (rawSetCookie.isEmpty) return '';

    final cookies = <String>[];
    // Split on ", " only when followed by a cookie name (word=),
    // to avoid splitting on comma-containing Expires= values.
    final parts = rawSetCookie.split(RegExp(r',\s*(?=[^;,]+=[^;,]+)'));
    for (final part in parts) {
      final nameValue = part.trim().split(';').first.trim();
      if (nameValue.isNotEmpty) {
        cookies.add(nameValue);
      }
    }
    return cookies.join('; ');
  }

  /// Tries to find the CSRF token in the HTML body or cookie string.
  static String? _extractCsrfToken(String html, String rawCookies) {
    // 1. <meta name="csrf-token" content="...">
    final metaMatch =
        RegExp(r'<meta\s+name=["\']csrf-token["\']\s+content=["\'](.*?)["\']',
                caseSensitive: false)
            .firstMatch(html);
    if (metaMatch != null) return metaMatch.group(1);

    // 2. XSRF-TOKEN cookie (URL-encoded)
    final xsrfMatch =
        RegExp(r'XSRF-TOKEN=([^;,\s]+)').firstMatch(rawCookies);
    if (xsrfMatch != null) {
      return Uri.decodeComponent(xsrfMatch.group(1)!);
    }

    return null;
  }

  static String? _extractTokenFromResponse(Map<String, dynamic> body) {
    // Shape: { "token": "..." }
    final token = body['token'];
    if (token is String && token.isNotEmpty) return token;

    // Shape: { "data": { "token": "..." } }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final nested = data['token'];
      if (nested is String && nested.isNotEmpty) return nested;
    }

    // Shape: { "attributes": { "token": "..." } }
    final attributes = body['attributes'];
    if (attributes is Map<String, dynamic>) {
      final nested = attributes['token'];
      if (nested is String && nested.isNotEmpty) return nested;
    }

    return null;
  }

  static String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final errors = decoded['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first as Map<String, dynamic>?;
        final detail = first?['detail']?.toString();
        if (detail != null && detail.isNotEmpty) return detail;
      }
      final error = decoded['error'];
      if (error is String && error.isNotEmpty) return error;
      final message = decoded['message'];
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<List<PterodactylServer>> fetchServers() async {
    final response =
        await _client.get(_uri('/api/client'), headers: _headers);
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? const [];
    return data
        .map((entry) =>
            PterodactylServer.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ServerResources> fetchServerResources(String identifier) async {
    final response = await _client.get(
        _uri('/api/client/servers/$identifier/resources'),
        headers: _headers);
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ServerResources.fromJson(decoded);
  }

  Future<List<PterodactylFile>> loadDirectory(
      String identifier, String directory) async {
    final response = await _client.get(
      _uri('/api/client/servers/$identifier/files/list',
          <String, dynamic>{'directory': directory}),
      headers: _headers,
    );
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? const [];
    return data
        .map((entry) =>
            PterodactylFile.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<String> getFileContents(String identifier, String file) async {
    final response = await _client.get(
      _uri('/api/client/servers/$identifier/files/contents',
          <String, dynamic>{'file': file}),
      headers: _headers,
    );
    _ensureSuccess(response);
    return response.body;
  }

  Future<void> saveFileContents(
      String identifier, String file, String content) async {
    final response = await _client.post(
      _uri('/api/client/servers/$identifier/files/write',
          <String, dynamic>{'file': file}),
      headers: <String, String>{
        ..._headers,
        'Content-Type': 'text/plain',
      },
      body: content,
    );
    _ensureSuccess(response);
  }

  Future<void> deleteFiles(
      String identifier, String root, List<String> files) async {
    final response = await _client.post(
      _uri('/api/client/servers/$identifier/files/delete'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{'root': root, 'files': files}),
    );
    _ensureSuccess(response);
  }

  Future<void> copyFile(String identifier, String location) async {
    final response = await _client.post(
      _uri('/api/client/servers/$identifier/files/copy'),
      headers: _headers,
      body: jsonEncode(<String, String>{'location': location}),
    );
    _ensureSuccess(response);
  }

  Future<void> renameFiles(
      String identifier, String root, List<Map<String, String>> files) async {
    final response = await _client.put(
      _uri('/api/client/servers/$identifier/files/rename'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{'root': root, 'files': files}),
    );
    _ensureSuccess(response);
  }

  Future<void> createDirectory(
      String identifier, String root, String name) async {
    final response = await _client.post(
      _uri('/api/client/servers/$identifier/files/create-folder'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{'root': root, 'name': name}),
    );
    _ensureSuccess(response);
  }

  Future<void> chmodFiles(
      String identifier, String root, List<Map<String, String>> files) async {
    final response = await _client.post(
      _uri('/api/client/servers/$identifier/files/chmod'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{'root': root, 'files': files}),
    );
    _ensureSuccess(response);
  }

  Future<void> compressFiles(
      String identifier, String root, List<String> files) async {
    final response = await _client.post(
      _uri('/api/client/servers/$identifier/files/compress'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{'root': root, 'files': files}),
    );
    _ensureSuccess(response);
  }

  Future<void> decompressFile(
      String identifier, String root, String file) async {
    final response = await _client.post(
      _uri('/api/client/servers/$identifier/files/decompress'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{'root': root, 'file': file}),
    );
    _ensureSuccess(response);
  }

  Future<String> getFileDownloadUrl(String identifier, String file) async {
    final response = await _client.get(
      _uri('/api/client/servers/$identifier/files/download',
          <String, dynamic>{'file': file}),
      headers: _headers,
    );
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final attributes =
        decoded['attributes'] as Map<String, dynamic>? ?? const {};
    return attributes['url']?.toString() ?? '';
  }

  Future<String> getFileUploadUrl(String identifier) async {
    final response = await _client.get(
        _uri('/api/client/servers/$identifier/files/upload'),
        headers: _headers);
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final attributes =
        decoded['attributes'] as Map<String, dynamic>? ?? const {};
    return attributes['url']?.toString() ?? '';
  }

  Future<void> sendCommand(String identifier, String command) async {
    final response = await _client.post(
      _uri('/api/client/servers/$identifier/command'),
      headers: _headers,
      body: jsonEncode(<String, String>{'command': command}),
    );
    _ensureSuccess(response);
  }

  Future<void> renameServer(String identifier, String name,
      {String? description}) async {
    final response = await _client.post(
      _uri('/api/client/servers/$identifier/settings/rename'),
      headers: _headers,
      body:
          jsonEncode(<String, dynamic>{'name': name, 'description': description}),
    );
    _ensureSuccess(response);
  }

  Future<void> reinstallServer(String identifier) async {
    final response = await _client.post(
      _uri('/api/client/servers/$identifier/settings/reinstall'),
      headers: _headers,
    );
    _ensureSuccess(response);
  }

  Future<WebSocketTicket> getWebsocketTicket(String identifier) async {
    final response = await _client.get(
        _uri('/api/client/servers/$identifier/websocket'),
        headers: _headers);
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    return WebSocketTicket(
      token: data['token']?.toString() ?? '',
      socket: data['socket']?.toString() ?? '',
    );
  }

  WebSocketChannel connectWebsocket(String socketUrl) {
    return WebSocketChannel.connect(Uri.parse(socketUrl));
  }

  Future<void> sendPowerSignal(String identifier, String signal) async {
    final response = await _client.post(
      _uri('/api/client/servers/$identifier/power'),
      headers: _headers,
      body: jsonEncode(<String, String>{'signal': signal}),
    );
    _ensureSuccess(response);
  }

  void dispose() {
    _client.close();
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw PterodactylApiException(
      response.statusCode,
      _extractErrorMessage(response.body) ??
          'Request failed with status ${response.statusCode}',
    );
  }
}

class WebSocketTicket {
  const WebSocketTicket({required this.token, required this.socket});

  final String token;
  final String socket;
}

class PterodactylApiException implements Exception {
  const PterodactylApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'PterodactylApiException($statusCode): $message';
}