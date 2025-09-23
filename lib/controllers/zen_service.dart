// lib/controllers/zen_service.dart
import 'package:flutter/foundation.dart';

import '../core/zen_logger.dart';

/// Base class for long-lived services that persist across app lifecycle
///
/// Unlike ZenController, ZenService instances:
/// - Default to permanent registration (can be overridden)
/// - Are ideal for background services, APIs, caches, etc.
/// - Have guaranteed cleanup via onClose()
///
/// Example:
/// ```dart
/// class AuthService extends ZenService {
///   @override
///   void onInit() {
///     super.onInit();
///     setupTokenListener();
///   }
///
///   @override
///   void onClose() {
///     cancelSubscriptions();
///     super.onClose();
///   }
/// }
///
/// // Register - automatically permanent
/// Zen.put<AuthService>(AuthService());
/// ```
abstract class ZenService {
  static final Set<ZenService> _activeServices = <ZenService>{};
  bool _initialized = false;
  bool _disposed = false;

  /// Create a new service instance
  ZenService() {
    _activeServices.add(this);
    ZenLogger.logDebug('ZenService created: $runtimeType');
  }

  /// Initialize the service - called automatically when first accessed
  @protected
  @mustCallSuper
  void onInit() {
    ZenLogger.logDebug('ZenService initialized: $runtimeType');
  }

  /// Called when service is being disposed
  /// Override to cleanup resources like streams, timers, etc.
  @protected
  @mustCallSuper
  void onClose() {
    ZenLogger.logDebug('ZenService closing: $runtimeType');
  }

  /// Internal initialization - called by framework when service is first accessed
  void ensureInitialized() {
    if (_initialized) return;

    // Prevent re-entrancy if onInit() indirectly triggers ensureInitialized()
    bool initStarted = false;
    try {
      initStarted = true;
      onInit();
      _initialized = true; // mark initialized only after successful onInit
    } catch (e, stackTrace) {
      // onInit failed; keep _initialized as false
      ZenLogger.logError(
          'ZenService onInit failed: $runtimeType', e, stackTrace);
      rethrow;
    } finally {
      // If onInit threw before completing, ensure we didn't flip the flag
      if (!initStarted) {
        _initialized = false;
      }
    }
  }

  /// Dispose this service and cleanup resources
  /// Called by Zenify's disposal system
  @mustCallSuper
  void onDelete() {
    if (_disposed) return; // Prevent double disposal
    _disposed = true;

    try {
      onClose();
    } catch (e, stackTrace) {
      ZenLogger.logError(
          'Error disposing ZenService $runtimeType', e, stackTrace);
    } finally {
      _activeServices.remove(this);
      ZenLogger.logDebug('ZenService disposed: $runtimeType');
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Check if service is disposed
  bool get isDisposed => _disposed;

  /// Get count of active services (useful for debugging)
  static int get activeServiceCount => _activeServices.length;

  /// Get list of active service types (debugging/testing)
  static List<String> getActiveServiceTypes() {
    return _activeServices.map((s) => s.runtimeType.toString()).toList();
  }

  /// Dispose all active services (for testing/shutdown)
  @visibleForTesting
  static void disposeAllServices() {
    final services = _activeServices.toList();
    ZenLogger.logDebug('Disposing ${services.length} services');
    for (final service in services) {
      service.onDelete();
    }
    _activeServices.clear();
  }
}
