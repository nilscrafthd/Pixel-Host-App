import 'package:shared_preferences/shared_preferences.dart';

class SessionData {
  const SessionData({required this.apiToken});

  final String apiToken;
}

class SessionStore {
  static const String _apiTokenKey = 'api_token';

  Future<SessionData?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString(_apiTokenKey);
    if (apiToken == null || apiToken.isEmpty) {
      return null;
    }
    await prefs.remove('panel_url');
    return SessionData(apiToken: apiToken);
  }

  Future<void> saveSession(SessionData session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiTokenKey, session.apiToken);
    await prefs.remove('panel_url');
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiTokenKey);
    await prefs.remove('panel_url');
  }
}
