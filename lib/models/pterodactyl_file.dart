class PterodactylFile {
  const PterodactylFile({
    required this.key,
    required this.name,
    required this.mode,
    required this.modeBits,
    required this.size,
    required this.isFile,
    required this.isSymlink,
    required this.mimetype,
    required this.createdAt,
    required this.modifiedAt,
  });

  final String key;
  final String name;
  final String mode;
  final String modeBits;
  final int size;
  final bool isFile;
  final bool isSymlink;
  final String mimetype;
  final DateTime createdAt;
  final DateTime modifiedAt;

  bool get isDirectory => !isFile;

  bool isArchiveType() {
    final lower = name.toLowerCase();
    return lower.endsWith('.zip') || lower.endsWith('.tar') || lower.endsWith('.gz') || lower.endsWith('.bz2');
  }

  bool isEditable() {
    final lower = name.toLowerCase();
    return isFile && (lower.endsWith('.txt') || lower.endsWith('.json') || lower.endsWith('.yml') || lower.endsWith('.yaml') || lower.endsWith('.php') || lower.endsWith('.js') || lower.endsWith('.ts') || lower.endsWith('.py') || lower.endsWith('.md') || lower.endsWith('.env') || lower.endsWith('.conf') || lower.endsWith('.cfg') || lower.endsWith('.xml') || lower.endsWith('.html') || lower.endsWith('.css'));
  }

  factory PterodactylFile.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    return PterodactylFile(
      key: attributes['key']?.toString() ?? attributes['name']?.toString() ?? '',
      name: attributes['name']?.toString() ?? '',
      mode: attributes['mode']?.toString() ?? '---------',
      modeBits: attributes['mode_bits']?.toString() ?? '0',
      size: (attributes['size'] as num?)?.toInt() ?? 0,
      isFile: attributes['is_file'] as bool? ?? false,
      isSymlink: attributes['is_symlink'] as bool? ?? false,
      mimetype: attributes['mimetype']?.toString() ?? '',
      createdAt: DateTime.tryParse(attributes['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      modifiedAt: DateTime.tryParse(attributes['modified_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}