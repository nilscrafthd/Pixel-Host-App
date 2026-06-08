import 'package:flutter/material.dart';

import '../services/pterodactyl_client.dart';
import '../services/session_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});

  final Future<void> Function(SessionData session) onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _panelUrlController = TextEditingController();
  final TextEditingController _apiTokenController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _panelUrlController.dispose();
    _apiTokenController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final session = SessionData(
      panelUrl: _panelUrlController.text.trim(),
      apiToken: _apiTokenController.text.trim(),
    );
    final client = PterodactylClient(
      panelUrl: session.panelUrl,
      apiToken: session.apiToken,
    );

    try {
      await client.fetchServers();
      await widget.onLoggedIn(session);
    } on PterodactylApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Unable to connect to the panel.';
      });
    } finally {
      client.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 0,
              color: const Color(0xFF111B2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pixel Host',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with your Pterodactyl panel URL and Client API token.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _panelUrlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Panel URL',
                          hintText: 'https://panel.example.com',
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Enter your panel URL.';
                          }
                          final uri = Uri.tryParse(trimmed);
                          if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
                            return 'Enter a valid URL including https://';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _apiTokenController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Client API Token',
                          hintText: 'ptlc_...',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Enter your API token.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
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
      ),
    );
  }
}
