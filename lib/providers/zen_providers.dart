// lib/providers/zen_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/zen_logger.dart';
import '../reactive/rx_notifier.dart';

/// Centralized registry for all providers in the application
/// Helps track, access, and organize providers in a standardized way
/// Enhanced with generic type parameters for improved type safety
class ZenProviders {
  ZenProviders._(); // Private constructor

  /// Internal storage for all registered providers
  static final Map<String, ProviderBase> _providers = {};

  /// Register a provider with a unique name
  /// If a provider with the same name exists, it will be overwritten with a warning
  ///
  /// Type parameter [T] ensures type safety when retrieving the provider later
  static void register<T>(ProviderBase<T> provider, {required String name}) {
    if (_providers.containsKey(name)) {
      ZenLogger.logWarning('Provider "$name" is being overwritten');
    }
    _providers[name] = provider;
  }

  /// Creates a type-safe provider reference that can be used to safely access and modify state
  /// This is the recommended way to access providers for better type safety
  static TypedProviderRef<T> createRef<T>(StateNotifierProvider<RxNotifier<T>, T> provider, {required String name}) {
    register<T>(provider, name: name);
    return TypedProviderRef<T>(provider: provider, name: name);
  }

  /// Gets a typed provider reference for an existing provider
  /// Returns null if the provider doesn't exist or has an incompatible type
  static TypedProviderRef<T>? getRef<T>(String name) {
    final provider = get<T>(name);
    if (provider is StateNotifierProvider<RxNotifier<T>, T>) {
      return TypedProviderRef<T>(provider: provider, name: name);
    }
    return null;
  }

  /// Bulk register multiple providers at once
  static void registerAll(Map<String, ProviderBase> providers) {
    providers.forEach((name, provider) {
      register(provider, name: name);
    });
  }

  /// Get a registered provider by name with proper type checking
  /// Returns null if not found or if types don't match
  static ProviderBase<T>? get<T>(String name) {
    final provider = _providers[name];
    if (provider is ProviderBase<T>) {
      return provider;
    }

    if (provider != null) {
      ZenLogger.logWarning(
          'Provider "$name" exists but has incompatible type. '
              'Expected provider of ${T.runtimeType}, but got ${provider.runtimeType}'
      );
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

  /// Get all providers of a specific type
  /// This method filters the providers by their actual type
  static Map<String, ProviderBase<T>> getAllOfType<T>() {
    return Map.unmodifiable(
        Map.fromEntries(
            _providers.entries
                .where((entry) => entry.value is ProviderBase<T>)
                .map((entry) => MapEntry(entry.key, entry.value as ProviderBase<T>))
        )
    );
  }

  /// Clear all registered providers
  static void clear() {
    _providers.clear();
  }
}

/// A type-safe reference to a provider
/// This class provides strongly-typed methods for interacting with providers,
/// ensuring compile-time type safety when accessing or modifying state
class TypedProviderRef<T> {
  final StateNotifierProvider<RxNotifier<T>, T> provider;
  final String name;

  const TypedProviderRef({
    required this.provider,
    required this.name,
  });

  /// Watch the provider value in a widget
  T watch(WidgetRef ref) => ref.watch(provider);

  /// Read the provider value
  T read(WidgetRef ref) => ref.read(provider);

  /// Update the provider value
  void update(WidgetRef ref, T Function(T current) updater) {
    ref.read(provider.notifier).update(updater);
  }

  /// Set the provider value
  void set(WidgetRef ref, T value) {
    ref.read(provider.notifier).value = value;
  }
}

/// Extension to create provider references from RxNotifier instances
extension RxNotifierProviderExtension<T> on RxNotifier<T> {
  /// Creates a type-safe provider reference
  TypedProviderRef<T> createRef({required String name}) {
    final provider = createProvider(debugName: name);
    return ZenProviders.createRef<T>(provider, name: name);
  }
}