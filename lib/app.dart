import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/session_store.dart';

class PixelHostApp extends StatefulWidget {
  const PixelHostApp({super.key});

  @override
  State<PixelHostApp> createState() => _PixelHostAppState();
}

class _PixelHostAppState extends State<PixelHostApp> {
  final SessionStore _sessionStore = SessionStore();
  SessionData? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await _sessionStore.loadSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _loading = false;
    });
  }

  Future<void> _handleLogin(SessionData session) async {
    await _sessionStore.saveSession(session);
    if (!mounted) return;
    setState(() => _session = session);
  }

  Future<void> _handleLogout() async {
    await _sessionStore.clearSession();
    if (!mounted) return;
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pixel Host',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D6CDF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        useMaterial3: true,
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _loading
            ? const _LoadingScreen()
            : _session == null
                ? LoginScreen(onLoggedIn: _handleLogin)
                : DashboardScreen(
                    session: _session!,
                    onLogout: _handleLogout,
                  ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}