// lib/zen_state/testing/zen_test_utilities.dart
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import '../controllers/zen_controller.dart';
import '../reactive/rx_value.dart';

/// Test utility for tracking changes to Rx values
class RxTester<T> {
  final Rx<T> value;
  final List<T> changes = [];
  late final VoidCallback _listener;

  RxTester(this.value) {
    _listener = () => changes.add(value.value);
    value.addListener(_listener);
  }

  void reset() => changes.clear();

  void dispose() => value.removeListener(_listener);

  bool get hasChanged => changes.isNotEmpty;

  T? get lastValue => changes.isEmpty ? null : changes.last;

  bool expectChanges(List<T> expected) {
    if (changes.length != expected.length) return false;
    for (int i = 0; i < changes.length; i++) {
      if (changes[i] != expected[i]) return false;
    }
    return true;
  }
}

/// Test utilities for Riverpod providers
class ZenRiverpodTester {
  final ProviderContainer container;

  ZenRiverpodTester(): container = ProviderContainer(
    overrides: [],
    observers: [_TestProviderObserver()],
  );

  void dispose() => container.dispose();

  // Get the current state of a provider
  T read<T>(ProviderBase<T> provider) {
    return container.read(provider);
  }

  // Listen to changes in a provider and return the values
  List<T> getValues<T>(ProviderBase<T> provider, void Function() action) {
    final values = <T>[];

    final subscription = container.listen<T>(
      provider,
          (_, next) => values.add(next),
    );

    // Execute the action that should cause changes
    action();

    // Clean up
    subscription.close();

    return values;
  }

  // Get all state changes from a StateNotifier
  List<T> getStateChanges<T>(StateNotifierProvider<StateNotifier<T>, T> provider, void Function(StateNotifier<T>) action) {
    final notifier = container.read(provider.notifier);
    final initialValue = container.read(provider);
    final values = <T>[initialValue];

    final subscription = container.listen<T>(
      provider,
          (_, next) => values.add(next),
    );

    // Execute the action
    action(notifier);

    // Clean up
    subscription.close();

    return values;
  }

  // Create a mock controller with initial values
  static T mockController<T extends ZenController>(Map<String, dynamic> initialValues, {T Function()? factory}) {
    // Use the factory or create a mock implementation
    if (factory != null) {
      final controller = factory();

      // Set initial values using reflection or direct property access
      // This is a simplified approach and might need to be adjusted
      initialValues.forEach((key, value) {
        try {
          // This is a simple approach - in real implementation,
          // you might need reflection or a more sophisticated mechanism
          (controller as dynamic)[key] = value;
                } catch (e) {
          print('Failed to set mock value for $key: $e');
        }
      });

      return controller;
    }

    throw UnimplementedError('Mock implementation for $T not provided');
  }
}

/// Observer for tracking provider changes in tests
class _TestProviderObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
      ProviderBase provider,
      Object? previousValue,
      Object? newValue,
      ProviderContainer container,
      ) {
    print('Provider ${provider.name ?? provider.runtimeType} updated: $newValue');
  }
}