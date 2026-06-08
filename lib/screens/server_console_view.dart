import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/pterodactyl_server.dart';
import '../services/pterodactyl_client.dart';

class ServerConsoleView extends StatefulWidget {
  const ServerConsoleView({super.key, required this.client, required this.server});

  final PterodactylClient client;
  final PterodactylServer server;

  @override
  State<ServerConsoleView> createState() => _ServerConsoleViewState();
}

class _ServerConsoleViewState extends State<ServerConsoleView> {
  final TextEditingController _commandController = TextEditingController();
  final List<String> _logs = <String>[];
  WebSocketTicket? _ticket;
  StreamSubscription? _subscription;
  dynamic _channel;
  bool _connecting = true;
  bool _sending = false;
  String? _error;
  String _status = 'unknown';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {
      // Ignore shutdown issues.
    }
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
      _logs.clear();
    });

    try {
      final ticket = await widget.client.getWebsocketTicket(widget.server.identifier);
      _ticket = ticket;
      final channel = widget.client.connectWebsocket(ticket.socket);
      _channel = channel;

      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = error.toString();
          });
        },
        onDone: () {
          if (!mounted) {
            return;
          }
          setState(() {
            _status = 'disconnected';
          });
        },
      );

      channel.sink.add(jsonEncode(<String, dynamic>{
        'event': 'auth',
        'args': <String>[ticket.token],
      }));
      channel.sink.add(jsonEncode(<String, dynamic>{'event': 'send logs', 'args': <String>[] }));
      channel.sink.add(jsonEncode(<String, dynamic>{'event': 'send stats', 'args': <String>[] }));

      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _status = 'connected';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _error = error.toString();
      });
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data as String) as Map<String, dynamic>;
      final event = decoded['event']?.toString();
      final args = decoded['args'];

      if (event == 'console output' && args is List && args.isNotEmpty) {
        final line = args.map((value) => value.toString()).join('');
        if (!mounted) {
          return;
        }
        setState(() {
          _logs.add(line.trimRight());
        });
      }

      if (event == 'status' && args is List && args.isNotEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _status = args.first.toString();
        });
      }
    } catch (_) {
      // Ignore malformed websocket frames.
    }
  }

  Future<void> _sendCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.client.sendCommand(widget.server.identifier, command);
      if (!mounted) {
        return;
      }
      setState(() {
        _logs.add('> $command');
        _commandController.clear();
      });
    } on PterodactylApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConsoleHeader(
          server: widget.server,
          status: _status,
          onReconnect: _connect,
          connecting: _connecting,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            elevation: 0,
            color: const Color(0xFF09101D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _error != null
                  ? _ConsoleError(message: _error!, onRetry: _connect)
                  : ListView.builder(
                      itemCount: _logs.isEmpty ? 1 : _logs.length,
                      itemBuilder: (context, index) {
                        if (_logs.isEmpty) {
                          return const Text('Console output will appear here once the websocket is connected.', style: TextStyle(color: Colors.white54));
                        }
                        final line = _logs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: SelectableText(
                            line,
                            style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: const Color(0xFF111B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    onSubmitted: (_) => _sendCommand(),
                    decoration: const InputDecoration(
                      labelText: 'Command',
                      hintText: 'say hello world',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _sending ? null : _sendCommand,
                  child: _sending ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConsoleHeader extends StatelessWidget {
  const _ConsoleHeader({
    required this.server,
    required this.status,
    required this.onReconnect,
    required this.connecting,
  });

  final PterodactylServer server;
  final String status;
  final VoidCallback onReconnect;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF111B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(server.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Console connection: $status', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: connecting ? null : onReconnect,
              child: const Text('Reconnect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsoleError extends StatelessWidget {
  const _ConsoleError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
