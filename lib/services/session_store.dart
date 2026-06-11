import 'package:shared_preferences/shared_preferences.dart';

class SessionData {
  const SessionData({required this.apiToken});

  final String apiToken;
}

class SessionStore {
  static const String _tokenKey = 'api_token';

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Future<SessionData?> loadSession() async {
    final token = await loadToken();
    if (token == null) return null;
    return SessionData(apiToken: token);
  }

  Future<void> saveSession(SessionData session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.apiToken.trim());
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}