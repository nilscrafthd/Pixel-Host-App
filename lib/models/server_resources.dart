class ServerResources {
  const ServerResources({
    required this.state,
    required this.memoryBytes,
    required this.cpuAbsolute,
    required this.diskBytes,
    required this.networkRxBytes,
    required this.networkTxBytes,
  });

  final String state;
  final int memoryBytes;
  final double cpuAbsolute;
  final int diskBytes;
  final int networkRxBytes;
  final int networkTxBytes;

  factory ServerResources.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    final resources = attributes['resources'] as Map<String, dynamic>? ?? const {};
    return ServerResources(
      state: attributes['current_state']?.toString() ?? 'unknown',
      memoryBytes: (resources['memory_bytes'] as num?)?.toInt() ?? 0,
      cpuAbsolute: (resources['cpu_absolute'] as num?)?.toDouble() ?? 0,
      diskBytes: (resources['disk_bytes'] as num?)?.toInt() ?? 0,
      networkRxBytes: (resources['network_rx_bytes'] as num?)?.toInt() ?? 0,
      networkTxBytes: (resources['network_tx_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}
