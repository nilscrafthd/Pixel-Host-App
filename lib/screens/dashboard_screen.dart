import 'package:flutter/material.dart';

import '../models/pterodactyl_server.dart';
import '../services/pterodactyl_client.dart';
import '../services/session_store.dart';
import 'server_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.session, required this.onLogout});

  final SessionData session;
  final Future<void> Function() onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final PterodactylClient _client;
  late Future<List<PterodactylServer>> _serversFuture;

  @override
  void initState() {
    super.initState();
    _client = PterodactylClient(
      panelUrl: widget.session.panelUrl,
      apiToken: widget.session.apiToken,
    );
    _serversFuture = _loadServers();
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Future<List<PterodactylServer>> _loadServers() {
    return _client.fetchServers();
  }

  Future<void> _refresh() async {
    setState(() {
      _serversFuture = _loadServers();
    });
  }

  Future<void> _openServer(PterodactylServer server) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ServerDetailScreen(
          client: _client,
          server: server,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _serversFuture = _loadServers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servers'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          TextButton(
            onPressed: widget.onLogout,
            child: const Text('Logout'),
          ),
        ],
      ),
      body: FutureBuilder<List<PterodactylServer>>(
        future: _serversFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _EmptyState(
              title: 'Could not load servers',
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final servers = snapshot.data ?? const <PterodactylServer>[];
          if (servers.isEmpty) {
            return _EmptyState(
              title: 'No servers found',
              message: 'Your account does not currently have any visible servers.',
              onRetry: _refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final server = servers[index];
                return _ServerCard(
                  server: server,
                  onTap: () => _openServer(server),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: servers.length,
            ),
          );
        },
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.server, required this.onTap});

  final PterodactylServer server;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = server.description.isEmpty ? server.allocation : server.description;
    return Card(
      elevation: 0,
      color: const Color(0xFF111B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(server.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('$subtitle\n${server.node}'),
        ),
        isThreeLine: true,
        trailing: _StateChip(server: server),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.server});

  final PterodactylServer server;

  @override
  Widget build(BuildContext context) {
    final label = server.installing
        ? 'Installing'
        : server.suspended
            ? 'Suspended'
            : 'Ready';
    final color = server.installing
        ? Colors.orange
        : server.suspended
            ? Colors.redAccent
            : Colors.greenAccent;
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      side: BorderSide(color: color.withOpacity(0.35)),
      backgroundColor: color.withOpacity(0.12),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message, required this.onRetry});

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
