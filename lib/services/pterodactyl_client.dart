import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pterodactyl_server.dart';
import '../models/server_resources.dart';

class PterodactylClient {
  PterodactylClient({required this.panelUrl, required this.apiToken, http.Client? client})
      : _client = client ?? http.Client();

  final String panelUrl;
  final String apiToken;
  final http.Client _client;

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPanelUrl = panelUrl.endsWith('/') ? panelUrl.substring(0, panelUrl.length - 1) : panelUrl;
    return Uri.parse('$normalizedPanelUrl$path').replace(queryParameters: queryParameters?.map((key, value) => MapEntry(key, value.toString())));
  }

  Map<String, String> get _headers => <String, String>{
        'Authorization': 'Bearer $apiToken',
        'Accept': 'Application/vnd.pterodactyl.v1+json',
        'Content-Type': 'application/json',
      };

  Future<List<PterodactylServer>> fetchServers() async {
    final response = await _client.get(_uri('/api/client'), headers: _headers);
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? const [];
    return data
        .map((entry) => PterodactylServer.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ServerResources> fetchServerResources(String identifier) async {
    final response = await _client.get(_uri('/api/client/servers/$identifier/resources'), headers: _headers);
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ServerResources.fromJson(decoded);
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
      _extractMessage(response.body) ?? 'Request failed with status ${response.statusCode}',
    );
  }

  String? _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final errors = decoded['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first as Map<String, dynamic>?;
        final detail = first?['detail']?.toString();
        if (detail != null && detail.isNotEmpty) {
          return detail;
        }
      }
      final error = decoded['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class PterodactylApiException implements Exception {
  const PterodactylApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'PterodactylApiException($statusCode): $message';
}
