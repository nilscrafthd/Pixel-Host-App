import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/pterodactyl_client.dart';
import '../services/session_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});

  final Future<void> Function(SessionData session) onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final SessionStore _sessionStore = SessionStore();

  // --- Token tab ---
  final GlobalKey<FormState> _tokenFormKey = GlobalKey<FormState>();
  final TextEditingController _apiTokenController = TextEditingController();
  SessionProfile _selectedProfile = SessionProfile.user;

  // --- Credentials tab ---
  final GlobalKey<FormState> _credentialsFormKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;

  // --- Shared state ---
  bool _loading = false;
  bool _cacheLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Clear errors when switching tabs
      if (!_tabController.indexIsChanging) {
        setState(() => _errorMessage = null);
      }
    });
    _loadCachedState();
  }

  Future<void> _loadCachedState() async {
    final profile = await _sessionStore.loadPreferredProfile();
    final loginMethod = await _sessionStore.loadPreferredLoginMethod();
    final token = await _sessionStore.loadToken(profile);
    final savedUsername = await _sessionStore.loadSavedUsername();

    if (!mounted) return;

    setState(() {
      _selectedProfile = profile;
      if (token != null) _apiTokenController.text = token;
      if (savedUsername != null) _usernameController.text = savedUsername;
      _tabController.index =
          loginMethod == LoginMethod.credentials ? 1 : 0;
      _cacheLoaded = true;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiTokenController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Token login ──────────────────────────────────────────────────────────

  Future<void> _loginWithToken() async {
    if (!_tokenFormKey.currentState!.validate()) return;
    _setLoading(true);

    final session = SessionData(
      apiToken: _apiTokenController.text.trim(),
      profile: _selectedProfile,
      loginMethod: LoginMethod.token,
    );
    final client = PterodactylClient(apiToken: session.apiToken);

    try {
      await client.fetchServers();
      await widget.onLoggedIn(session);
    } on PterodactylApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Unable to connect to panel: $e');
    } finally {
      client.dispose();
      _setLoading(false);
    }
  }

  Future<void> _changeProfile(SessionProfile profile) async {
    if (_selectedProfile == profile) return;

    final currentToken = _apiTokenController.text.trim();
    if (currentToken.isNotEmpty) {
      await _sessionStore.saveToken(_selectedProfile, currentToken);
    }

    if (!mounted) return;
    setState(() {
      _selectedProfile = profile;
      _errorMessage = null;
    });

    final token = await _sessionStore.loadToken(profile);
    if (!mounted) return;
    setState(() => _apiTokenController.text = token ?? '');
  }

  // ── Credentials login ────────────────────────────────────────────────────

  Future<void> _loginWithCredentials() async {
    if (!_credentialsFormKey.currentState!.validate()) return;
    _setLoading(true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      final apiToken = await PterodactylClient.loginWithCredentials(
        username: username,
        password: password,
      );

      final session = SessionData(
        apiToken: apiToken,
        profile: _selectedProfile,
        loginMethod: LoginMethod.credentials,
        savedUsername: username,
      );

      // Verify the token works by fetching servers
      final client = PterodactylClient(apiToken: apiToken);
      try {
        await client.fetchServers();
      } finally {
        client.dispose();
      }

      await widget.onLoggedIn(session);
    } on PterodactylApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Unable to connect to panel: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    if (mounted) setState(() => _loading = value);
  }

  void _setError(String message) {
    if (mounted) setState(() => _errorMessage = message);
  }

  String _profileLabel(SessionProfile profile) =>
      profile == SessionProfile.user ? 'User Token' : 'Main Token';

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 0,
              color: const Color(0xFF111B2E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Pixel Host',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connect to ${AppConfig.panelUrl}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),

                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: Colors.white54,
                      tabs: const [
                        Tab(text: 'API Token'),
                        Tab(text: 'Username & Password'),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Error banner (shared)
                    if (_errorMessage != null) ...[
                      _ErrorBanner(message: _errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // Tab content
                    SizedBox(
                      // Enough height to hold either form without jumping
                      height: 300,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _TokenForm(
                            formKey: _tokenFormKey,
                            tokenController: _apiTokenController,
                            selectedProfile: _selectedProfile,
                            onProfileChanged: _changeProfile,
                            profileLabel: _profileLabel,
                          ),
                          _CredentialsForm(
                            formKey: _credentialsFormKey,
                            usernameController: _usernameController,
                            passwordController: _passwordController,
                            passwordVisible: _passwordVisible,
                            onTogglePasswordVisibility: () => setState(
                                () => _passwordVisible = !_passwordVisible),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Connect button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_loading || !_cacheLoaded)
                            ? null
                            : _tabController.index == 0
                                ? _loginWithToken
                                : _loginWithCredentials,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Connect'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenForm extends StatelessWidget {
  const _TokenForm({
    required this.formKey,
    required this.tokenController,
    required this.selectedProfile,
    required this.onProfileChanged,
    required this.profileLabel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController tokenController;
  final SessionProfile selectedProfile;
  final Future<void> Function(SessionProfile) onProfileChanged;
  final String Function(SessionProfile) profileLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<SessionProfile>(
            segments: SessionProfile.values
                .map((p) => ButtonSegment(
                      value: p,
                      label: Text(profileLabel(p)),
                    ))
                .toList(),
            selected: {selectedProfile},
            onSelectionChanged: (selected) =>
                onProfileChanged(selected.first),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: tokenController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Token',
              hintText: 'ptlc_...',
              prefixIcon: Icon(Icons.key_outlined),
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Enter your API token.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Find your token under Account > API Credentials on the panel.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

class _CredentialsForm extends StatelessWidget {
  const _CredentialsForm({
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.passwordVisible,
    required this.onTogglePasswordVisibility,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final VoidCallback onTogglePasswordVisibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: usernameController,
            decoration: const InputDecoration(
              labelText: 'Username or Email',
              hintText: 'admin',
              prefixIcon: Icon(Icons.person_outline),
            ),
            autocorrect: false,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Enter your username or email.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: passwordController,
            obscureText: !passwordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: onTogglePasswordVisibility,
                tooltip: passwordVisible ? 'Hide password' : 'Show password',
              ),
            ),
            textInputAction: TextInputAction.done,
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return 'Enter your password.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Your credentials are only used to obtain an API token and are never stored.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}