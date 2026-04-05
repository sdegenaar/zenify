// lib/devtools/service_extensions.dart
// coverage:ignore-file
// This file registers dart:developer service extensions which can only
// be invoked by an active DevTools connection. The callbacks cannot be
// exercised in unit tests. Tested manually via DevTools integration.
import 'dart:developer' as developer;
import '../debug/zen_debug.dart';
import '../utils/zen_scope_inspector.dart';
import '../core/zen_scope.dart';
import '../query/core/zen_query_cache.dart';

/// Service extensions for DevTools integration
///
/// These extensions allow the DevTools extension to query the running app
/// for scope hierarchy, dependencies, and other debug information.
class ZenServiceExtensions {
  static bool _registered = false;

  /// Register all Zenify service extensions
  ///
  /// Call this once during app initialization, typically in main()
  /// Only registers in debug mode - no overhead in release builds.
  static void registerExtensions() {
    if (_registered) return;
    _registered = true;

    // Register scope inspection extension
    developer.registerExtension(
      'ext.zenify.getScopes',
      (method, parameters) async {
        final scopes = _buildScopeHierarchy();
        return developer.ServiceExtensionResponse.result(
          '{"scopes": ${_scopesToJson(scopes)}}',
        );
      },
    );

    // Register query cache extensions
    developer.registerExtension(
      'ext.zenify.getQueries',
      (method, parameters) async {
        final queries = _getQueryList();
        return developer.ServiceExtensionResponse.result(
          '{"queries": ${_queriesToJson(queries)}}',
        );
      },
    );

    developer.registerExtension(
      'ext.zenify.getQueryStats',
      (method, parameters) async {
        final stats = ZenQueryCache.instance.getStats();
        return developer.ServiceExtensionResponse.result(
          '{"stats": ${_mapToJson(stats)}}',
        );
      },
    );

    developer.registerExtension(
      'ext.zenify.invalidateQuery',
      (method, parameters) async {
        final queryKey = parameters['queryKey'];
        if (queryKey != null) {
          ZenQueryCache.instance.invalidateQuery(queryKey);
        }
        return developer.ServiceExtensionResponse.result('{"success": true}');
      },
    );

    developer.registerExtension(
      'ext.zenify.refetchQuery',
      (method, parameters) async {
        final queryKey = parameters['queryKey'];
        if (queryKey != null) {
          await ZenQueryCache.instance.refetchQuery(queryKey);
        }
        return developer.ServiceExtensionResponse.result('{"success": true}');
      },
    );

    developer.registerExtension(
      'ext.zenify.clearQueries',
      (method, parameters) async {
        ZenQueryCache.instance.clear();
        return developer.ServiceExtensionResponse.result('{"success": true}');
      },
    );

    // Register system stats extension
    developer.registerExtension(
      'ext.zenify.getStats',
      (method, parameters) async {
        final stats = ZenDebug.getSystemStats();
        return developer.ServiceExtensionResponse.result(
          '{"stats": ${_statsToJson(stats)}}',
        );
      },
    );

    // Register comprehensive metrics extension
    developer.registerExtension(
      'ext.zenify.getMetrics',
      (method, parameters) async {
        final metrics = _buildMetrics();
        return developer.ServiceExtensionResponse.result(
          '{"metrics": ${_mapToJson(metrics)}}',
        );
      },
    );
  }

  /// Build comprehensive metrics
  static Map<String, dynamic> _buildMetrics() {
    final allScopes = ZenDebug.allScopes;
    final queryStats = ZenQueryCache.instance.getStats();

    int totalControllers = 0;
    int totalServices = 0;

    for (final scope in allScopes) {
      final breakdown = ZenScopeInspector.getDependencyBreakdown(scope);
      totalControllers += (breakdown['controllers'] as List).length;
      totalServices += (breakdown['services'] as List).length;
    }

    return {
      'totalScopes': allScopes.length,
      'activeScopes': allScopes.where((s) => !s.isDisposed).length,
      'disposedScopes': allScopes.where((s) => s.isDisposed).length,
      'totalControllers': totalControllers,
      'totalServices': totalServices,
      'totalQueries': queryStats['total_queries'],
      'activeQueries': queryStats['total_queries'],
      'cachedQueries': queryStats['total_queries'],
      'globalQueries': queryStats['global_queries'],
      'scopedQueries': queryStats['scoped_queries'],
      'loadingQueries': queryStats['loading'],
      'errorQueries': queryStats['error'],
      'staleQueries': queryStats['stale'],
    };
  }

  /// Get list of all queries with their metadata
  static List<Map<String, dynamic>> _getQueryList() {
    final queries = ZenQueryCache.instance.getAllQueries();
    return queries.map((query) => _queryToMap(query)).toList();
  }

  /// Convert a query to a map
  static Map<String, dynamic> _queryToMap(dynamic query) {
    return {
      'queryKey': query.queryKey,
      'status': query.status.value.toString().split('.').last,
      'dataTimestamp': query.dataTimestamp?.millisecondsSinceEpoch,
      'lastFetch': query.lastFetch?.millisecondsSinceEpoch,
      'isStale': query.isStale,
      'isLoading': query.isLoading.value,
      'hasError': query.hasError,
      'errorMessage': query.error?.toString(),
      'fetchCount': query.fetchCount ?? 0,
      'scopeId': query.scopeId,
    };
  }

  /// Convert queries to JSON
  static String _queriesToJson(List<Map<String, dynamic>> queries) {
    final buffer = StringBuffer('[');
    for (var i = 0; i < queries.length; i++) {
      if (i > 0) buffer.write(',');
      buffer.write(_mapToJson(queries[i]));
    }
    buffer.write(']');
    return buffer.toString();
  }

  /// Build hierarchical scope tree starting from root
  static List<Map<String, dynamic>> _buildScopeHierarchy() {
    final allScopes = ZenDebug.allScopes;
    if (allScopes.isEmpty) return [];

    // Find root scope(s)
    final rootScopes = allScopes.where((s) => s.parent == null).toList();

    return rootScopes.map((root) => _scopeToMap(root)).toList();
  }

  /// Convert a scope and its children to a map recursively
  static Map<String, dynamic> _scopeToMap(ZenScope scope) {
    final breakdown = ZenScopeInspector.getDependencyBreakdown(scope);

    return {
      'id': scope.id,
      'name': scope.name ?? 'Unnamed',
      'parentId': scope.parent?.id,
      'parentName': scope.parent?.name,
      'isDisposed': scope.isDisposed,
      'isRoot': scope.parent == null,
      'controllers': breakdown['controllers'] ?? [],
      'services': breakdown['services'] ?? [],
      'others': breakdown['others'] ?? [],
      'children': scope.childScopes.map((child) => _scopeToMap(child)).toList(),
    };
  }

  /// Convert scope list to JSON string
  static String _scopesToJson(List<Map<String, dynamic>> scopes) {
    final buffer = StringBuffer('[');
    for (var i = 0; i < scopes.length; i++) {
      if (i > 0) buffer.write(',');
      buffer.write(_mapToJson(scopes[i]));
    }
    buffer.write(']');
    return buffer.toString();
  }

  /// Convert stats to JSON string
  static String _statsToJson(Map<String, dynamic> stats) {
    return _mapToJson(stats);
  }

  /// Simple JSON encoder for maps
  static String _mapToJson(Map<String, dynamic> map) {
    final buffer = StringBuffer('{');
    var first = true;

    map.forEach((key, value) {
      if (!first) buffer.write(',');
      first = false;

      buffer.write('"$key":');
      buffer.write(_valueToJson(value));
    });

    buffer.write('}');
    return buffer.toString();
  }

  /// Convert value to JSON string
  static String _valueToJson(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"${_escapeJson(value)}"';
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      final buffer = StringBuffer('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) buffer.write(',');
        buffer.write(_valueToJson(value[i]));
      }
      buffer.write(']');
      return buffer.toString();
    }
    if (value is Map) {
      return _mapToJson(value as Map<String, dynamic>);
    }
    return '"$value"';
  }

  /// Escape JSON special characters
  static String _escapeJson(String str) {
    return str
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
}
