// lib/reactive/rx_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/zen_config.dart';
import '../core/zen_logger.dart';
import '../providers/zen_providers.dart';

/// Mimics GetX's Rx<T> with Riverpod's StateNotifier
/// Provides type-safe operations for state management
class RxNotifier<T> extends StateNotifier<T> {
  RxNotifier(super.initialValue);

  // Store the provider reference to avoid creating new instances
  StateNotifierProvider<RxNotifier<T>, T>? _provider;

  T get value => state;
  set value(T newValue) => state = newValue;

  // Operator overloading to mimic GetX's Rx behavior
  T call() => value;

  // Type-safe update method
  void update(T Function(T value) updater) => value = updater(value);

  /// Creates a provider for this RxNotifier
  /// Use this method once to create a provider, then reuse that provider reference
  StateNotifierProvider<RxNotifier<T>, T> createProvider({String? debugName}) {
    _provider ??= StateNotifierProvider<RxNotifier<T>, T>(
          (ref) => this,
      name: debugName,
    );

    // Auto-register in the central registry if debugName is provided
    if (debugName != null) {
      ZenProviders.register<T>(_provider!, name: debugName);

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Provider "$debugName" registered');
      }
    }

    return _provider!;
  }

  /// Gets the previously created provider or creates a new one
  /// WARNING: This creates a new provider each time if createProvider() wasn't called first
  /// It's recommended to use createProvider() explicitly and store the reference
  StateNotifierProvider<RxNotifier<T>, T> get provider {
    if (_provider == null && ZenConfig.strictMode) {
      ZenLogger.logWarning(
          'Provider accessed without explicit creation. Consider using createProvider() first.'
      );
    }
    return _provider ?? createProvider();
  }
}

// Only define these types here, they will be exported properly in the barrel file
// These types will be used with Riverpod
typedef RiverpodRxBool = RxNotifier<bool>;
typedef RiverpodRxInt = RxNotifier<int>;
typedef RiverpodRxDouble = RxNotifier<double>;
typedef RiverpodRxString = RxNotifier<String>;

// Operator extensions for RxNotifier types
extension RxNotifierIntExtension on RxNotifier<int> {
  void operator +(int value) => this.value += value;
  void operator -(int value) => this.value -= value;
  void operator *(int value) => this.value *= value;
  void operator /(int value) => this.value = (this.value / value).floor();
}

extension RxNotifierDoubleExtension on RxNotifier<double> {
  void operator +(double value) => this.value += value;
  void operator -(double value) => this.value -= value;
  void operator *(double value) => this.value *= value;
  void operator /(double value) => this.value /= value;
}

extension RxNotifierBoolExtension on RxNotifier<bool> {
  void toggle() => value = !value;
}

extension RxNotifierStringExtension on RxNotifier<String> {
  void operator +(String value) => this.value += value;
  void clear() => value = '';
}