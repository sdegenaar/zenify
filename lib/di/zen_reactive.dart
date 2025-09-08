// lib/di/zen_reactive.dart
import 'package:flutter/widgets.dart';
import 'package:zenify/di/zen_di.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';

/// Enhanced subscription with automatic cleanup and state tracking
class ZenSubscription {
  final VoidCallback _dispose;
  bool _isDisposed = false;

  ZenSubscription(this._dispose);

  /// Close the subscription and clean up resources
  void close() {
    if (!_isDisposed) {
      _dispose();
      _isDisposed = true;
    }
  }

  /// Check if subscription is disposed
  bool get isDisposed => _isDisposed;

  /// Dispose when not needed anymore (alias for close)
  void dispose() => close();
}

/// Production-ready reactive system for the DI container
class ZenReactiveSystem {
  // Singleton instance
  static final ZenReactiveSystem instance = ZenReactiveSystem._();

  // Private constructor
  ZenReactiveSystem._();

  // Core listener storage
  final Map<dynamic, Set<VoidCallback>> _listeners = {};

  // Memory management constants
  static const int _maxTotalListeners = 1000;
  static const int _maxListenersPerKey = 50;
  static const int _cleanupThreshold = 100;

  // Performance tracking
  int _notificationCount = 0;
  int _errorCount = 0;
  DateTime? _lastCleanup;

  /// Optimized listener notification with memory safety
  void notifyListeners<T>(String? tag) {
    final key = _getKey(T, tag);
    final listenerSet = _listeners[key];

    // Early return for empty cases - zero allocations
    if (listenerSet == null || listenerSet.isEmpty) return;

    _notificationCount++;

    // Single listener optimization - no iteration overhead
    if (listenerSet.length == 1) {
      _safeNotify(listenerSet.first, T);
      return;
    }

    // Multiple listeners - direct Set iteration (no toList())
    for (final listener in listenerSet) {
      _safeNotify(listener, T);
    }

    // Periodic cleanup check
    if (_notificationCount % _cleanupThreshold == 0) {
      _performMaintenanceCheck();
    }
  }

  /// Safe notification with comprehensive error handling
  void _safeNotify(VoidCallback listener, Type type) {
    try {
      listener();
    } catch (e, stack) {
      _errorCount++;
      ZenLogger.logError('Error notifying listener for $type', e, stack);

      // Consider removing problematic listeners in production
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logWarning(
            'Consider checking listener implementation for $type');
      }
    }
  }

  /// Enhanced listen with comprehensive memory protection
  ZenSubscription listen<T>(
    dynamic provider,
    void Function(T) listener,
  ) {
    // Memory protection - prevent runaway subscriptions
    _checkMemoryPressure();

    final Type type = T;
    final String? tag = _extractTag(provider);
    final key = _getKey(type, tag);

    // Validate listener count per key
    final existingListeners = _listeners[key];
    if (existingListeners != null &&
        existingListeners.length >= _maxListenersPerKey) {
      ZenLogger.logWarning(
          'High listener count (${existingListeners.length}) for $type:$tag. Potential memory leak?');
    }

    _listeners.putIfAbsent(key, () => <VoidCallback>{});

    // Create resilient callback using findOrNull to avoid exceptions
    void callback() {
      try {
        final instance = Zen.findOrNull<T>(tag: tag);
        if (instance != null) {
          listener(instance);
        }
      } catch (e, stack) {
        _errorCount++;
        ZenLogger.logError('Error in listener callback for $T', e, stack);
      }
    }

    _listeners[key]!.add(callback);

    // Safe initial notification
    final current = Zen.findOrNull<T>(tag: tag);
    if (current != null) {
      try {
        listener(current);
      } catch (e, stack) {
        _errorCount++;
        ZenLogger.logError('Error in initial listener call for $T', e, stack);
      }
    }

    // Return enhanced subscription with cleanup tracking
    return ZenSubscription(() {
      final listenerSet = _listeners[key];
      if (listenerSet != null) {
        listenerSet.remove(callback);

        // Automatic cleanup of empty listener sets
        if (listenerSet.isEmpty) {
          _listeners.remove(key);
        }
      }
    });
  }

  /// Memory pressure monitoring and protection
  void _checkMemoryPressure() {
    final stats = getMemoryStats();
    final totalListeners = stats['totalListeners'] as int;

    if (totalListeners > _maxTotalListeners) {
      ZenLogger.logWarning(
          'HIGH MEMORY PRESSURE: $totalListeners total listeners. '
          'Max recommended: $_maxTotalListeners. Check for memory leaks!');

      // Force cleanup
      _cleanupEmptyListeners();

      // Log detailed statistics for debugging
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Memory stats: $stats');
      }
    }
  }

  /// Perform periodic maintenance
  void _performMaintenanceCheck() {
    final now = DateTime.now();

    // Only run cleanup every minute to avoid performance impact
    if (_lastCleanup == null || now.difference(_lastCleanup!).inMinutes >= 1) {
      _cleanupEmptyListeners();
      _lastCleanup = now;

      if (ZenConfig.enableDebugLogs) {
        final stats = getMemoryStats();
        ZenLogger.logDebug(
            'Reactive system stats: $stats, errors: $_errorCount');
      }
    }
  }

  /// Remove empty listener sets to prevent memory leaks
  void _cleanupEmptyListeners() {
    final removedCount = _listeners.length;
    _listeners.removeWhere((key, listeners) => listeners.isEmpty);
    final finalCount = _listeners.length;

    if (removedCount != finalCount && ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug(
          'Cleaned up ${removedCount - finalCount} empty listener sets');
    }
  }

  /// Comprehensive memory and performance statistics
  Map<String, dynamic> getMemoryStats() {
    final totalListeners = _listeners.values.fold<int>(
      0,
      (sum, set) => sum + set.length,
    );

    final listenerCounts = _listeners.values.map((set) => set.length).toList()
      ..sort();
    final maxListeners = listenerCounts.isEmpty ? 0 : listenerCounts.last;
    final avgListeners =
        _listeners.isEmpty ? 0.0 : totalListeners / _listeners.length;

    return {
      'totalKeys': _listeners.length,
      'totalListeners': totalListeners,
      'maxListenersPerKey': maxListeners,
      'averageListenersPerKey': avgListeners.toStringAsFixed(1),
      'emptyKeys': _listeners.values.where((set) => set.isEmpty).length,
      'notificationCount': _notificationCount,
      'errorCount': _errorCount,
      'memoryPressure': totalListeners > _maxTotalListeners
          ? 'HIGH'
          : totalListeners > (_maxTotalListeners * 0.7)
              ? 'MEDIUM'
              : 'LOW',
      'lastCleanup': _lastCleanup?.toIso8601String() ?? 'never',
    };
  }

  /// Get health status for monitoring
  Map<String, dynamic> getHealthStatus() {
    final stats = getMemoryStats();
    final errorRate =
        _notificationCount == 0 ? 0.0 : _errorCount / _notificationCount;

    return {
      'status': _getHealthLevel(stats, errorRate),
      'memoryPressure': stats['memoryPressure'],
      'errorRate': '${(errorRate * 100).toStringAsFixed(2)}%',
      'recommendations': _getRecommendations(stats, errorRate),
    };
  }

  String _getHealthLevel(Map<String, dynamic> stats, double errorRate) {
    if (stats['memoryPressure'] == 'HIGH' || errorRate > 0.1) return 'CRITICAL';
    if (stats['memoryPressure'] == 'MEDIUM' || errorRate > 0.05) {
      return 'WARNING';
    }
    return 'HEALTHY';
  }

  List<String> _getRecommendations(
      Map<String, dynamic> stats, double errorRate) {
    final recommendations = <String>[];

    if (stats['memoryPressure'] == 'HIGH') {
      recommendations.add('Reduce number of active listeners');
      recommendations.add('Check for subscription leaks');
    }

    if (errorRate > 0.05) {
      recommendations.add('Review listener implementations for error handling');
    }

    final maxListeners = stats['maxListenersPerKey'] as int;
    if (maxListeners > _maxListenersPerKey) {
      recommendations.add('Consider reducing listeners per dependency type');
    }

    return recommendations;
  }

  /// Clear all listeners with logging
  void clearListeners() {
    final count =
        _listeners.values.fold<int>(0, (sum, set) => sum + set.length);
    _listeners.clear();
    _notificationCount = 0;
    _errorCount = 0;
    _lastCleanup = null;

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('Cleared $count listeners from reactive system');
    }
  }

  /// Force cleanup for testing/debugging
  void forceCleanup() {
    _cleanupEmptyListeners();
    _performMaintenanceCheck();
  }

  /// Extract tag from a provider (for compatibility with previous API)
  String? _extractTag(dynamic provider) {
    if (provider is Type) return null;

    if (provider is String && provider.contains(':')) {
      return provider.split(':').last;
    }

    return null;
  }

  /// Get a key for associating listeners with types and tags
  dynamic _getKey(Type type, String? tag) {
    return tag != null ? '$type:$tag' : type;
  }

  /// Debug method to dump current listener state
  String dumpListeners() {
    if (_listeners.isEmpty) return 'No active listeners';

    final buffer = StringBuffer();
    buffer.writeln('=== REACTIVE SYSTEM STATE ===');
    buffer.writeln('Total listener groups: ${_listeners.length}');

    for (final entry in _listeners.entries) {
      buffer.writeln('${entry.key}: ${entry.value.length} listeners');
    }

    final stats = getMemoryStats();
    buffer.writeln('\nStatistics: $stats');

    return buffer.toString();
  }
}
