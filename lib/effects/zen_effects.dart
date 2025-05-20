import 'package:zenify/controllers/zen_controller.dart';
import 'package:zenify/reactive/reactive.dart';

import '../core/zen_logger.dart';
import '../core/zen_metrics.dart';

/// Handles asynchronous side effects with built-in loading, error, and success states
class ZenEffect<T> {
  final RxBool isLoading;
  final Rx<Object?> error;
  final Rx<T?> data;

  // Performance metrics
  final String name;
  final bool enableMetrics;

  ZenEffect({
    required this.name,
    T? initialData,
    this.enableMetrics = true,
  }) :
        isLoading = false.obs(),
        error = null.obs(),
        data = initialData.obs();

  Future<T?> run(Future<T> Function() action) async {
    if (enableMetrics) ZenMetrics.startTiming('effect.$name');

    isLoading.value = true;
    error.value = null;

    try {
      final result = await action();
      data.value = result;

      if (enableMetrics) {
        ZenMetrics.recordEffectSuccess(name);
        ZenMetrics.stopTiming('effect.$name');
      }

      return result;
    } catch (e, stackTrace) {
      error.value = e;

      if (enableMetrics) {
        ZenMetrics.recordEffectFailure(name);
        ZenMetrics.stopTiming('effect.$name');
      }

      ZenLogger.logError('Effect "$name" failed', e, stackTrace);
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  void reset() {
    isLoading.value = false;
    error.value = null;
    // Optionally reset data
  }
}

// Extension methods for ZenController for easy effect creation
extension ZenEffectExtension on ZenController {
  ZenEffect<T> createEffect<T>({
    required String name,
    T? initialData,
    bool enableMetrics = true,
  }) {
    final effect = ZenEffect<T>(
      name: name,
      initialData: initialData,
      enableMetrics: enableMetrics,
    );

    // Auto-dispose the Rx values when controller is disposed
    addDisposer(() {
      // No explicit disposal needed for ValueNotifier-based Rx values
      // They will be garbage collected
    });

    return effect;
  }
}