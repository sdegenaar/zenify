// lib/di/zen_reactive.dart
import 'package:flutter/widgets.dart';
import 'package:zenify/di/zen_di.dart';
import '../core/zen_logger.dart';

/// Custom subscription
class ZenSubscription {
  final VoidCallback _dispose;

  ZenSubscription(this._dispose);

  void close() {
    _dispose();
  }
}

/// Manages the reactive system for the DI container
class ZenReactiveSystem {
  // Maps of instances and listeners for the reactive system
  final Map<dynamic, Set<VoidCallback>> _listeners = {};

  /// Notify all listeners for a given type and tag
  void notifyListeners<T>(String? tag) {
    final key = _getKey(T, tag);
    final listeners = _listeners[key]?.toList() ?? [];

    for (final listener in listeners) {
      try {
        listener();
      } catch (e, stack) {
        ZenLogger.logError('Error notifying listener for $T', e, stack);
      }
    }
  }

  /// Listen to changes for a specific type and tag
  /// Replacement for Riverpod's listen function
  ZenSubscription listen<T>(
      dynamic provider,
      void Function(T) listener,
      ) {
    // Extract type and tag from provider
    final Type type = T;
    final String? tag = _extractTag(provider);
    final key = _getKey(type, tag);

    // Add listener
    _listeners.putIfAbsent(key, () => {});

    // Create callback that will call the listener with current value
    void callback() {
      try {
        final instance = Zen.findDependency<T>(tag: tag);
        if (instance != null) {
          listener(instance);
        }
      } catch (e, stack) {
        ZenLogger.logError('Error in listener for $T', e, stack);
      }
    }

    _listeners[key]!.add(callback);

    // Call initially with current value if exists
    final current = Zen.findDependency<T>(tag: tag);
    if (current != null) {
      try {
        listener(current);
      } catch (e, stack) {
        ZenLogger.logError('Error in initial listener call for $T', e, stack);
      }
    }

    // Return subscription that can be disposed
    return ZenSubscription(() {
      _listeners[key]?.remove(callback);
      if (_listeners[key]?.isEmpty ?? false) {
        _listeners.remove(key);
      }
    });
  }

  /// Clear all listeners
  void clearListeners() {
    _listeners.clear();
  }

  /// Extract tag from a provider (for compatibility with previous API)
  String? _extractTag(dynamic provider) {
    // If the provider is just a Type, there's no tag
    if (provider is Type) {
      return null;
    }

    // Try to extract tag from a String pattern like "Type:tag"
    if (provider is String && provider.contains(':')) {
      return provider.split(':').last;
    }

    return null;
  }

  /// Get a key for associating listeners with types and tags
  dynamic _getKey(Type type, String? tag) {
    return tag != null ? '$type:$tag' : type;
  }
}