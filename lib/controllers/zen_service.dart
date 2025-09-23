import 'package:flutter/foundation.dart';
import '../core/zen_logger.dart';

abstract class ZenService {
  static final Set<ZenService> _activeServices = <ZenService>{};
  bool _initialized = false;
  bool _initializing = false; // protect against re-entrancy
  bool _disposed = false;

  ZenService() {
    _activeServices.add(this);
    ZenLogger.logDebug('ZenService created: $runtimeType');
  }

  @protected
  @mustCallSuper
  void onInit() {
    ZenLogger.logDebug('ZenService initialized: $runtimeType');
  }

  // User cleanup hook. Override this in subclasses.
  @protected
  void onClose() {}

  void ensureInitialized() {
    if (_initialized) return;
    if (_initializing) return; // prevent re-entrant init
    _initializing = true;
    try {
      onInit();
      _initialized = true;
    } catch (e, stackTrace) {
      ZenLogger.logError(
          'ZenService onInit failed: $runtimeType', e, stackTrace);
      rethrow;
    } finally {
      _initializing = false;
    }
  }

  // Public API: either call is acceptable and idempotent.
  void dispose() => _disposeOnce(trigger: 'dispose');
  void onCloseCall() => _disposeOnce(trigger: 'onClose');

  void _disposeOnce({required String trigger}) {
    if (_disposed) return;
    _disposed = true;

    ZenLogger.logDebug('ZenService disposing ($trigger): $runtimeType');
    try {
      onClose(); // user cleanup once
    } catch (e, stackTrace) {
      // Never rethrow on disposal; just log
      ZenLogger.logError(
          'Error in onClose for ZenService $runtimeType', e, stackTrace);
    } finally {
      _activeServices.remove(this);
      ZenLogger.logDebug('ZenService disposed: $runtimeType');
    }
  }

  bool get isInitialized => _initialized;
  bool get isInitializing => _initializing;
  bool get isDisposed => _disposed;

  static int get activeServiceCount => _activeServices.length;

  static List<String> getActiveServiceTypes() {
    return _activeServices.map((s) => s.runtimeType.toString()).toList();
  }

  @visibleForTesting
  static void disposeAllServices() {
    // Work on a snapshot to avoid concurrent modification.
    final services = _activeServices.toList(growable: false);
    ZenLogger.logDebug('Disposing ${services.length} services');
    for (final s in services) {
      // Each dispose() removes itself; no need to clear afterward.
      s.dispose();
    }
  }
}
