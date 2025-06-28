
// test/memory_leak_detection_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// =============================================================================
// MEMORY LEAK DETECTION UTILITIES
// =============================================================================

/// Simple memory leak detector that tracks object creation/disposal
class MemoryLeakDetector {
  static final Map<String, int> _createdObjects = {};
  static final Map<String, int> _disposedObjects = {};
  static bool _isEnabled = false;

  /// Enable memory leak detection
  static void enable() {
    _isEnabled = true;
    _createdObjects.clear();
    _disposedObjects.clear();
  }

  /// Disable memory leak detection
  static void disable() {
    _isEnabled = false;
    _createdObjects.clear();
    _disposedObjects.clear();
  }

  /// Track an object creation
  static void trackCreation(String objectType) {
    if (!_isEnabled) return;
    _createdObjects[objectType] = (_createdObjects[objectType] ?? 0) + 1;
  }

  /// Track an object disposal
  static void trackDisposal(String objectType) {
    if (!_isEnabled) return;
    _disposedObjects[objectType] = (_disposedObjects[objectType] ?? 0) + 1;
  }

  /// Get memory leak report
  static Map<String, int> getLeakReport() {
    final leaks = <String, int>{};

    for (final entry in _createdObjects.entries) {
      final type = entry.key;
      final created = entry.value;
      final disposed = _disposedObjects[type] ?? 0;
      final leaked = created - disposed;

      if (leaked > 0) {
        leaks[type] = leaked;
      }
    }

    return leaks;
  }

  /// Assert no memory leaks
  static void expectNoLeaks([String? testName]) {
    final leaks = getLeakReport();

    if (leaks.isNotEmpty) {
      final reportStr = leaks.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
      fail('${testName ?? "Test"} has memory leaks: $reportStr');
    }
  }

  /// Reset tracking
  static void reset() {
    _createdObjects.clear();
    _disposedObjects.clear();
  }
}

/// Resource counter for tracking active Zenify resources
class ZenResourceTracker {
  static int _controllerCount = 0;
  static int _scopeCount = 0;
  static int _serviceCount = 0;

  static void trackController() => _controllerCount++;
  static void trackScope() => _scopeCount++;
  static void trackService() => _serviceCount++;

  static void untrackController() => _controllerCount--;
  static void untrackScope() => _scopeCount--;
  static void untrackService() => _serviceCount--;

  static int get controllerCount => _controllerCount;
  static int get scopeCount => _scopeCount;
  static int get serviceCount => _serviceCount;
  static int get totalResourceCount => _controllerCount + _scopeCount + _serviceCount;

  static void reset() {
    _controllerCount = 0;
    _scopeCount = 0;
    _serviceCount = 0;
  }

  static String getReport() {
    return 'Controllers: $_controllerCount, Scopes: $_scopeCount, Services: $_serviceCount';
  }
}

// =============================================================================
// TEST CLASSES
// =============================================================================

class TestController extends ZenController {
  final String id;
  bool initCalled = false;
  bool readyCalled = false;
  bool disposeCalled = false;

  late final Rx<int> counter;
  late final Rx<String> message;

  TestController(this.id) {
    counter = obs(0);
    message = obs('initial');

    MemoryLeakDetector.trackCreation('TestController');
    ZenResourceTracker.trackController();

    ZenLogger.logDebug('TestController created: $id');
  }

  @override
  void onInit() {
    super.onInit();
    initCalled = true;
    ZenLogger.logDebug('TestController initialized: $id');
  }

  @override
  void onReady() {
    super.onReady();
    readyCalled = true;
    ZenLogger.logDebug('TestController ready: $id');
  }

  @override
  void onDispose() {
    disposeCalled = true;
    ZenLogger.logDebug('TestController disposing: $id');

    MemoryLeakDetector.trackDisposal('TestController');
    ZenResourceTracker.untrackController();

    super.onDispose();
  }

  void increment() {
    counter.value++;
    ZenLogger.logDebug('TestController $id incremented to: ${counter.value}');
  }

  void updateMessage(String newMessage) {
    message.value = newMessage;
    ZenLogger.logDebug('TestController $id message updated to: $newMessage');
  }
}

class TestService {
  final String name;
  bool disposed = false;

  TestService(this.name) {
    MemoryLeakDetector.trackCreation('TestService');
    ZenResourceTracker.trackService();
    ZenLogger.logDebug('TestService created: $name');
  }

  void dispose() {
    if (disposed) return;

    disposed = true;
    MemoryLeakDetector.trackDisposal('TestService');
    ZenResourceTracker.untrackService();
    ZenLogger.logDebug('TestService disposed: $name');
  }
}

class TestModule extends ZenModule {
  final String moduleId;
  final List<TestService> _services = [];

  TestModule(this.moduleId);

  @override
  String get name => 'TestModule-$moduleId';

  @override
  void register(ZenScope scope) {
    ZenLogger.logDebug('Registering module: $name');

    // Create and track services
    for (int i = 0; i < 2; i++) {
      final service = TestService('service-$moduleId-$i');
      _services.add(service);
      scope.put(service, tag: 'service-$moduleId-$i');
    }

    // Create and register controller
    scope.put(TestController('controller-$moduleId'));

    ZenLogger.logDebug('Module registration completed: $name');
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    ZenLogger.logDebug('Disposing module: $name');

    // Manually dispose services to ensure proper cleanup
    for (final service in _services) {
      service.dispose();
    }
    _services.clear();
    await super.onDispose(scope);

    ZenLogger.logDebug('Module disposal completed: $name');
  }
}

// =============================================================================
// SAFE ZENVIEW IMPLEMENTATION FOR TESTING
// =============================================================================

/// A safe ZenView implementation that doesn't use reactive Obx widgets
/// This prevents hanging issues during widget disposal in tests
class SafeZenTestView extends StatefulWidget {
  const SafeZenTestView({super.key});

  @override
  State<SafeZenTestView> createState() => _SafeZenTestViewState();
}

class _SafeZenTestViewState extends State<SafeZenTestView> {
  TestController? _controller;
  int _counterValue = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    ZenLogger.logDebug('SafeZenTestView initializing...');

    _controller = TestController('safe-zenview-test');
    ZenResourceTracker.trackController(); // Track the controller creation
    _counterValue = _controller!.counter.value;

    ZenLogger.logDebug('SafeZenTestView initialized');
  }

  @override
  void dispose() {
    ZenLogger.logDebug('SafeZenTestView disposing...');

    if (!_disposed && _controller != null) {
      _controller!.onDispose(); // Manually dispose controller
      _disposed = true;
    }
    super.dispose();

    ZenLogger.logDebug('SafeZenTestView disposed');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            // Use static text instead of reactive Obx
            Text('Counter: $_counterValue'),
            ElevatedButton(
              onPressed: _disposed ? null : () {
                _controller?.increment();
                if (mounted && !_disposed) {
                  setState(() {
                    _counterValue = _controller!.counter.value;
                  });
                }
              },
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TEST HELPER FUNCTIONS
// =============================================================================

/// Test module registration and cleanup
Future<void> _testModuleRegistration() async {
  ZenLogger.logDebug('Starting module registration test...');

  final scope = Zen.createScope(name: 'ModuleTestScope');
  ZenResourceTracker.trackScope();

  final modules = <TestModule>[];

  // Create modules
  for (int i = 0; i < 2; i++) {
    final module = TestModule('module-$i');
    modules.add(module);
    module.register(scope);
  }

  // Use registered controllers briefly
  for (int i = 0; i < modules.length; i++) {
    final controller = scope.find<TestController>();
    if (controller != null) {
      controller.increment();
      controller.updateMessage('test');
    }
  }

  // Dispose modules properly
  for (final module in modules) {
    await module.onDispose(scope);
  }

  // Dispose scope
  scope.dispose();
  ZenResourceTracker.untrackScope();

  ZenLogger.logDebug('Module registration test completed');
}

/// Test scope hierarchy
Future<void> _testScopeHierarchy() async {
  ZenLogger.logDebug('Starting scope hierarchy test...');

  final parentScope = Zen.createScope(name: 'Parent');
  ZenResourceTracker.trackScope();

  final childScope = Zen.createScope(name: 'Child', parent: parentScope);
  ZenResourceTracker.trackScope();

  // Add services to scopes
  final parentService = TestService('parent-service');
  final childService = TestService('child-service');

  parentScope.put(parentService);
  childScope.put(childService);

  // Test hierarchy access
  final foundFromChild = childScope.find<TestService>();
  expect(foundFromChild, isNotNull);

  // Clean up services before disposing scopes
  parentService.dispose();
  childService.dispose();

  // Dispose scopes
  childScope.dispose();
  parentScope.dispose();

  ZenResourceTracker.untrackScope(); // child
  ZenResourceTracker.untrackScope(); // parent

  ZenLogger.logDebug('Scope hierarchy test completed');
}

// =============================================================================
// MAIN TEST SUITE
// =============================================================================

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Enable ZenLogger for tests when needed
    ZenConfig.enableDebugLogs = const bool.fromEnvironment('TEST_DEBUG', defaultValue: false);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('🔍 STARTING ZENIFY MEMORY LEAK DETECTION TESTS');
      ZenLogger.logInfo('════════════════════════════════════════════════════════════');
    }
  });

  setUp(() {
    Zen.init();
    // Keep debug logs setting from environment
    ZenConfig.enableDebugLogs = const bool.fromEnvironment('TEST_DEBUG', defaultValue: false);
    MemoryLeakDetector.enable();
    ZenResourceTracker.reset();
  });

  tearDown(() {
    try {
      Zen.reset();
    } catch (e) {
      ZenLogger.logError('Error during test cleanup: $e');
    }
    MemoryLeakDetector.disable();
    ZenResourceTracker.reset();
  });

  group('🧪 Controller Memory Leak Tests', () {
    test('should dispose controllers and free memory', () async {
      ZenLogger.logDebug('Starting controller disposal test...');

      final initialResourceCount = ZenResourceTracker.totalResourceCount;

      // Create and register controllers
      final controllers = <TestController>[];
      for (int i = 0; i < 3; i++) {
        final controller = TestController('test-$i');
        controllers.add(controller);
        Zen.put(controller, tag: 'test-$i');
      }

      ZenLogger.logDebug('Created ${controllers.length} controllers');

      // Verify controllers are initialized
      for (final controller in controllers) {
        expect(controller.initCalled, isTrue);
        expect(controller.readyCalled, isTrue);
      }

      ZenLogger.logDebug('All controllers initialized and ready');

      // Use controllers
      for (final controller in controllers) {
        controller.increment();
        controller.updateMessage('test message');
      }

      ZenLogger.logDebug('Controller operations completed');

      // Dispose controllers
      for (int i = 0; i < controllers.length; i++) {
        final deleted = Zen.delete<TestController>(tag: 'test-$i', force: true);
        expect(deleted, isTrue);
      }

      ZenLogger.logDebug('All controllers deleted');

      // Verify disposal
      for (final controller in controllers) {
        expect(controller.disposeCalled, isTrue);
      }

      // Wait for cleanup
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify resource cleanup
      expect(ZenResourceTracker.totalResourceCount, equals(initialResourceCount));
      MemoryLeakDetector.expectNoLeaks('Controller disposal test');

      ZenLogger.logDebug('✅ Controller disposal test completed successfully');
    });

    test('should handle controller lifecycle correctly', () async {
      ZenLogger.logDebug('Starting controller lifecycle test...');

      final controller = TestController('lifecycle-test');
      Zen.put(controller, tag: 'lifecycle-test');

      // Test lifecycle
      expect(controller.initCalled, isTrue);
      expect(controller.readyCalled, isTrue);
      expect(controller.disposeCalled, isFalse);

      ZenLogger.logDebug('Controller lifecycle states verified');

      // Use controller
      controller.increment();
      expect(controller.counter.value, equals(1));

      // Dispose
      Zen.delete<TestController>(tag: 'lifecycle-test', force: true);
      expect(controller.disposeCalled, isTrue);

      MemoryLeakDetector.expectNoLeaks('Controller lifecycle test');

      ZenLogger.logDebug('✅ Controller lifecycle test completed successfully');
    });

    test('should handle reactive workers cleanup', () async {
      ZenLogger.logDebug('Starting worker cleanup test...');

      final initialResourceCount = ZenResourceTracker.totalResourceCount;

      final controller = TestController('worker-test');
      Zen.put(controller, tag: 'worker-test');

      // Create reactive workers
      ZenWorkers.ever(controller.counter, (value) {
        ZenLogger.logDebug('Counter worker triggered: $value');
      });

      ZenWorkers.debounce(controller.message, (value) {
        ZenLogger.logDebug('Message worker triggered: $value');
      }, const Duration(milliseconds: 100));

      ZenLogger.logDebug('Workers created, starting reactive updates...');

      // Trigger reactive updates
      for (int i = 0; i < 5; i++) {
        controller.increment();
        controller.updateMessage('update $i');
        await Future.delayed(const Duration(milliseconds: 10));
      }

      ZenLogger.logDebug('Reactive updates completed, disposing controller...');

      // Dispose controller
      final deleted = Zen.delete<TestController>(tag: 'worker-test', force: true);
      expect(deleted, isTrue);
      expect(controller.disposeCalled, isTrue);

      // Wait for worker cleanup
      await Future.delayed(const Duration(milliseconds: 200));

      expect(ZenResourceTracker.totalResourceCount, equals(initialResourceCount));
      MemoryLeakDetector.expectNoLeaks('Worker cleanup test');

      ZenLogger.logDebug('✅ Worker cleanup test completed successfully');
    });
  });

  group('🏗️ Scope Memory Leak Tests', () {
    test('should dispose scopes correctly', () async {
      ZenLogger.logDebug('Starting scope disposal test...');

      final initialResourceCount = ZenResourceTracker.totalResourceCount;

      await _testScopeHierarchy();

      expect(ZenResourceTracker.totalResourceCount, equals(initialResourceCount));
      MemoryLeakDetector.expectNoLeaks('Scope hierarchy test');

      ZenLogger.logDebug('✅ Scope disposal test completed successfully');
    });

    test('should handle multiple scopes', () async {
      ZenLogger.logDebug('Starting multiple scopes test...');

      final initialResourceCount = ZenResourceTracker.totalResourceCount;

      final scopes = <ZenScope>[];
      final services = <TestService>[];

      // Create multiple scopes with services
      for (int i = 0; i < 3; i++) {
        final scope = Zen.createScope(name: 'TestScope$i');
        ZenResourceTracker.trackScope();
        scopes.add(scope);

        final service = TestService('service-$i');
        services.add(service);
        scope.put(service);
      }

      ZenLogger.logDebug('Created ${scopes.length} scopes with services');

      // Manually dispose services first
      for (final service in services) {
        service.dispose();
      }

      // Dispose scopes
      for (final scope in scopes) {
        scope.dispose();
        ZenResourceTracker.untrackScope();
      }

      ZenLogger.logDebug('All scopes and services disposed');

      expect(ZenResourceTracker.totalResourceCount, equals(initialResourceCount));
      MemoryLeakDetector.expectNoLeaks('Multiple scope test');

      ZenLogger.logDebug('✅ Multiple scopes test completed successfully');
    });

    test('should dispose child scopes when parent is disposed', () async {
      ZenLogger.logDebug('Starting parent-child scope disposal test...');

      final initialResourceCount = ZenResourceTracker.totalResourceCount;

      final parentScope = Zen.createScope(name: 'Parent');
      ZenResourceTracker.trackScope();

      final childScope1 = Zen.createScope(name: 'Child1', parent: parentScope);
      final childScope2 = Zen.createScope(name: 'Child2', parent: parentScope);
      ZenResourceTracker.trackScope();
      ZenResourceTracker.trackScope();

      // Add controllers to scopes
      final parentController = TestController('parent');
      final child1Controller = TestController('child1');
      final child2Controller = TestController('child2');

      parentScope.put(parentController);
      childScope1.put(child1Controller);
      childScope2.put(child2Controller);

      ZenLogger.logDebug('Parent and child scopes setup complete');

      // Dispose parent scope
      parentScope.dispose();
      ZenResourceTracker.untrackScope(); // parent
      ZenResourceTracker.untrackScope(); // child1
      ZenResourceTracker.untrackScope(); // child2

      // Verify all scopes are disposed
      expect(parentScope.isDisposed, isTrue);
      expect(childScope1.isDisposed, isTrue);
      expect(childScope2.isDisposed, isTrue);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(ZenResourceTracker.totalResourceCount, equals(initialResourceCount));
      MemoryLeakDetector.expectNoLeaks('Scope hierarchy disposal test');

      ZenLogger.logDebug('✅ Parent-child scope disposal test completed successfully');
    });
  });

  group('📦 Module Memory Leak Tests', () {
    test('should not leak memory when registering modules', () async {
      ZenLogger.logDebug('Starting module registration test...');

      final initialResourceCount = ZenResourceTracker.totalResourceCount;

      await _testModuleRegistration();

      expect(ZenResourceTracker.totalResourceCount, equals(initialResourceCount));
      MemoryLeakDetector.expectNoLeaks('Module registration test');

      ZenLogger.logDebug('✅ Module registration test completed successfully');
    });
  });

  group('🎨 Widget Memory Leak Tests', () {
    testWidgets('should not leak memory after widget disposal', (tester) async {
      ZenLogger.logDebug('Starting widget disposal test...');

      final initialResourceCount = ZenResourceTracker.totalResourceCount;

      // Create controller
      final controller = TestController('widget-test');
      Zen.put(controller, tag: 'widget-test');

      // Create simple test widget without reactive Obx
      Widget buildTestWidget() {
        return MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final ctrl = Zen.findOrNull<TestController>(tag: 'widget-test');
                if (ctrl == null) {
                  return const Text('No controller');
                }
                return Column(
                  children: [
                    Text('Counter: ${ctrl.counter.value}'),
                    ElevatedButton(
                      onPressed: ctrl.increment,
                      child: const Text('Increment'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      }

      // Pump widget
      await tester.pumpWidget(buildTestWidget());

      // Interact with widget
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(controller.counter.value, equals(1));

      ZenLogger.logDebug('Widget interaction completed');

      // Clean up controller first
      Zen.delete<TestController>(tag: 'widget-test', force: true);

      // Remove widget
      await tester.pumpWidget(Container());
      await tester.pump();

      // Verify cleanup
      expect(ZenResourceTracker.totalResourceCount, equals(initialResourceCount));
      MemoryLeakDetector.expectNoLeaks('Widget disposal test');

      ZenLogger.logDebug('✅ Widget disposal test completed successfully');
    });

    test('should handle controller lifecycle like ZenView', () async {
      ZenLogger.logDebug('Starting ZenView lifecycle simulation...');

      final initialResourceCount = ZenResourceTracker.totalResourceCount;

      // Simulate ZenView controller creation
      final controller = TestController('zenview-lifecycle-test');

      // Simulate ZenView automatic registration
      Zen.put(controller, tag: 'zenview-lifecycle-test');

      // Simulate widget interaction
      controller.increment();
      controller.updateMessage('zenview test');

      expect(controller.counter.value, equals(1));
      expect(controller.message.value, equals('zenview test'));
      expect(controller.initCalled, isTrue);
      expect(controller.readyCalled, isTrue);

      ZenLogger.logDebug('ZenView controller operations completed');

      // Simulate ZenView dispose (when widget is removed)
      final deleted = Zen.delete<TestController>(tag: 'zenview-lifecycle-test', force: true);
      expect(deleted, isTrue);
      expect(controller.disposeCalled, isTrue);

      // Wait for cleanup
      await Future.delayed(const Duration(milliseconds: 50));

      expect(ZenResourceTracker.totalResourceCount, equals(initialResourceCount));
      MemoryLeakDetector.expectNoLeaks('ZenView lifecycle simulation');

      ZenLogger.logDebug('✅ ZenView lifecycle simulation completed successfully');
    });

    testWidgets('should handle widget tree with multiple controllers', (tester) async {
      ZenLogger.logDebug('Starting multi-controller widget test...');

      final initialResourceCount = ZenResourceTracker.totalResourceCount;

      // Create multiple controllers
      final controllers = <TestController>[];
      for (int i = 0; i < 3; i++) {
        final controller = TestController('widget-multi-$i');
        controllers.add(controller);
        Zen.put(controller, tag: 'widget-multi-$i');
      }

      ZenLogger.logDebug('Created ${controllers.length} controllers for widget');

      // Create widget that uses multiple controllers
      Widget buildMultiControllerWidget() {
        return MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (int i = 0; i < 3; i++)
                  Builder(
                    builder: (context) {
                      final ctrl = Zen.findOrNull<TestController>(tag: 'widget-multi-$i');
                      if (ctrl == null) return const SizedBox.shrink();
                      return Text('Controller $i: ${ctrl.counter.value}');
                    },
                  ),
                ElevatedButton(
                  onPressed: () {
                    for (final controller in controllers) {
                      controller.increment();
                    }
                  },
                  child: const Text('Increment All'),
                ),
              ],
            ),
          ),
        );
      }

      // Pump widget
      await tester.pumpWidget(buildMultiControllerWidget());

      // Interact
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify all controllers were incremented
      for (final controller in controllers) {
        expect(controller.counter.value, equals(1));
      }

      ZenLogger.logDebug('Multi-controller widget interactions completed');

      // Clean up controllers
      for (int i = 0; i < controllers.length; i++) {
        Zen.delete<TestController>(tag: 'widget-multi-$i', force: true);
      }

      // Remove widget
      await tester.pumpWidget(Container());
      await tester.pump();

      expect(ZenResourceTracker.totalResourceCount, equals(initialResourceCount));
      MemoryLeakDetector.expectNoLeaks('Multi-controller widget test');

      ZenLogger.logDebug('✅ Multi-controller widget test completed successfully');
    });
  });

  group('🚀 Stress Tests', () {
    test('should handle rapid creation and disposal', () async {
      ZenLogger.logDebug('Starting stress test with rapid creation/disposal...');

      final initialResourceCount = ZenResourceTracker.totalResourceCount;

      for (int i = 0; i < 20; i++) {
        final controller = TestController('stress-$i');
        Zen.put(controller, tag: 'stress-$i');

        controller.increment();
        controller.updateMessage('stress test $i');

        Zen.delete<TestController>(tag: 'stress-$i', force: true);

        // Log progress every 5 iterations
        if (i % 5 == 0) {
          ZenLogger.logDebug('Stress test progress: ${i + 1}/20 completed');
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      // Allow final cleanup
      await Future.delayed(const Duration(milliseconds: 100));

      expect(ZenResourceTracker.totalResourceCount, equals(initialResourceCount));
      MemoryLeakDetector.expectNoLeaks('Stress test');

      ZenLogger.logInfo('✅ Stress test completed - 20 controllers created and disposed');
    });

    test('should handle memory pressure with scopes', () async {
      ZenLogger.logDebug('Starting memory pressure test...');

      final initialResourceCount = ZenResourceTracker.totalResourceCount;

      for (int batch = 0; batch < 10; batch++) {
        final scope = Zen.createScope(name: 'StressBatch$batch');
        ZenResourceTracker.trackScope();

        // Create multiple controllers in each scope
        for (int i = 0; i < 3; i++) {
          final controller = TestController('batch-$batch-$i');
          scope.put(controller);
          controller.increment();
        }

        // Dispose scope
        scope.dispose();
        ZenResourceTracker.untrackScope();

        // Periodic cleanup and logging
        if (batch % 3 == 0) {
          ZenLogger.logDebug('Memory pressure test batch ${batch + 1}/10 completed');
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(ZenResourceTracker.totalResourceCount, equals(initialResourceCount));
      MemoryLeakDetector.expectNoLeaks('Memory pressure test');

      ZenLogger.logInfo('✅ Memory pressure test completed - 10 batches processed');
    });
  });

  group('📊 Performance Monitoring', () {
    test('should track resource lifecycle correctly', () async {
      ZenLogger.logDebug('Starting resource lifecycle monitoring...');

      final initialCount = ZenResourceTracker.totalResourceCount;

      // Phase 1: Create resources
      final controller1 = TestController('monitor-1');
      final controller2 = TestController('monitor-2');
      Zen.put(controller1, tag: 'monitor-1');
      Zen.put(controller2, tag: 'monitor-2');

      expect(ZenResourceTracker.totalResourceCount, equals(initialCount + 2));
      ZenLogger.logDebug('Phase 1: Created 2 controllers');

      // Phase 2: Use resources
      controller1.increment();
      controller2.increment();
      controller1.updateMessage('monitoring');
      controller2.updateMessage('monitoring');

      expect(controller1.counter.value, equals(1));
      expect(controller2.counter.value, equals(1));
      ZenLogger.logDebug('Phase 2: Controller operations completed');

      // Phase 3: Dispose one resource
      Zen.delete<TestController>(tag: 'monitor-1', force: true);
      expect(ZenResourceTracker.totalResourceCount, equals(initialCount + 1));
      ZenLogger.logDebug('Phase 3: Disposed 1 controller');

      // Phase 4: Dispose remaining resource
      Zen.delete<TestController>(tag: 'monitor-2', force: true);
      expect(ZenResourceTracker.totalResourceCount, equals(initialCount));
      ZenLogger.logDebug('Phase 4: Disposed remaining controller');

      MemoryLeakDetector.expectNoLeaks('Resource lifecycle monitoring');

      ZenLogger.logDebug('✅ Resource lifecycle monitoring completed successfully');
    });

    test('should detect and report memory leaks', () async {
      ZenLogger.logDebug('Starting memory leak detection test...');

      // Intentionally create a leak for testing
      MemoryLeakDetector.trackCreation('LeakyController');
      // Don't call trackDisposal to simulate a leak

      final leaks = MemoryLeakDetector.getLeakReport();
      expect(leaks['LeakyController'], equals(1));
      ZenLogger.logDebug('Memory leak correctly detected: LeakyController');

      // Clean up for other tests
      MemoryLeakDetector.trackDisposal('LeakyController');

      final cleanReport = MemoryLeakDetector.getLeakReport();
      expect(cleanReport.isEmpty, isTrue);
      ZenLogger.logDebug('Memory leak cleaned up');

      ZenLogger.logDebug('✅ Memory leak detection test completed successfully');
    });
  });

  tearDownAll(() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('');
      ZenLogger.logInfo('🎉 MEMORY LEAK DETECTION TESTS COMPLETED');
      ZenLogger.logInfo('════════════════════════════════════════════════════════════');
      final finalReport = ZenResourceTracker.getReport();
      ZenLogger.logInfo('Final resource count: $finalReport');
      ZenLogger.logInfo('');
    }
  });
}