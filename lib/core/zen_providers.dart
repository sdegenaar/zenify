// lib/zen_state/zen_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'zen_logger.dart';

/// Centralized registry for all providers in the application
/// Helps track, access, and organize providers in a standardized way
class ZenProviders {
  ZenProviders._(); // Private constructor

  /// Internal storage for all registered providers
  static final Map<String, ProviderBase> _providers = {};

  /// Register a provider with a unique name
  /// If a provider with the same name exists, it will be overwritten with a warning
  static void register<T>(ProviderBase provider, {required String name}) {
    if (_providers.containsKey(name)) {
      ZenLogger.logWarning('Provider "$name" is being overwritten');
    }
    _providers[name] = provider;
  }

  /// Bulk register multiple providers at once
  static void registerAll(Map<String, ProviderBase> providers) {
    providers.forEach((name, provider) {
      register(provider, name: name);
    });
  }

  /// Get a registered provider by name
  /// Returns null if not found
  static ProviderBase<T>? get<T>(String name) {
    final provider = _providers[name];
    if (provider is ProviderBase<T>) {
      return provider;
    }
    return null;
  }

  /// Check if a provider is registered
  static bool hasProvider(String name) => _providers.containsKey(name);

  /// Remove a provider from the registry
  static void unregister(String name) {
    _providers.remove(name);
  }

  /// Get all registered providers
  static Map<String, ProviderBase> getAll() {
    return Map.unmodifiable(_providers);
  }

  /// Get all providers with names matching a pattern
  static Map<String, ProviderBase> getByPattern(Pattern pattern) {
    return Map.unmodifiable(
        Map.fromEntries(
            _providers.entries.where((entry) => entry.key.contains(pattern))
        )
    );
  }

  /// Clear all registered providers
  static void clear() {
    _providers.clear();
  }
}