// lib/di/zen_di.dart
import '../controllers/zen_service.dart';
import '../core/zen_logger.dart';
import '../core/zen_scope.dart';
import '../core/zen_module.dart';
import '../controllers/zen_controller.dart';
import '../core/zen_scope_manager.dart';
import '../testing/zen_test_mode.dart';
import 'zen_lifecycle.dart';
import 'zen_reactive.dart';

/// Main Zenify API for dependency injection
class Zen {
  Zen._(); // Private constructor

  static final ZenLifecycleManager _lifecycleManager =
      ZenLifecycleManager.instance;
  static ZenScope? _currentScope;

  //
  // INITIALIZATION
  //

  /// Initialize Zenify - call once at app startup
  static void init() {
    _lifecycleManager.initLifecycleObserver();
    ZenLogger.logInfo('Zen initialized');
  }

  //
  // SCOPE MANAGEMENT - Primary API
  //

  /// Create a new scope for isolated dependencies
  static ZenScope createScope({String? name, ZenScope? parent}) {
    return ZenScopeManager.getOrCreateScope(
      name: name ?? 'Scope_${DateTime.now().millisecondsSinceEpoch}',
      parentScope: parent,
      autoDispose: false,
    );
  }

  /// Get the root scope for global dependencies
  static ZenScope get rootScope => ZenScopeManager.rootScope;

  /// Get the current active scope (for internal use)
  static ZenScope get currentScope => _currentScope ?? rootScope;

  /// Set current scope (used by routing/navigation)
  static void setCurrentScope(ZenScope scope) {
    _currentScope = scope;
    ZenLogger.logDebug('Current scope: ${scope.name}');
  }

  /// Reset current scope to root
  static void resetCurrentScope() {
    _currentScope = null;
  }

  //
  // ROOT SCOPE CONVENIENCE - Simple API for common cases
  //

  /// Register a dependency in root scope
  ///
  /// ZenService instances are permanent by default, others are not.
  static T put<T>(T instance, {String? tag, bool? isPermanent}) {
    final permanent = isPermanent ?? (instance is ZenService);

    final result = rootScope.put<T>(
      instance,
      tag: tag,
      isPermanent: permanent,
    );

    // Initialize via lifecycle manager
    if (instance is ZenController) {
      _lifecycleManager.initializeController(instance);
    } else if (instance is ZenService) {
      _lifecycleManager.initializeService(instance);
    }

    return result;
  }

  /// Register a lazy factory in root scope
  ///
  /// Creates a singleton that is instantiated only on first access.
  ///
  /// - Set [isPermanent] to true for permanent singletons (survive scope cleanup)
  /// - Set [isPermanent] to false for temporary singletons (default, cleaned up with scope)
  /// - Set [alwaysNew] to true to create fresh instance on each find() call (factory pattern)
  ///
  /// Note: Cannot set both isPermanent and alwaysNew to true
  ///
  /// Example:
  /// ```dart
  /// // Lazy singleton (created once, temporary)
  /// Zen.putLazy(() => HeavyService());
  ///
  /// // Permanent lazy singleton
  /// Zen.putLazy(() => ConfigService(), isPermanent: true);
  ///
  /// // Factory pattern (new instance each time)
  /// Zen.putLazy(() => RequestId.generate(), alwaysNew: true);
  /// ```
  static void putLazy<T>(
    T Function() factory, {
    String? tag,
    bool isPermanent = false,
    bool alwaysNew = false,
  }) {
    rootScope.putLazy<T>(
      factory,
      tag: tag,
      isPermanent: isPermanent,
      alwaysNew: alwaysNew,
    );
  }

  /// Find a dependency in root scope (throws if not found)
  static T find<T>({String? tag}) {
    final result = rootScope.find<T>(tag: tag);
    if (result == null) {
      throw Exception(
          'Dependency of type $T${tag != null ? ' with tag "$tag"' : ''} not found in root scope');
    }

    // Auto-initialize ZenService on first access
    if (result is ZenService && !result.isInitialized) {
      result.ensureInitialized();
    }

    return result;
  }

  /// Find a dependency in root scope (returns null if not found)
  static T? findOrNull<T>({String? tag}) {
    return rootScope.find<T>(tag: tag);
  }

  /// Check if a dependency exists in root scope
  static bool exists<T>({String? tag}) {
    return rootScope.exists<T>(tag: tag);
  }

  /// Delete a dependency from root scope
  static bool delete<T>({String? tag, bool force = false}) {
    return rootScope.delete<T>(tag: tag, force: force);
  }

  //
  // MODULE MANAGEMENT
  //

  /// Register and load modules with auto-dependency resolution
  ///
  /// Example:
  /// ```dart
  /// await Zen.registerModules([
  ///   CoreModule(),
  ///   AuthModule(),
  ///   ApiModule(),
  /// ]);
  /// ```
  static Future<void> registerModules(
    List<ZenModule> modules, {
    ZenScope? scope,
  }) async {
    final targetScope = scope ?? rootScope;
    await ZenModuleRegistry.registerModules(modules, targetScope);
  }

  /// Get a registered module by name
  static ZenModule? getModule(String name) {
    return ZenModuleRegistry.getModule(name);
  }

  /// Check if a module is registered
  static bool hasModule(String name) {
    return ZenModuleRegistry.hasModule(name);
  }

  /// Get all registered modules
  static Map<String, ZenModule> getAllModules() {
    return ZenModuleRegistry.getAllModules();
  }

  //
  // TESTING & CLEANUP
  //

  /// Enter test mode for easy mocking
  ///
  /// Example:
  /// ```dart
  /// Zen.testMode()
  ///   .mock<AuthService>(FakeAuthService())
  ///   .mock<ApiClient>(MockApiClient());
  /// ```
  static ZenTestMode testMode() => ZenTestMode();

  /// Complete reset - clear everything (for testing)
  static void reset() {
    ZenModuleRegistry.clear();
    ZenReactiveSystem.instance.clearListeners();
    _lifecycleManager.dispose();
    _currentScope = null;
    ZenScopeManager.disposeAll();
    ZenLogger.logInfo('🔄 Zen reset complete');
  }

  /// Delete all dependencies from all scopes
  static void deleteAll({bool force = false}) {
    ZenScopeManager.disposeAll();
  }
}
