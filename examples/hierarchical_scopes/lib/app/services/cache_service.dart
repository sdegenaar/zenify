import 'dart:async';

import 'package:zenify/zenify.dart';

/// Cache service for storing and retrieving data
/// Demonstrates a service that can be shared across hierarchical scopes
class CacheService {
  final _cache = <String, CacheEntry>{};
  final _cacheHits = 0.obs();
  final _cacheMisses = 0.obs();
  final _cacheSize = 0.obs();
  final _cacheStats = RxMap<String, dynamic>({});
  final _cleanupTimer = Rx<Timer?>(null);

  // Reactive getters
  Rx<int> get cacheHits => _cacheHits;
  Rx<int> get cacheMisses => _cacheMisses;
  Rx<int> get cacheSize => _cacheSize;
  RxMap<String, dynamic> get cacheStats => _cacheStats;

  CacheService() {
    // Start periodic cleanup
    _startCleanupTimer();
    _updateStats();
  }

  /// Get a value from the cache
  T? get<T>(String key) {
    final entry = _cache[key];
    
    if (entry == null || entry.isExpired) {
      _cacheMisses.value++;
      _updateStats();
      
      // Remove expired entry if it exists
      if (entry != null && entry.isExpired) {
        _cache.remove(key);
        _cacheSize.value = _cache.length;
      }
      
      return null;
    }
    
    _cacheHits.value++;
    entry.lastAccessed = DateTime.now();
    _updateStats();
    
    return entry.value as T?;
  }

  /// Set a value in the cache with optional TTL
  void set<T>(String key, T value, {Duration? ttl}) {
    final entry = CacheEntry(
      value: value,
      created: DateTime.now(),
      lastAccessed: DateTime.now(),
      ttl: ttl,
    );
    
    _cache[key] = entry;
    _cacheSize.value = _cache.length;
    _updateStats();
    
    ZenLogger.logInfo('Cache: Set "$key" with TTL ${ttl?.inSeconds ?? 'infinite'} seconds');
  }

  /// Check if a key exists in the cache and is not expired
  bool has(String key) {
    final entry = _cache[key];
    return entry != null && !entry.isExpired;
  }

  /// Remove a value from the cache
  void remove(String key) {
    _cache.remove(key);
    _cacheSize.value = _cache.length;
    _updateStats();
    
    ZenLogger.logInfo('Cache: Removed "$key"');
  }

  /// Clear all values from the cache
  void clear() {
    _cache.clear();
    _cacheSize.value = 0;
    _updateStats();
    
    ZenLogger.logInfo('Cache: Cleared all entries');
  }

  /// Get all keys in the cache
  List<String> keys() {
    return _cache.keys.toList();
  }

  /// Get all entries in the cache
  Map<String, dynamic> entries() {
    final result = <String, dynamic>{};
    
    _cache.forEach((key, entry) {
      if (!entry.isExpired) {
        result[key] = entry.value;
      }
    });
    
    return result;
  }

  /// Start the cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer.value = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupExpiredEntries();
    });
  }

  /// Cleanup expired entries
  void _cleanupExpiredEntries() {
    final expiredKeys = <String>[];
    
    _cache.forEach((key, entry) {
      if (entry.isExpired) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      _cacheSize.value = _cache.length;
      _updateStats();
      
      ZenLogger.logInfo('Cache: Cleaned up ${expiredKeys.length} expired entries');
    }
  }

  /// Update cache statistics
  void _updateStats() {
    final now = DateTime.now();
    final oldestEntry = _cache.values.isEmpty
        ? null
        : _cache.values.reduce((a, b) => a.created.isBefore(b.created) ? a : b);
    final newestEntry = _cache.values.isEmpty
        ? null
        : _cache.values.reduce((a, b) => a.created.isAfter(b.created) ? a : b);
    
    _cacheStats.value = {
      'size': _cache.length,
      'hits': _cacheHits.value,
      'misses': _cacheMisses.value,
      'hitRatio': _cacheHits.value + _cacheMisses.value > 0
          ? _cacheHits.value / (_cacheHits.value + _cacheMisses.value)
          : 0.0,
      'oldestEntry': oldestEntry?.created.toIso8601String(),
      'newestEntry': newestEntry?.created.toIso8601String(),
      'averageAge': _cache.values.isEmpty
          ? 0
          : _cache.values
              .map((e) => now.difference(e.created).inSeconds)
              .reduce((a, b) => a + b) ~/
              _cache.length,
    };
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'size': _cacheSize.value,
      'hits': _cacheHits.value,
      'misses': _cacheMisses.value,
      'hitRatio': _cacheStats.value['hitRatio'] ?? 0.0,
      'oldestEntry': _cacheStats.value['oldestEntry'],
      'newestEntry': _cacheStats.value['newestEntry'],
      'averageAge': _cacheStats.value['averageAge'] ?? 0,
    };
  }

  void dispose() {
    _cleanupTimer.value?.cancel();
    _cache.clear();
    ZenLogger.logInfo('CacheService disposed');
  }
}

/// Cache entry with value, creation time, last access time, and TTL
class CacheEntry {
  final dynamic value;
  final DateTime created;
  DateTime lastAccessed;
  final Duration? ttl;

  CacheEntry({
    required this.value,
    required this.created,
    required this.lastAccessed,
    this.ttl,
  });

  /// Check if the entry is expired
  bool get isExpired {
    if (ttl == null) return false;
    
    final now = DateTime.now();
    return now.difference(created) > ttl!;
  }

  @override
  String toString() => 'CacheEntry(value: $value, created: $created, ttl: $ttl)';
}