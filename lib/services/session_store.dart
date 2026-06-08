import 'package:shared_preferences/shared_preferences.dart';

class SessionData {
  const SessionData({required this.panelUrl, required this.apiToken});

  final String panelUrl;
  final String apiToken;
}

class SessionStore {
  static const String _panelUrlKey = 'panel_url';
  static const String _apiTokenKey = 'api_token';

  Future<SessionData?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final panelUrl = prefs.getString(_panelUrlKey);
    final apiToken = prefs.getString(_apiTokenKey);
    if (panelUrl == null || apiToken == null || panelUrl.isEmpty || apiToken.isEmpty) {
      return null;
    }
    return SessionData(panelUrl: panelUrl, apiToken: apiToken);
  }

  Future<void> saveSession(SessionData session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_panelUrlKey, session.panelUrl);
    await prefs.setString(_apiTokenKey, session.apiToken);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_panelUrlKey);
    await prefs.remove(_apiTokenKey);
  }
}
