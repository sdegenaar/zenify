
// test/test_helpers.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Helper class for testing with Zen
class ZenTestHelper {
  /// Creates an isolated test environment with its own scope
  static ZenScope createIsolatedTestScope(String testName) {
    // Ensure Flutter binding is initialized
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize Zen if not already done
    try {
      Zen.init();
    } catch (e) {
      // Already initialized, continue
    }

    // Configure Zen for testing environment
    ZenConfig.configureTest();

    // Create a unique test scope that won't conflict with other tests
    final scopeName = 'TestScope-$testName-${DateTime.now().microsecondsSinceEpoch}';

    // Create scope with root as parent to ensure isolation
    final testScope = Zen.createScope(name: scopeName);

    return testScope;
  }

  /// Register dependencies in a given scope or root scope
  static void registerDependencies(
      Map<Type, Function> dependencies, {
        ZenScope? scope,
      }) {
    final targetScope = scope ?? Zen.rootScope;

    // Register each dependency
    for (final entry in dependencies.entries) {
      final factory = entry.value;
      final instance = factory();

      // Use put for all dependencies
      targetScope.put(instance);
    }
  }

  /// Register dependencies in the root scope (convenience method)
  static void registerGlobalDependencies(Map<Type, Function> dependencies) {
    // Ensure Zen is initialized
    try {
      Zen.init();
    } catch (e) {
      // Already initialized, ignore
    }

    // Clear existing dependencies in root scope
    Zen.deleteAll(force: true);

    // Register each dependency using the root scope API
    for (final entry in dependencies.entries) {
      final factory = entry.value;
      final instance = factory();

      // Use put for all dependencies
      Zen.put(instance);
    }
  }

  /// Reset the entire DI system for a fresh test environment
  static void resetDI() {
    try {
      // Reset the entire Zen system
      Zen.reset();

      // Reinitialize
      Zen.init();
    } catch (e) {
      ZenLogger.logError('Error resetting DI system', e);
    }
  }

  /// Create a test scope with predefined dependencies
  static ZenScope createScopeWithDependencies(
      String scopeName,
      Map<Type, Function> dependencies,
      ) {
    final scope = createIsolatedTestScope(scopeName);
    registerDependencies(dependencies, scope: scope);
    return scope;
  }

  /// Dispose a scope and verify it's properly cleaned up
  static void disposeAndVerifyScope(ZenScope scope) {
    expect(scope.isDisposed, isFalse, reason: 'Scope should not be disposed before calling dispose');

    scope.dispose();

    expect(scope.isDisposed, isTrue, reason: 'Scope should be disposed after calling dispose');
  }

  /// Verify that a dependency exists in a scope
  static void verifyDependencyExists<T>(ZenScope scope, {String? tag}) {
    final dependency = scope.find<T>(tag: tag);
    expect(dependency, isNotNull, reason: 'Dependency $T${tag != null ? ' with tag $tag' : ''} should exist');
  }

  /// Verify that a dependency does not exist in a scope
  static void verifyDependencyNotExists<T>(ZenScope scope, {String? tag}) {
    final dependency = scope.find<T>(tag: tag);
    expect(dependency, isNull, reason: 'Dependency $T${tag != null ? ' with tag $tag' : ''} should not exist');
  }

  /// Create multiple test scopes for hierarchy testing
  static List<ZenScope> createScopeHierarchy(List<String> scopeNames) {
    final scopes = <ZenScope>[];

    for (int i = 0; i < scopeNames.length; i++) {
      final parent = i == 0 ? null : scopes[i - 1];
      final scope = Zen.createScope(
        name: scopeNames[i],
        parent: parent,
      );
      scopes.add(scope);
    }

    return scopes;
  }

  /// Wait for all async operations to complete
  static Future<void> waitForAsyncOperations() async {
    // Wait for microtasks
    await Future.microtask(() {});

    // Wait for a short delay to ensure all operations complete
    await Future.delayed(const Duration(milliseconds: 10));
  }

  /// Helper to verify controller lifecycle
  static Future<void> verifyControllerLifecycle(ZenController controller) async {
    // Should be initialized immediately - use the correct getter
    expect(controller.isInitialized, isTrue, reason: 'Controller should be initialized');

    // Wait for onReady
    await waitForAsyncOperations();

    // Should be ready now - use the correct getter
    expect(controller.isReady, isTrue, reason: 'Controller should be ready');
  }

  /// Create a mock service for testing
  static TestService createMockService(String value) {
    return TestService(value);
  }

  /// Create a mock controller for testing
  static TestController createMockController(String value) {
    return TestController(value);
  }
}

/// Helper class for testing ZenController lifecycle methods
class ZenLifecycleTestHelper {
  /// Process all lifecycle events
  static Future<void> processLifecycleEvents() async {
    // Wait for microtasks to complete
    await Future.microtask(() {});

    // Wait for post-frame callbacks
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Wait for controller to be ready
  static Future<void> waitForControllerReady(ZenController controller) async {
    await processLifecycleEvents();

    // Verify the controller is in the expected state - use correct getters
    expect(controller.isInitialized, isTrue);
    expect(controller.isReady, isTrue);
  }
}

// Test helper classes that can be used across tests
class TestService {
  final String value;
  bool disposed = false;

  TestService(this.value);

  void dispose() {
    disposed = true;
  }
}

class TestController extends ZenController {
  final String value;
  bool initialized = false;  // Custom property for test tracking
  bool readyCalled = false;  // Custom property for test tracking
  bool disposeMethodCalled = false;  // Custom property for test tracking

  TestController(this.value);

  @override
  void onInit() {
    super.onInit();
    initialized = true;  // Set our custom tracking property
  }

  @override
  void onReady() {
    super.onReady();
    readyCalled = true;  // Set our custom tracking property
  }

  @override
  void onDispose() {
    disposeMethodCalled = true;  // Set our custom tracking property
    super.onDispose();
  }
}

class DependentService {
  final TestService dependency;

  DependentService(this.dependency);
}

// Test module for module testing
class TestModule extends ZenModule {
  @override
  String get name => 'TestModule';

  @override
  void register(ZenScope scope) {
    final service = TestService('from module');
    scope.put<TestService>(service, permanent: false);
  }
}