import 'package:flutter/material.dart';

import '../models/pterodactyl_file.dart';
import '../models/pterodactyl_server.dart';
import '../services/pterodactyl_client.dart';

class ServerFileManagerView extends StatefulWidget {
  const ServerFileManagerView({super.key, required this.client, required this.server});

  final PterodactylClient client;
  final PterodactylServer server;

  @override
  State<ServerFileManagerView> createState() => _ServerFileManagerViewState();
}

class _ServerFileManagerViewState extends State<ServerFileManagerView> {
  final TextEditingController _pathController = TextEditingController(text: '/');
  final Set<String> _selected = <String>{};
  List<PterodactylFile> _files = <PterodactylFile>[];
  bool _loading = true;
  String? _error;
  String _currentDirectory = '/';

  @override
  void initState() {
    super.initState();
    _loadDirectory('/');
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory(String directory) async {
    final normalized = _normalizePath(directory);
    setState(() {
      _loading = true;
      _error = null;
      _currentDirectory = normalized;
      _pathController.text = normalized;
      _selected.clear();
    });

    try {
      final files = await widget.client.loadDirectory(widget.server.identifier, normalized);
      if (!mounted) {
        return;
      }
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refresh() => _loadDirectory(_currentDirectory);

  String _normalizePath(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty || trimmed == '/') {
      return '/';
    }
    var path = trimmed.replaceAll('\\', '/');
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    while (path.contains('//')) {
      path = path.replaceAll('//', '/');
    }
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  String _joinPath(String root, String child) {
    final normalizedRoot = _normalizePath(root);
    final normalizedChild = child.trim().replaceAll('\\', '/');
    if (normalizedRoot == '/') {
      return '/$normalizedChild';
    }
    return '$normalizedRoot/$normalizedChild';
  }

  String _parentPath(String path) {
    final normalized = _normalizePath(path);
    if (normalized == '/') {
      return '/';
    }
    final segments = normalized.split('/')..removeWhere((segment) => segment.isEmpty);
    if (segments.length <= 1) {
      return '/';
    }
    return '/${segments.sublist(0, segments.length - 1).join('/')}';
  }

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, nameController.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    nameController.dispose();

    if (name == null || name.isEmpty) {
      return;
    }

    await widget.client.createDirectory(widget.server.identifier, _currentDirectory, name);
    await _refresh();
  }

  Future<void> _renameSingle(PterodactylFile file) async {
    final controller = TextEditingController(text: file.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file.isDirectory ? 'Rename folder' : 'Rename file'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'New name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || name == file.name) {
      return;
    }

    await widget.client.renameFiles(widget.server.identifier, _currentDirectory, [
      <String, String>{'from': file.name, 'to': name},
    ]);
    await _refresh();
  }

  Future<void> _moveSelected() async {
    if (_selected.isEmpty) return;
    final controller = TextEditingController(text: _currentDirectory);
    final destination = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move selected files'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Destination path')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Move')),
        ],
      ),
    );
    controller.dispose();

    if (destination == null || destination.isEmpty) {
      return;
    }

    await widget.client.renameFiles(
      widget.server.identifier,
      _currentDirectory,
      _selected.map((file) => <String, String>{'from': file, 'to': _joinPath(destination, file)}).toList(growable: false),
    );
    await _refresh();
  }

  Future<void> _chmodSelected() async {
    if (_selected.isEmpty) return;
    final controller = TextEditingController(text: '644');
    final mode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change permissions'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Mode, e.g. 644 or 755')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Apply')),
        ],
      ),
    );
    controller.dispose();

    if (mode == null || mode.isEmpty) {
      return;
    }

    await widget.client.chmodFiles(
      widget.server.identifier,
      _currentDirectory,
      _selected.map((file) => <String, String>{'file': file, 'mode': mode}).toList(growable: false),
    );
    await _refresh();
  }

  Future<void> _archiveSelected() async {
    if (_selected.isEmpty) return;
    await widget.client.compressFiles(widget.server.identifier, _currentDirectory, _selected.toList(growable: false));
    await _refresh();
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected files'),
        content: Text('Delete ${_selected.length} selected entries?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await widget.client.deleteFiles(widget.server.identifier, _currentDirectory, _selected.toList(growable: false));
    await _refresh();
  }

  Future<void> _toggleOpen(PterodactylFile file) async {
    if (file.isDirectory) {
      await _loadDirectory(_joinPath(_currentDirectory, file.name));
      return;
    }
    if (file.isEditable()) {
      await _editFile(file);
      return;
    }
    final url = await widget.client.getFileDownloadUrl(widget.server.identifier, _joinPath(_currentDirectory, file.name));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url.isEmpty ? 'Download URL not available.' : url)));
  }

  Future<void> _downloadFile(PterodactylFile file) async {
    final url = await widget.client.getFileDownloadUrl(widget.server.identifier, _joinPath(_currentDirectory, file.name));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url.isEmpty ? 'Download URL not available.' : url)));
  }

  Future<void> _editFile(PterodactylFile file) async {
    final filePath = _joinPath(_currentDirectory, file.name);
    final controller = TextEditingController();
    String? error;

    try {
      controller.text = await widget.client.getFileContents(widget.server.identifier, filePath);
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) {
      controller.dispose();
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${file.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                maxLines: 14,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close')),
          FilledButton(onPressed: error == null ? () => Navigator.pop(context, true) : null, child: const Text('Save')),
        ],
      ),
    );

    if (saved == true) {
      await widget.client.saveFileContents(widget.server.identifier, filePath, controller.text);
      await _refresh();
    }

    controller.dispose();
  }

  Future<void> _bulkMenuAction(String value) async {
    switch (value) {
      case 'select_all':
        setState(() {
          _selected
            ..clear()
            ..addAll(_files.where((file) => file.isFile || file.isDirectory).map((file) => file.name));
        });
        break;
      case 'clear':
        setState(_selected.clear);
        break;
      case 'refresh':
        await _refresh();
        break;
      case 'new_folder':
        await _createFolder();
        break;
      case 'delete':
        await _deleteSelected();
        break;
      case 'archive':
        await _archiveSelected();
        break;
      case 'move':
        await _moveSelected();
        break;
      case 'chmod':
        await _chmodSelected();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          color: const Color(0xFF111B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pathController,
                        onSubmitted: _loadDirectory,
                        decoration: const InputDecoration(labelText: 'Path'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: () => _loadDirectory(_pathController.text), child: const Text('Open')),
                    const SizedBox(width: 8),
                    FilledButton.tonal(onPressed: _refresh, child: const Text('Refresh')),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Current: $_currentDirectory', style: const TextStyle(color: Colors.white70)),
                    TextButton(onPressed: _currentDirectory == '/' ? null : () => _loadDirectory(_parentPath(_currentDirectory)), child: const Text('Up')),
                    TextButton(onPressed: _createFolder, child: const Text('New Folder')),
                    PopupMenuButton<String>(
                      tooltip: 'More actions',
                      onSelected: _bulkMenuAction,
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'select_all', child: Text('Select all')),
                        PopupMenuItem(value: 'clear', child: Text('Clear selection')),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'new_folder', child: Text('New folder')),
                        PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'move', child: Text('Move selected')),
                        PopupMenuItem(value: 'chmod', child: Text('Permissions')),
                        PopupMenuItem(value: 'archive', child: Text('Archive selected')),
                        PopupMenuItem(value: 'delete', child: Text('Delete selected')),
                      ],
                    ),
                    if (_selected.isNotEmpty)
                      Chip(label: Text('${_selected.length} selected')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _FileError(message: _error!, onRetry: _refresh)
                  : Card(
                      elevation: 0,
                      color: const Color(0xFF09101D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _files.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white12),
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          final isSelected = _selected.contains(file.name);
                          return _FileRow(
                            file: file,
                            selected: isSelected,
                            onSelectedChanged: (value) {
                              setState(() {
                                if (value) {
                                  _selected.add(file.name);
                                } else {
                                  _selected.remove(file.name);
                                }
                              });
                            },
                            onOpen: () => _toggleOpen(file),
                            onRename: () => _renameSingle(file),
                            onDelete: () async {
                              await widget.client.deleteFiles(widget.server.identifier, _currentDirectory, [file.name]);
                              await _refresh();
                            },
                            onArchive: file.isArchiveType()
                                ? () async {
                                    await widget.client.decompressFile(widget.server.identifier, _currentDirectory, file.name);
                                    await _refresh();
                                  }
                                : () async {
                                    await widget.client.compressFiles(widget.server.identifier, _currentDirectory, [file.name]);
                                    await _refresh();
                                  },
                            onCopy: file.isFile
                                ? () async {
                                    await widget.client.copyFile(widget.server.identifier, _joinPath(_currentDirectory, file.name));
                                    await _refresh();
                                  }
                                : null,
                            onDownload: file.isFile ? () => _downloadFile(file) : null,
                            onPermissions: () async {
                              final controller = TextEditingController(text: '644');
                              final mode = await showDialog<String>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Permissions: ${file.name}'),
                                  content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Mode')),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Apply')),
                                  ],
                                ),
                              );
                              controller.dispose();
                              if (mode == null || mode.isEmpty) return;
                              await widget.client.chmodFiles(widget.server.identifier, _currentDirectory, [
                                <String, String>{'file': file.name, 'mode': mode},
                              ]);
                              await _refresh();
                            },
                          );
                        },
                      ),
                    ),
        ),
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(onPressed: _deleteSelected, child: const Text('Delete selected')),
                FilledButton.tonal(onPressed: _archiveSelected, child: const Text('Archive selected')),
                OutlinedButton(onPressed: _moveSelected, child: const Text('Move selected')),
                TextButton(onPressed: _chmodSelected, child: const Text('Permissions')),
              ],
            ),
          ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.selected,
    required this.onSelectedChanged,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onArchive,
    required this.onCopy,
    required this.onPermissions,
    required this.onDownload,
  });

  final PterodactylFile file;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback? onCopy;
  final VoidCallback onPermissions;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final icon = file.isDirectory ? Icons.folder : Icons.description;
    return ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Checkbox(value: selected, onChanged: (value) => onSelectedChanged(value ?? false)),
      title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${file.modeBits} • ${_formatBytes(file.size)} • ${_formatShortDate(file.modifiedAt)}'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'open':
              onOpen();
              break;
            case 'rename':
              onRename();
              break;
            case 'copy':
              onCopy?.call();
              break;
            case 'download':
              onDownload?.call();
              break;
            case 'permissions':
              onPermissions();
              break;
            case 'archive':
              onArchive();
              break;
            case 'delete':
              onDelete();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'open', child: Text('Open')),
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
          if (onCopy != null) const PopupMenuItem(value: 'copy', child: Text('Copy')),
          if (onDownload != null) const PopupMenuItem(value: 'download', child: Text('Download')),
          const PopupMenuItem(value: 'permissions', child: Text('Permissions')),
          PopupMenuItem(value: 'archive', child: Text(file.isArchiveType() ? 'Unarchive' : 'Archive')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
        child: Icon(icon, color: Colors.white70),
      ),
    );
  }
}

class _FileError extends StatelessWidget {
  const _FileError({required this.message, required this.onRetry});

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

String _formatShortDate(DateTime dateTime) {
  if (dateTime.millisecondsSinceEpoch == 0) {
    return '-';
  }
  return '${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
}
