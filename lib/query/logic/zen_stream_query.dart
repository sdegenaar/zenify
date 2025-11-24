import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../controllers/zen_controller.dart';
import '../../core/zen_logger.dart';
import '../../core/zen_scope.dart';
import '../../di/zen_lifecycle.dart';
import '../../reactive/core/rx_value.dart';
import '../../workers/zen_workers.dart';
import '../query.dart';

/// A reactive query wrapper for Streams.
class ZenStreamQuery<T> extends ZenController {
  final String queryKey;
  final Stream<T> Function() streamFn;
  final ZenQueryConfig config;
  final ZenScope? scope;
  final bool autoDispose;

  // Reactive State
  final Rx<T?> data;
  final Rx<Object?> error = Rx<Object?>(null);
  final Rx<ZenQueryStatus> status = Rx<ZenQueryStatus>(ZenQueryStatus.idle);

  StreamSubscription<T>? _subscription;
  bool _isPaused = false;
  bool _isDisposed = false;
  ZenWorkerHandle?
      _statusWorker; // Changed from ZenWorkers? to ZenWorkerHandle?

  // Derived State
  RxBool get isLoading =>
      _isLoadingNotifier ??= RxBool(status.value == ZenQueryStatus.loading);
  RxBool? _isLoadingNotifier;

  bool get hasData => data.value != null;
  bool get hasError => error.value != null;
  @override
  bool get isDisposed => _isDisposed;

  ZenStreamQuery({
    required this.queryKey,
    required this.streamFn,
    ZenQueryConfig? config,
    T? initialData,
    this.scope,
    this.autoDispose = true,
    bool autoSubscribe = true,
  })  : config = ZenQueryConfig.defaults.merge(config).cast<T>(),
        data = Rx<T?>(initialData) {
    if (initialData != null) {
      status.value = ZenQueryStatus.success;
    }

    _initReactiveProperties();

    if (scope != null) {
      _registerInScope();
    }

    if (autoSubscribe) {
      subscribe();
    }

    ZenLifecycleManager.instance.addLifecycleListener(_handleLifecycleChange);
  }

  void _initReactiveProperties() {
    // Keep track of this worker to dispose it later
    _statusWorker = ZenWorkers.ever(status, (s) {
      if (!_isDisposed) {
        _isLoadingNotifier?.value = s == ZenQueryStatus.loading;
      }
    });
  }

  void _registerInScope() {
    if (autoDispose) {
      scope!.registerDisposer(() {
        if (!_isDisposed) {
          dispose();
        }
      });
    }
  }

  void subscribe() {
    if (_subscription != null) return;

    if (!hasData) {
      status.value = ZenQueryStatus.loading;
    }
    error.value = null;

    try {
      final stream = streamFn();
      _subscription = stream.listen(
        (event) {
          if (_isDisposed) return;
          data.value = event;
          status.value = ZenQueryStatus.success;
          error.value = null;
        },
        onError: (err, stack) {
          if (_isDisposed) return;
          error.value = err;
          status.value = ZenQueryStatus.error;
          ZenLogger.logError('Stream error [$queryKey]', err, stack);
        },
      );
    } catch (e, s) {
      if (!_isDisposed) {
        error.value = e;
        status.value = ZenQueryStatus.error;
      }
      ZenLogger.logError('Failed to subscribe to stream [$queryKey]', e, s);
    }
  }

  void unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handleLifecycleChange(AppLifecycleState state) {
    if (!config.refetchOnFocus) return;

    if (state == AppLifecycleState.paused) {
      _subscription?.pause();
      _isPaused = true;
    } else if (state == AppLifecycleState.resumed && _isPaused) {
      _subscription?.resume();
      _isPaused = false;
    }
  }

  void setData(T newData) {
    data.value = newData;
    status.value = ZenQueryStatus.success;
    error.value = null;
  }

  @override
  void onClose() {
    if (_isDisposed) return;
    _isDisposed = true;

    ZenLifecycleManager.instance
        .removeLifecycleListener(_handleLifecycleChange);

    unsubscribe();
    _statusWorker?.dispose(); // Dispose worker explicitly

    data.dispose();
    error.dispose();
    status.dispose();
    _isLoadingNotifier?.dispose();

    super.onClose();
  }
}
