/// Metrics data for Zenify system monitoring
class ZenifyMetrics {
  final int totalScopes;
  final int activeScopes;
  final int disposedScopes;
  final int totalControllers;
  final int totalServices;
  final int totalQueries;
  final int activeQueries;
  final int cachedQueries;
  final int globalQueries;
  final int scopedQueries;
  final int loadingQueries;
  final int errorQueries;
  final int staleQueries;
  final MemoryMetrics? memory;

  const ZenifyMetrics({
    required this.totalScopes,
    required this.activeScopes,
    required this.disposedScopes,
    required this.totalControllers,
    required this.totalServices,
    required this.totalQueries,
    required this.activeQueries,
    required this.cachedQueries,
    required this.globalQueries,
    required this.scopedQueries,
    required this.loadingQueries,
    required this.errorQueries,
    required this.staleQueries,
    this.memory,
  });

  factory ZenifyMetrics.fromJson(Map<String, dynamic> json) {
    return ZenifyMetrics(
      totalScopes: json['totalScopes'] as int? ?? 0,
      activeScopes: json['activeScopes'] as int? ?? 0,
      disposedScopes: json['disposedScopes'] as int? ?? 0,
      totalControllers: json['totalControllers'] as int? ?? 0,
      totalServices: json['totalServices'] as int? ?? 0,
      totalQueries: json['totalQueries'] as int? ?? 0,
      activeQueries: json['activeQueries'] as int? ?? 0,
      cachedQueries: json['cachedQueries'] as int? ?? 0,
      globalQueries: json['globalQueries'] as int? ?? 0,
      scopedQueries: json['scopedQueries'] as int? ?? 0,
      loadingQueries: json['loadingQueries'] as int? ?? 0,
      errorQueries: json['errorQueries'] as int? ?? 0,
      staleQueries: json['staleQueries'] as int? ?? 0,
      memory: json['memory'] != null
          ? MemoryMetrics.fromJson(json['memory'] as Map<String, dynamic>)
          : null,
    );
  }

  int get totalDependencies => totalControllers + totalServices;
}

/// Memory usage metrics
class MemoryMetrics {
  final int currentRss;
  final int currentHeapSize;
  final int currentHeapUsed;

  const MemoryMetrics({
    required this.currentRss,
    required this.currentHeapSize,
    required this.currentHeapUsed,
  });

  factory MemoryMetrics.fromJson(Map<String, dynamic> json) {
    return MemoryMetrics(
      currentRss: json['currentRss'] as int? ?? 0,
      currentHeapSize: json['currentHeapSize'] as int? ?? 0,
      currentHeapUsed: json['currentHeapUsed'] as int? ?? 0,
    );
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
