/// Data model for query cache entries
class QueryCacheData {
  final String queryKey;
  final String status;
  final DateTime? dataTimestamp;
  final DateTime? lastFetch;
  final bool isStale;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final int fetchCount;
  final String? scopeId;

  const QueryCacheData({
    required this.queryKey,
    required this.status,
    this.dataTimestamp,
    this.lastFetch,
    required this.isStale,
    required this.isLoading,
    required this.hasError,
    this.errorMessage,
    required this.fetchCount,
    this.scopeId,
  });

  factory QueryCacheData.fromJson(Map<String, dynamic> json) {
    return QueryCacheData(
      queryKey: json['queryKey'] as String,
      status: json['status'] as String,
      dataTimestamp: json['dataTimestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['dataTimestamp'] as int)
          : null,
      lastFetch: json['lastFetch'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastFetch'] as int)
          : null,
      isStale: json['isStale'] as bool? ?? false,
      isLoading: json['isLoading'] as bool? ?? false,
      hasError: json['hasError'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
      fetchCount: json['fetchCount'] as int? ?? 0,
      scopeId: json['scopeId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'queryKey': queryKey,
      'status': status,
      'dataTimestamp': dataTimestamp?.millisecondsSinceEpoch,
      'lastFetch': lastFetch?.millisecondsSinceEpoch,
      'isStale': isStale,
      'isLoading': isLoading,
      'hasError': hasError,
      'errorMessage': errorMessage,
      'fetchCount': fetchCount,
      'scopeId': scopeId,
    };
  }

  String get statusIcon {
    if (isLoading) return '⏳';
    if (hasError) return '❌';
    if (isStale) return '⚠️';
    return '✅';
  }

  String get ageString {
    if (dataTimestamp == null) return 'Never';
    final age = DateTime.now().difference(dataTimestamp!);
    if (age.inSeconds < 60) return '${age.inSeconds}s ago';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }
}

/// Summary statistics for query cache
class QueryCacheStats {
  final int totalQueries;
  final int globalQueries;
  final int scopedQueries;
  final int activeScopes;
  final int loadingQueries;
  final int successQueries;
  final int errorQueries;
  final int staleQueries;

  const QueryCacheStats({
    required this.totalQueries,
    required this.globalQueries,
    required this.scopedQueries,
    required this.activeScopes,
    required this.loadingQueries,
    required this.successQueries,
    required this.errorQueries,
    required this.staleQueries,
  });

  factory QueryCacheStats.fromJson(Map<String, dynamic> json) {
    return QueryCacheStats(
      totalQueries: json['total_queries'] as int? ?? 0,
      globalQueries: json['global_queries'] as int? ?? 0,
      scopedQueries: json['scoped_queries'] as int? ?? 0,
      activeScopes: json['active_scopes'] as int? ?? 0,
      loadingQueries: json['loading'] as int? ?? 0,
      successQueries: json['success'] as int? ?? 0,
      errorQueries: json['error'] as int? ?? 0,
      staleQueries: json['stale'] as int? ?? 0,
    );
  }
}
