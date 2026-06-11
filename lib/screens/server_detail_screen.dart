import 'package:flutter/material.dart';

import '../models/pterodactyl_server.dart';
import '../models/server_resources.dart';
import '../services/pterodactyl_client.dart';
import 'server_console_view.dart';
import 'server_file_manager_view.dart';

enum ServerSection { overview, console, files, actions }

class ServerDetailScreen extends StatefulWidget {
  const ServerDetailScreen({super.key, required this.client, required this.server});

  final PterodactylClient client;
  final PterodactylServer server;

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> {
  late Future<ServerResources> _resourcesFuture;
  ServerSection _section = ServerSection.overview;

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
    try {
      await widget.client.sendPowerSignal(widget.server.identifier, signal);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$signal sent to ${widget.server.name}')));
    } on PterodactylApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _renameServer() async {
    final nameController = TextEditingController(text: widget.server.name);
    final descriptionController = TextEditingController(text: widget.server.description);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.client.renameServer(
        widget.server.identifier,
        nameController.text.trim(),
        description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
      );
      await _refresh();
    }

    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _reinstallServer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reinstall server'),
        content: const Text('This will rebuild the server. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reinstall')),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.client.reinstallServer(widget.server.identifier);
      await _refresh();
    }
  }

  Widget _buildSectionSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 0,
        color: const Color(0xFF111B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ServerSection>(
                  value: _section,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: const [
                    DropdownMenuItem(value: ServerSection.overview, child: Text('Overview')),
                    DropdownMenuItem(value: ServerSection.console, child: Text('Console')),
                    DropdownMenuItem(value: ServerSection.files, child: Text('File Manager')),
                    DropdownMenuItem(value: ServerSection.actions, child: Text('Actions')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _section = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.server.description.isEmpty ? widget.server.identifier : widget.server.description,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverview(ServerResources? resources, Object? error) {
    final hasError = error != null;
    final state = resources?.state ?? (hasError ? 'error' : 'loading');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeaderCard(server: widget.server, status: state),
        const SizedBox(height: 16),
        if (hasError)
          _ErrorCard(message: error.toString(), onRetry: _refresh)
        else if (resources != null) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(title: 'Memory', value: _formatBytes(resources.memoryBytes), subtitle: state),
              _MetricCard(title: 'CPU', value: '${resources.cpuAbsolute.toStringAsFixed(1)}%', subtitle: 'Live usage'),
              _MetricCard(title: 'Disk', value: _formatBytes(resources.diskBytes), subtitle: 'Current usage'),
              _MetricCard(title: 'Network RX', value: _formatBytes(resources.networkRxBytes), subtitle: 'Received'),
              _MetricCard(title: 'Network TX', value: _formatBytes(resources.networkTxBytes), subtitle: 'Sent'),
            ],
          ),
          const SizedBox(height: 16),
          _QuickActionCard(
            onStart: () => _sendSignal('start'),
            onRestart: () => _sendSignal('restart'),
            onStop: () => _sendSignal('stop'),
            onKill: () => _sendSignal('kill'),
            onReinstall: _reinstallServer,
            onRename: _renameServer,
          ),
        ],
      ],
    );
  }

  Widget _buildActions(ServerResources? resources, Object? error) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeaderCard(server: widget.server, status: resources?.state ?? (error != null ? 'error' : 'loading')),
        const SizedBox(height: 16),
        _QuickActionCard(
          onStart: () => _sendSignal('start'),
          onRestart: () => _sendSignal('restart'),
          onStop: () => _sendSignal('stop'),
          onKill: () => _sendSignal('kill'),
          onReinstall: _reinstallServer,
          onRename: _renameServer,
        ),
        const SizedBox(height: 16),
        if (error != null) _ErrorCard(message: error.toString(), onRetry: _refresh),
        if (resources != null) ...[
          _MetricCard(title: 'Status', value: resources.state, subtitle: 'Server state'),
          const SizedBox(height: 12),
          _MetricCard(title: 'Identifier', value: widget.server.identifier, subtitle: 'Client ID'),
          const SizedBox(height: 12),
          _MetricCard(title: 'Allocation', value: widget.server.allocation, subtitle: widget.server.node),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.server.name),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
          PopupMenuButton<ServerSection>(
            icon: const Icon(Icons.view_list),
            onSelected: (section) => setState(() => _section = section),
            itemBuilder: (context) => const [
              PopupMenuItem(value: ServerSection.overview, child: Text('Overview')),
              PopupMenuItem(value: ServerSection.console, child: Text('Console')),
              PopupMenuItem(value: ServerSection.files, child: Text('File Manager')),
              PopupMenuItem(value: ServerSection.actions, child: Text('Actions')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<ServerResources>(
        future: _resourcesFuture,
        builder: (context, snapshot) {
          final resources = snapshot.data;
          final error = snapshot.error;

          return Column(
            children: [
              _buildSectionSelector(),
              const SizedBox(height: 16),
              Expanded(
                child: switch (_section) {
                  ServerSection.overview => _buildOverview(resources, error),
                  ServerSection.console => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ServerConsoleView(client: widget.client, server: widget.server),
                    ),
                  ServerSection.files => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ServerFileManagerView(client: widget.client, server: widget.server),
                    ),
                  ServerSection.actions => _buildActions(resources, error),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.server, required this.status});

  final PterodactylServer server;
  final String status;

  @override
  Widget build(BuildContext context) {
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
            _KeyValue(label: 'Status', value: status),
            _KeyValue(label: 'Allocation', value: server.allocation),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.onStart,
    required this.onRestart,
    required this.onStop,
    required this.onKill,
    required this.onReinstall,
    required this.onRename,
  });

  final VoidCallback onStart;
  final VoidCallback onRestart;
  final VoidCallback onStop;
  final VoidCallback onKill;
  final VoidCallback onReinstall;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF111B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ActionButton(
              label: 'Start',
              onPressed: onStart,
              backgroundColor: const Color(0xFF1F8A5B),
              foregroundColor: Colors.white,
            ),
            _ActionButton(
              label: 'Restart',
              onPressed: onRestart,
              backgroundColor: const Color(0xFFB9770E),
              foregroundColor: Colors.white,
            ),
            _ActionButton(
              label: 'Stop',
              onPressed: onStop,
              backgroundColor: const Color(0xFFD64545),
              foregroundColor: Colors.white,
            ),
            _ActionButton(
              label: 'Kill',
              onPressed: onKill,
              backgroundColor: const Color(0xFFB23A2F),
              foregroundColor: Colors.white,
            ),
            _ActionButton(
              label: 'Reinstall',
              onPressed: onReinstall,
              backgroundColor: const Color(0xFF356AE6),
              foregroundColor: Colors.white,
            ),
            _ActionButton(
              label: 'Rename',
              onPressed: onRename,
              backgroundColor: const Color(0xFF41506B),
              foregroundColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      onPressed: onPressed,
      child: Text(label),
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
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        color: const Color(0xFF111B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Colors.white54)),
            ],
          ),
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
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white70))),
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
