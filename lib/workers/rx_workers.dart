// lib/zen_state/rx_workers.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/zen_controller.dart';
import '../reactive/rx_notifier.dart';
import '../reactive/rx_value.dart';
import '../core/zen_logger.dart'; // Import ZenLogger

/// Mimics GetX workers (ever, once, debounce, interval)
class ZenWorkers {
  /// Similar to ever() - runs callback every time value changes
  static void Function() ever<T>(
      RxNotifier<T> rx,
      void Function(T) callback, {
        ProviderContainer? container,
      }) {
    final provider = rx.provider;
    final subscription = (container ?? Zen.container).listen<T>(
      provider,
          (_, next) {
        try {
          callback(next);
        } catch (e, stack) {
          ZenLogger.logError('Error in ZenWorkers.ever callback', e, stack);
        }
      },
    );

    return () => subscription.close();
  }

  /// For ValueNotifier/Rx<T> based reactivity
  static void Function() everRx<T>(
      Rx<T> rx,
      void Function(T) callback,
      ) {
    void listener() {
      try {
        callback(rx.value);
      } catch (e, stack) {
        ZenLogger.logError('Error in ZenWorkers.everRx callback', e, stack);
      }
    }

    rx.addListener(listener);
    return () => rx.removeListener(listener);
  }

  /// Similar to once() - runs callback only on first change
  static void Function() once<T>(
      RxNotifier<T> rx,
      void Function(T) callback, {
        ProviderContainer? container,
      }) {
    bool called = false;
    final provider = rx.provider;

    // Properly declare the variable with its type
    late final ProviderSubscription<T> subscription;

    // Initialize the subscription
    subscription = (container ?? Zen.container).listen<T>(
      provider,
          (_, next) {
        if (!called) {
          try {
            callback(next);
          } catch (e, stack) {
            ZenLogger.logError('Error in ZenWorkers.once callback', e, stack);
          }
          called = true;
          subscription.close();
        }
      },
    );

    return () => subscription.close();
  }

  /// Similar to debounce() - runs callback after value stops changing for duration
  static void Function() debounce<T>(
      RxNotifier<T> rx,
      void Function(T) callback, {
        Duration duration = const Duration(milliseconds: 800),
        ProviderContainer? container,
      }) {
    Timer? debounceTimer;
    final provider = rx.provider;
    final subscription = (container ?? Zen.container).listen<T>(
      provider,
          (_, next) {
        if (debounceTimer?.isActive ?? false) debounceTimer?.cancel();
        debounceTimer = Timer(duration, () {
          try {
            callback(next);
          } catch (e, stack) {
            ZenLogger.logError('Error in ZenWorkers.debounce callback', e, stack);
          }
        });
      },
    );

    return () {
      debounceTimer?.cancel();
      subscription.close();
    };
  }

  /// Similar to interval() - limits how frequently the callback can run
  static void Function() interval<T>(
      RxNotifier<T> rx,
      void Function(T) callback, {
        Duration duration = const Duration(milliseconds: 800),
        ProviderContainer? container,
      }) {
    DateTime? lastRun;
    final provider = rx.provider;
    final subscription = (container ?? Zen.container).listen<T>(
      provider,
          (_, next) {
        final now = DateTime.now();
        if (lastRun == null || now.difference(lastRun!) > duration) {
          try {
            callback(next);
          } catch (e, stack) {
            ZenLogger.logError('Error in ZenWorkers.interval callback', e, stack);
          }
          lastRun = now;
        }
      },
    );

    return () => subscription.close();
  }

  /// Works with any Riverpod provider, not just RxNotifier
  static void Function() observe<T>(
      ProviderListenable<T> provider,
      void Function(T) callback, {
        ProviderContainer? container,
      }) {
    final subscription = (container ?? Zen.container).listen<T>(
      provider,
          (_, next) {
        try {
          callback(next);
        } catch (e, stack) {
          ZenLogger.logError('Error in ZenWorkers.observe callback', e, stack);
        }
      },
    );

    return () => subscription.close();
  }
}