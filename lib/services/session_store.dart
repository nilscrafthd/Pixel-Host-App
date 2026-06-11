import 'package:shared_preferences/shared_preferences.dart';

enum SessionProfile { user, main }

enum LoginMethod { token, credentials }

class SessionData {
  const SessionData({
    required this.apiToken,
    required this.profile,
    this.loginMethod = LoginMethod.token,
    this.savedUsername,
  });

  final String apiToken;
  final SessionProfile profile;
  final LoginMethod loginMethod;

  /// Only stored when the user logged in via username/password,
  /// so the username field can be pre-filled on next launch.
  final String? savedUsername;
}

class SessionStore {
  static const String _userTokenKey = 'user_api_token';
  static const String _mainTokenKey = 'main_api_token';
  static const String _activeProfileKey = 'active_profile';
  static const String _loginMethodKey = 'login_method';
  static const String _savedUsernameKey = 'saved_username';

  String _tokenKey(SessionProfile profile) {
    return profile == SessionProfile.user ? _userTokenKey : _mainTokenKey;
  }

  SessionProfile _parseProfile(String? value) {
    if (value == SessionProfile.main.name) {
      return SessionProfile.main;
    }
    return SessionProfile.user;
  }

  LoginMethod _parseLoginMethod(String? value) {
    if (value == LoginMethod.credentials.name) {
      return LoginMethod.credentials;
    }
    return LoginMethod.token;
  }

  Future<String?> loadToken(SessionProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey(profile));
    if (token == null || token.isEmpty) {
      return null;
    }
    return token;
  }

  Future<SessionProfile> loadPreferredProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseProfile(prefs.getString(_activeProfileKey));
  }

  Future<LoginMethod> loadPreferredLoginMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseLoginMethod(prefs.getString(_loginMethodKey));
  }

  Future<String?> loadSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_savedUsernameKey);
    if (username == null || username.isEmpty) return null;
    return username;
  }

  Future<SessionData?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final activeProfile = _parseProfile(prefs.getString(_activeProfileKey));
    final activeToken = prefs.getString(_tokenKey(activeProfile));
    if (activeToken != null && activeToken.isNotEmpty) {
      final loginMethod = _parseLoginMethod(prefs.getString(_loginMethodKey));
      final savedUsername = prefs.getString(_savedUsernameKey);
      return SessionData(
        apiToken: activeToken,
        profile: activeProfile,
        loginMethod: loginMethod,
        savedUsername: savedUsername?.isEmpty == true ? null : savedUsername,
      );
    }

    for (final profile in SessionProfile.values) {
      final token = prefs.getString(_tokenKey(profile));
      if (token != null && token.isNotEmpty) {
        return SessionData(apiToken: token, profile: profile);
      }
    }

    return null;
  }

  Future<void> saveToken(SessionProfile profile, String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey(profile), normalized);
  }

  Future<void> saveActiveProfile(SessionProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, profile.name);
  }

  Future<void> saveSession(SessionData session) async {
    await saveToken(session.profile, session.apiToken);
    await saveActiveProfile(session.profile);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loginMethodKey, session.loginMethod.name);

    if (session.savedUsername != null && session.savedUsername!.isNotEmpty) {
      await prefs.setString(_savedUsernameKey, session.savedUsername!);
    } else {
      await prefs.remove(_savedUsernameKey);
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userTokenKey);
    await prefs.remove(_mainTokenKey);
    await prefs.remove(_activeProfileKey);
    await prefs.remove(_loginMethodKey);
    await prefs.remove(_savedUsernameKey);
  }
}