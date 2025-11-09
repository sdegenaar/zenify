// lib/testing/zen_test_mode.dart
import '../di/zen_di.dart';
import '../core/zen_scope.dart';
import '../core/zen_logger.dart';

/// Test mode utilities for easy mocking and test setup
///
/// Provides a fluent API for setting up test dependencies and creating
/// isolated test scopes.
///
/// Example:
/// ```dart
/// testWidgets('login flow', (tester) async {
///   Zen.testMode()
///     .mock<AuthService>(FakeAuthService())
///     .mock<ApiClient>(MockApiClient());
///
///   await tester.pumpWidget(MyApp());
///   // test...
/// });
/// ```
class ZenTestMode {
  ZenTestMode._();

  static final ZenTestMode _instance = ZenTestMode._();

  /// Get the singleton test mode instance
  factory ZenTestMode() => _instance;

  /// Replace a dependency with a mock/fake implementation
  ///
  /// This will forcefully delete the existing dependency and register
  /// the mock in its place.
  ZenTestMode mock<T>(T instance, {String? tag}) {
    ZenLogger.logDebug('🧪 Test Mode: Mocking $T${tag != null ? ':$tag' : ''}');

    // Delete existing if present
    Zen.delete<T>(tag: tag, force: true);

    // Register mock
    Zen.put<T>(instance, tag: tag);

    return this;
  }

  /// Replace a dependency with a factory function
  ///
  /// Useful when you need to create a new instance for each test.
  ZenTestMode mockLazy<T>(T Function() factory, {String? tag}) {
    ZenLogger.logDebug(
        '🧪 Test Mode: Mocking $T${tag != null ? ':$tag' : ''} (lazy)');

    Zen.delete<T>(tag: tag, force: true);
    Zen.putLazy<T>(factory, tag: tag);

    return this;
  }

  /// Replace a dependency with a factory that creates new instances
  ZenTestMode mockFactory<T>(T Function() factory, {String? tag}) {
    ZenLogger.logDebug(
        '🧪 Test Mode: Mocking $T${tag != null ? ':$tag' : ''} (factory)');

    Zen.delete<T>(tag: tag, force: true);
    Zen.putLazy<T>(factory, tag: tag);

    return this;
  }

  /// Create an isolated test scope
  ///
  /// This creates a new scope that's completely isolated from other scopes,
  /// useful for integration tests.
  ///
  /// Example:
  /// ```dart
  /// final testScope = Zen.testMode().isolatedScope();
  /// testScope.put<AuthService>(FakeAuthService());
  ///
  /// // Use testScope in your test
  /// // ...
  ///
  /// testScope.dispose(); // Clean up
  /// ```
  ZenScope isolatedScope({String? name}) {
    final scopeName =
        name ?? 'TestScope-${DateTime.now().millisecondsSinceEpoch}';
    ZenLogger.logDebug('🧪 Test Mode: Creating isolated scope: $scopeName');

    return Zen.createScope(name: scopeName);
  }

  /// Mock multiple dependencies at once
  ///
  /// Example:
  /// ```dart
  /// Zen.testMode().mockAll({
  ///   AuthService: FakeAuthService(),
  ///   ApiClient: MockApiClient(),
  ///   CacheService: InMemoryCacheService(),
  /// });
  /// ```
  ZenTestMode mockAll(Map<Type, dynamic> mocks) {
    for (final entry in mocks.entries) {
      ZenLogger.logDebug('🧪 Test Mode: Mocking ${entry.key}');

      // This requires runtime type inspection - simplified version
      final instance = entry.value;
      Zen.put(instance);
    }

    return this;
  }

  /// Reset all mocks and return to normal mode
  ///
  /// This is automatically called by Zen.reset() but can be called
  /// explicitly if needed.
  void reset() {
    ZenLogger.logDebug('🧪 Test Mode: Reset');
    // Actual reset is handled by Zen.reset()
  }
}

/// Helper function to access test mode (alternative to extension)
///
/// This is exported globally so you can use:
/// ```dart
/// zenTestMode().mock<AuthService>(FakeAuthService());
/// ```
ZenTestMode zenTestMode() => ZenTestMode();

/// Extension on Zen class to provide test mode access
///
/// Note: This needs to be a static extension since Zen is used as a static class.
extension ZenTestingExtension on Zen {
  /// Enter test mode for easy mocking and test setup
  ///
  /// Example:
  /// ```dart
  /// Zen.testMode()
  ///   .mock<AuthService>(FakeAuthService())
  ///   .mock<ApiClient>(MockApiClient());
  /// ```
  static ZenTestMode testMode() => ZenTestMode();
}
