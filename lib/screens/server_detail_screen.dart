import 'package:flutter/material.dart';

import '../models/pterodactyl_server.dart';
import '../models/server_resources.dart';
import '../services/pterodactyl_client.dart';

class ServerDetailScreen extends StatefulWidget {
  const ServerDetailScreen({super.key, required this.client, required this.server});

  final PterodactylClient client;
  final PterodactylServer server;

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> {
  late Future<ServerResources> _resourcesFuture;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _resourcesFuture = widget.client.fetchServerResources(widget.server.identifier);
  }

  Future<void> _refresh() async {
    setState(() {
      _resourcesFuture = widget.client.fetchServerResources(widget.server.identifier);
    });
  }

  Future<void> _sendSignal(String signal) async {
    setState(() {
      _actionInProgress = true;
    });

    try {
      await widget.client.sendPowerSignal(widget.server.identifier, signal);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent $signal signal to ${widget.server.name}')),
      );
    } on PterodactylApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.server.name),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<ServerResources>(
        future: _resourcesFuture,
        builder: (context, snapshot) {
          final resources = snapshot.data;
          final hasError = snapshot.hasError;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(server: widget.server, resources: resources, hasError: hasError),
              const SizedBox(height: 16),
              if (hasError)
                _ErrorCard(
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                )
              else if (resources != null) ...[
                _MetricCard(
                  title: 'Memory',
                  value: _formatBytes(resources.memoryBytes),
                  subtitle: resources.state,
                ),
                const SizedBox(height: 12),
                _MetricCard(
                  title: 'CPU',
                  value: '${resources.cpuAbsolute.toStringAsFixed(1)}%',
                  subtitle: 'Live usage',
                ),
                const SizedBox(height: 12),
                _MetricCard(
                  title: 'Disk',
                  value: _formatBytes(resources.diskBytes),
                  subtitle: 'Current usage',
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: _actionInProgress ? null : () => _sendSignal('start'),
                    child: const Text('Start'),
                  ),
                  FilledButton.tonal(
                    onPressed: _actionInProgress ? null : () => _sendSignal('restart'),
                    child: const Text('Restart'),
                  ),
                  OutlinedButton(
                    onPressed: _actionInProgress ? null : () => _sendSignal('stop'),
                    child: const Text('Stop'),
                  ),
                  TextButton(
                    onPressed: _actionInProgress ? null : () => _sendSignal('kill'),
                    child: const Text('Kill'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.server, required this.resources, required this.hasError});

  final PterodactylServer server;
  final ServerResources? resources;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final state = resources?.state ?? (hasError ? 'error' : 'loading');
    return Card(
      elevation: 0,
      color: const Color(0xFF111B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(server.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(server.description.isEmpty ? server.identifier : server.description),
            const SizedBox(height: 16),
            _KeyValue(label: 'Identifier', value: server.identifier),
            _KeyValue(label: 'Node', value: server.node),
            _KeyValue(label: 'Status', value: state),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.subtitle});

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF111B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            Text(subtitle, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF351B24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Failed to load resources', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.white70))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < suffixes.length - 1) {
    value /= 1024;
    index++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${suffixes[index]}';
}
