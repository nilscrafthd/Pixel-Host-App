class PterodactylServer {
  const PterodactylServer({
    required this.identifier,
    required this.internalId,
    required this.uuid,
    required this.name,
    required this.node,
    required this.suspended,
    required this.installing,
    required this.limits,
    required this.allocation,
    required this.description,
  });

  final String identifier;
  final int internalId;
  final String uuid;
  final String name;
  final String node;
  final bool suspended;
  final bool installing;
  final ServerLimits limits;
  final String allocation;
  final String description;

  factory PterodactylServer.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    final relationships = attributes['relationships'] as Map<String, dynamic>? ?? const {};
    final allocations = relationships['allocations'] as Map<String, dynamic>? ?? const {};
    final limits = attributes['limits'] as Map<String, dynamic>? ?? const {};

    return PterodactylServer(
      identifier: attributes['identifier']?.toString() ?? '',
      internalId: (attributes['id'] as num?)?.toInt() ?? 0,
      uuid: attributes['uuid']?.toString() ?? '',
      name: attributes['name']?.toString() ?? 'Unknown server',
      node: attributes['node']?.toString() ?? 'Unknown node',
      suspended: attributes['is_suspended'] as bool? ?? false,
      installing: attributes['is_installing'] as bool? ?? false,
      limits: ServerLimits.fromJson(limits),
      allocation: allocations['data'] is List && (allocations['data'] as List).isNotEmpty
          ? _formatAllocation(allocations['data'] as List)
          : 'Unknown allocation',
      description: attributes['description']?.toString() ?? '',
    );
  }

  static String _formatAllocation(List<dynamic> allocations) {
    final first = allocations.first as Map<String, dynamic>? ?? const {};
    final attributes = first['attributes'] as Map<String, dynamic>? ?? const {};
    final alias = attributes['alias']?.toString();
    final ip = attributes['ip']?.toString() ?? 'unknown-ip';
    final port = attributes['port']?.toString() ?? '0000';
    if (alias != null && alias.isNotEmpty) {
      return '$alias ($ip:$port)';
    }
    return '$ip:$port';
  }
}

class ServerLimits {
  const ServerLimits({
    required this.memoryMb,
    required this.diskMb,
    required this.cpu,
    required this.swapMb,
  });

  final int memoryMb;
  final int diskMb;
  final int cpu;
  final int swapMb;

  factory ServerLimits.fromJson(Map<String, dynamic> json) {
    return ServerLimits(
      memoryMb: (json['memory'] as num?)?.toInt() ?? 0,
      diskMb: (json['disk'] as num?)?.toInt() ?? 0,
      cpu: (json['cpu'] as num?)?.toInt() ?? 0,
      swapMb: (json['swap'] as num?)?.toInt() ?? 0,
    );
  }
}
