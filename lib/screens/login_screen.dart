import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/app_config.dart';
import '../services/pterodactyl_client.dart';
import '../services/session_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});

  final Future<void> Function(SessionData session) onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showWebView = false;

  void _openWebViewLogin() {
    setState(() => _showWebView = true);
  }

  void _closeWebView() {
    setState(() => _showWebView = false);
  }

  Future<void> _handleTokenReceived(String token) async {
    setState(() => _showWebView = false);

    final session = SessionData(
      apiToken: token,
      profile: SessionProfile.user,
    );

    final client = PterodactylClient(apiToken: token);
    try {
      await client.fetchServers();
    } finally {
      client.dispose();
    }

    await widget.onLoggedIn(session);
  }

  @override
  Widget build(BuildContext context) {
    if (_showWebView) {
      return _PanelLoginWebView(
        onTokenReceived: _handleTokenReceived,
        onCancel: _closeWebView,
      );
    }

    return _LoginLandingScreen(onSignIn: _openWebViewLogin);
  }
}

// ── Landing screen ────────────────────────────────────────────────────────────

class _LoginLandingScreen extends StatelessWidget {
  const _LoginLandingScreen({required this.onSignIn});

  final VoidCallback onSignIn;

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
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pixel Host',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppConfig.panelUrl,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white54),
                    ),
                    const SizedBox(height: 32),
                    _StepRow(
                      number: '1',
                      text: 'Sign in to your panel account',
                    ),
                    const SizedBox(height: 12),
                    _StepRow(
                      number: '2',
                      text: 'An API token is created automatically',
                    ),
                    const SizedBox(height: 12),
                    _StepRow(
                      number: '3',
                      text: 'The app connects — you\'re in',
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onSignIn,
                        icon: const Icon(Icons.login_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Sign in with Panel'),
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

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

// ── WebView login ─────────────────────────────────────────────────────────────

class _PanelLoginWebView extends StatefulWidget {
  const _PanelLoginWebView({
    required this.onTokenReceived,
    required this.onCancel,
  });

  final Future<void> Function(String token) onTokenReceived;
  final VoidCallback onCancel;

  @override
  State<_PanelLoginWebView> createState() => _PanelLoginWebViewState();
}

class _PanelLoginWebViewState extends State<_PanelLoginWebView> {
  late final WebViewController _controller;
  bool _busy = false;
  String? _errorMessage;

  static String get _panelBase {
    final url = AppConfig.panelUrl;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterTokenBridge',
        onMessageReceived: _onBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: _onPageFinished,
          onWebResourceError: (error) {
            if (mounted) {
              setState(() =>
                  _errorMessage = 'Failed to load panel: ${error.description}');
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('$_panelBase/auth/login'));
  }

  /// Called every time a page finishes loading.
  /// If the user has landed on a page other than /auth/*, they are logged in —
  /// inject JS to create an API token automatically.
  Future<void> _onPageFinished(String url) async {
    if (_busy) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final isAuthPage = uri.path.startsWith('/auth');
    if (isAuthPage) return; // still on login / 2FA pages, wait

    // User is logged in — create a token automatically.
    setState(() => _busy = true);
    await _injectTokenCreation();
  }

  Future<void> _injectTokenCreation() async {
    // language=JavaScript
    const js = r"""
(async () => {
  try {
    // 1. Get CSRF token from meta tag
    const metaEl = document.querySelector('meta[name="csrf-token"]');
    if (!metaEl) {
      FlutterTokenBridge.postMessage(JSON.stringify({
        error: 'CSRF token not found on page. Please try again.'
      }));
      return;
    }
    const csrf = metaEl.getAttribute('content');

    // 2. Create API token via the client API
    const res = await fetch('/api/client/account/api-keys', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.pterodactyl.v1+json',
        'X-CSRF-TOKEN': csrf,
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: JSON.stringify({
        description: 'Pixel Host App — ' + new Date().toLocaleDateString(),
        allowed_ips: []
      })
    });

    const data = await res.json();

    if (!res.ok) {
      const msg = data?.errors?.[0]?.detail
                  || data?.error
                  || ('Request failed: ' + res.status);
      FlutterTokenBridge.postMessage(JSON.stringify({ error: msg }));
      return;
    }

    // The full token is only returned once, in data.meta.secret_token
    const token = data?.meta?.secret_token || data?.attributes?.identifier;
    if (!token) {
      FlutterTokenBridge.postMessage(JSON.stringify({
        error: 'Token created but could not be read. Please use a manual API token.'
      }));
      return;
    }

    FlutterTokenBridge.postMessage(JSON.stringify({ token: token }));
  } catch (e) {
    FlutterTokenBridge.postMessage(JSON.stringify({ error: String(e) }));
  }
})();
""";

    await _controller.runJavaScript(js);
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Unexpected response from panel.');
      return;
    }

    final error = payload['error'] as String?;
    if (error != null) {
      if (mounted) setState(() {
        _busy = false;
        _errorMessage = error;
      });
      return;
    }

    final token = payload['token'] as String?;
    if (token != null && token.isNotEmpty) {
      widget.onTokenReceived(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to Panel'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: widget.onCancel,
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // WebView — hidden while busy so the user doesn't see the navigation
          Opacity(
            opacity: _busy ? 0.0 : 1.0,
            child: WebViewWidget(controller: _controller),
          ),

          // Overlay shown while creating the token
          if (_busy && _errorMessage == null)
            const ColoredBox(
              color: Color(0xFF0B1220),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Creating API token…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          // Error overlay
          if (_errorMessage != null)
            ColoredBox(
              color: const Color(0xFF0B1220),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => setState(() {
                          _errorMessage = null;
                          _busy = false;
                          _controller
                              .loadRequest(Uri.parse('$_panelBase/auth/login'));
                        }),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}