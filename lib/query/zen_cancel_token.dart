import '../core/zen_logger.dart';

/// A token that can be used to signal cancellation to async operations.
///
/// Designed to be platform-agnostic. Can be easily adapted to:
/// - Dio: `cancelToken: token.toDioCancelToken()` (via extension)
/// - Http: `token.onCancel(() => client.close())`
class ZenCancelToken {
  bool _isCancelled = false;
  final List<void Function()> _listeners = [];
  final String? message;

  ZenCancelToken([this.message]);

  /// Whether cancellation has been requested
  bool get isCancelled => _isCancelled;

  /// Request cancellation
  void cancel([String? reason]) {
    if (_isCancelled) return;
    _isCancelled = true;

    if (reason != null || message != null) {
      ZenLogger.logDebug('ZenCancelToken cancelled: ${reason ?? message}');
    }

    for (final listener in _listeners) {
      try {
        listener();
      } catch (e, stack) {
        ZenLogger.logError('Error in ZenCancelToken listener', e, stack);
      }
    }
    _listeners.clear();
  }

  /// Register a callback to be invoked when the token is cancelled.
  /// If the token is already cancelled, the callback is invoked immediately.
  void onCancel(void Function() callback) {
    if (_isCancelled) {
      callback();
    } else {
      _listeners.add(callback);
    }
  }

  /// Throw an exception if the token is cancelled
  void throwIfCancelled() {
    if (_isCancelled) {
      throw ZenCancellationException(message ?? 'Operation cancelled');
    }
  }
}

/// Exception thrown when an operation is cancelled
class ZenCancellationException implements Exception {
  final String message;
  ZenCancellationException(this.message);

  @override
  String toString() => 'ZenCancellationException: $message';
}
