// test/widgets/zen_route_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// =============================================================================
// TEST SERVICES AND MODULES FOR ZEN_MODULE_PAGE TESTING
// =============================================================================

class TestService {
  final String name;
  bool disposed = false;

  TestService(this.name);

  void dispose() => disposed = true;
}

class ParentService {
  final String data;
  bool disposed = false;

  ParentService(this.data);

  void dispose() => disposed = true;
}

class ChildService {
  final ParentService parentService;
  bool disposed = false;

  ChildService(this.parentService);

  void dispose() => disposed = true;
}

class DatabaseService {
  final String connectionString;
  bool isConnected = false;
  bool disposed = false;

  DatabaseService(this.connectionString);

  void connect() => isConnected = true;
  void dispose() => disposed = true;
}

class UserService {
  final DatabaseService databaseService;
  bool disposed = false;

  UserService(this.databaseService);

  void dispose() => disposed = true;
}

// Test controller for ZenBuilder integration
class TestController extends ZenController {
  int value = 0;

  void increment() {
    value++;
    update();
  }
}

// Test modules
class BasicTestModule extends ZenModule {
  bool initCalled = false;
  bool disposeCalled = false;

  @override
  String get name => 'BasicTestModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService('basic'));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    initCalled = true;
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    disposeCalled = true;
  }
}

class ParentTestModule extends ZenModule {
  bool initCalled = false;
  bool disposeCalled = false;

  @override
  String get name => 'ParentTestModule';

  @override
  void register(ZenScope scope) {
    scope.put<ParentService>(ParentService('parent-data'));
    scope.put<DatabaseService>(DatabaseService('parent://database'));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    initCalled = true;
    final db = scope.find<DatabaseService>();
    db?.connect();
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    disposeCalled = true;
    final db = scope.find<DatabaseService>();
    db?.dispose();
  }
}

class ChildTestModule extends ZenModule {
  bool initCalled = false;
  bool disposeCalled = false;

  @override
  String get name => 'ChildTestModule';

  @override
  void register(ZenScope scope) {
    final parentService = scope.find<ParentService>();
    if (parentService != null) {
      scope.put<ChildService>(ChildService(parentService));
    }

    final databaseService = scope.find<DatabaseService>();
    if (databaseService != null) {
      scope.put<UserService>(UserService(databaseService));
    }
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    initCalled = true;
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    disposeCalled = true;
  }
}

class ControllerTestModule extends ZenModule {
  @override
  String get name => 'ControllerTestModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestController>(TestController());
  }
}

class EmptyTestModule extends ZenModule {
  @override
  String get name => 'EmptyTestModule';

  @override
  void register(ZenScope scope) {
    // Empty module - no registrations
  }
}

class FailingModule extends ZenModule {
  @override
  String get name => 'FailingModule';

  @override
  void register(ZenScope scope) {
    throw Exception('Registration failed');
  }
}

class InitFailingModule extends ZenModule {
  @override
  String get name => 'InitFailingModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService('failing'));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    throw Exception('Initialization failed');
  }
}

// Synchronous module that simulates loading behavior without actual async delays
class LoadingSimulationModule extends ZenModule {
  bool initCalled = false;

  @override
  String get name => 'LoadingSimulationModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService('loading-sim'));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    // Simulate initialization without actual delays
    initCalled = true;
  }
}

// Tracking modules for cleanup tests
class HomeModule extends ZenModule {
  final List<String> disposedServices;

  HomeModule(this.disposedServices);

  @override
  String get name => 'HomeModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService('home'));
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    final service = scope.find<TestService>();
    if (service != null) {
      service.dispose();
      disposedServices.add('home');
    }
  }
}

class DepartmentsModule extends ZenModule {
  final List<String> disposedControllers;
  final List<String> disposedServices;

  DepartmentsModule(this.disposedControllers, this.disposedServices);

  @override
  String get name => 'DepartmentsModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestController>(TestController());
    scope.put<TestService>(TestService('departments'));
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    final controller = scope.find<TestController>();
    final service = scope.find<TestService>();

    controller?.onClose();
    disposedControllers.add('departments');

    service?.dispose();
    disposedServices.add('departments');
  }
}

class DepartmentDetailModule extends ZenModule {
  final List<String> disposedControllers;
  final List<String> disposedServices;

  DepartmentDetailModule(this.disposedControllers, this.disposedServices);

  @override
  String get name => 'DepartmentDetailModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestController>(TestController());
    scope.put<TestService>(TestService('department-detail'));
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    final controller = scope.find<TestController>();
    final service = scope.find<TestService>();

    controller?.onClose();
    disposedControllers.add('department-detail');

    service?.dispose();
    disposedServices.add('department-detail');
  }
}

class EmployeeModule extends ZenModule {
  final List<String> disposedControllers;
  final List<String> disposedServices;

  EmployeeModule(this.disposedControllers, this.disposedServices);

  @override
  String get name => 'EmployeeModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestController>(TestController());
    scope.put<TestService>(TestService('employee'));
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    final controller = scope.find<TestController>();
    final service = scope.find<TestService>();

    controller?.onClose();
    disposedControllers.add('employee');

    service?.dispose();
    disposedServices.add('employee');
  }
}

class TrackingModule extends ZenModule {
  final String moduleName;
  final List<String> disposedScopes;

  TrackingModule(this.moduleName, this.disposedScopes);

  @override
  String get name => '${moduleName}Module';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService(moduleName));
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    disposedScopes.add(moduleName);
  }
}

class CountingController extends ZenController {
  static int _globalCreationCount = 0;
  static int get globalCreationCount => _globalCreationCount;
  static void resetGlobalCount() => _globalCreationCount = 0;

  CountingController() {
    _globalCreationCount++;
  }

  @override
  void onClose() {
    super.onClose();
    _globalCreationCount--;
  }
}

class CountingModule extends ZenModule {
  @override
  String get name => 'CountingModule';

  @override
  void register(ZenScope scope) {
    scope.put<CountingController>(CountingController());
  }
}

// Test pages
class TestPage extends StatelessWidget {
  final String content;

  const TestPage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(content),
      ),
    );
  }
}

class ZenBuilderInModuleTestPage extends StatelessWidget {
  const ZenBuilderInModuleTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Using ZenBuilder with scope-provided controller (no tag)
          ZenBuilder<TestController>(
            builder: (context, controller) {
              return Text('Scoped Value: ${controller.value}');
            },
          ),
          // Using ZenBuilder with locally created controller (with tag to avoid conflicts)
          ZenBuilder<TestController>(
            tag: 'local',
            create: () => TestController(),
            builder: (context, controller) {
              return Text('Local Value: ${controller.value}');
            },
          ),
        ],
      ),
    );
  }
}

class ScopeAwarePage extends StatelessWidget {
  final Function(ZenScope scope)? onScopeReceived;

  const ScopeAwarePage({super.key, this.onScopeReceived});

  @override
  Widget build(BuildContext context) {
    final scope = context.zenScope;
    if (scope != null && onScopeReceived != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onScopeReceived!(scope);
      });
    }

    final service = context.findInScopeOrNull<TestService>();
    if (service == null) {
      return const Center(child: Text('Service not found'));
    }

    return Scaffold(
      body: Center(
        child: Text('Service: ${service.name}'),
      ),
    );
  }
}

// =============================================================================
// ZEN_MODULE_PAGE TESTS
// =============================================================================

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    Zen.reset();
    Zen.init();
    ZenConfig.applyEnvironment(ZenEnvironment.test); // Apply test settings
    ZenConfig.logLevel = ZenLogLevel.none; // Override to disable all logs
    ZenScopeManager.disposeAll();
    ZenScopeStackTracker.clear();
    CountingController.resetGlobalCount();
  });

  tearDown(() {
    ZenScopeManager.disposeAll();
    ZenScopeStackTracker.clear();
    Zen.reset();
  });

  group('ZenModulePage Basic Functionality', () {
    testWidgets('should create and provide scope to child widget',
        (tester) async {
      final module = BasicTestModule();
      ZenScope? capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: ScopeAwarePage(
              onScopeReceived: (scope) => capturedScope = scope,
            ),
            scopeName: 'TestScope',
          ),
        ),
      );

      // Wait for initialization
      await tester.pumpAndSettle();

      // Verify scope was created and provided
      expect(capturedScope, isNotNull);
      expect(capturedScope!.name, 'TestScope');
      expect(module.initCalled, isTrue);

      // Verify service is accessible
      final service = capturedScope!.find<TestService>();
      expect(service, isNotNull);
      expect(service!.name, 'basic');

      // Verify UI shows service
      expect(find.text('Service: basic'), findsOneWidget);
    });

    testWidgets('should generate scope name if not provided', (tester) async {
      final module = BasicTestModule();
      ZenScope? capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: ScopeAwarePage(
              onScopeReceived: (scope) => capturedScope = scope,
            ),
            // No scopeName provided
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);
      expect(capturedScope!.name, startsWith('ZenRoute_'));
      expect(capturedScope!.name, contains('ScopeAwarePage'));
    });

    testWidgets('should show custom loading widget', (tester) async {
      final customLoading = Container(
        key: const ValueKey('custom-loading'),
        child: const Text('Custom Loading...'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => LoadingSimulationModule(),
            page: const TestPage(content: 'Ready'),
            loadingWidget: customLoading,
          ),
        ),
      );

      // Since LoadingSimulationModule completes synchronously,
      // we should see the ready page immediately
      await tester.pumpAndSettle();
      expect(find.text('Ready'), findsOneWidget);
    });
  });

  group('ZenModulePage Hierarchical Scoping', () {
    testWidgets(
        'should create parent-child scope relationship with parent scope',
        (tester) async {
      // First create parent scope directly via ZenScopeManager
      final parentModule = ParentTestModule();
      final parentScope = ZenScopeManager.getOrCreateScope(
        name: 'ParentScope',
      );

      // Register the parent module in the scope
      parentModule.register(parentScope);
      await parentModule.onInit(parentScope);

      // Verify parent scope is created and tracked
      expect(ZenScopeManager.isTracking('ParentScope'), isTrue);
      expect(ZenScopeManager.getScope('ParentScope'), same(parentScope));

      // Now create child module page that inherits from parent
      final childModule = ChildTestModule();
      ZenScope? childScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => childModule,
            page: ScopeAwarePage(
              onScopeReceived: (scope) => childScope = scope,
            ),
            scopeName: 'ChildScope',
            parentScope: parentScope,
            useParentScope:
                true, // 🔥 This prevents the parent scope from being disposed
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify child scope inherits from parent
      expect(childScope, isNotNull);
      expect(childScope!.name, 'ChildScope');
      expect(childScope!.parent, same(parentScope));

      // Verify child can access parent services
      final parentService = childScope!.find<ParentService>();
      expect(parentService, isNotNull);
      expect(parentService!.data, 'parent-data');

      // Verify child has its own services that use parent dependencies
      final childService = childScope!.find<ChildService>();
      expect(childService, isNotNull);
      expect(childService!.parentService, same(parentService));

      // Verify child scope is tracked as child of parent
      final childScopes = ZenScopeManager.getChildScopes('ParentScope');
      expect(childScopes, contains('ChildScope'));
    });

    testWidgets('should handle missing parent scope gracefully',
        (tester) async {
      final module = BasicTestModule();

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: const TestPage(content: 'Orphan'),
            scopeName: 'OrphanScope',
            parentScope: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should still work, falling back to root scope as parent
      expect(find.text('Orphan'), findsOneWidget);
      expect(module.initCalled, isTrue);
    });
  });

  group('ZenModulePage Auto-Dispose Logic', () {
    testWidgets('should use smart defaults for auto-dispose', (tester) async {
      // Test 1: No parent → auto-dispose = true
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => BasicTestModule(),
            page: const TestPage(content: 'Root Level'),
            scopeName: 'RootLevelScope',
            // No autoDispose specified, no parent → should default to true
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Root Level'), findsOneWidget);

      // Test 2: With parent → auto-dispose = false
      final parentScope = ZenScopeManager.getOrCreateScope(
        name: 'SomeParent',
        autoDispose: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => BasicTestModule(),
            page: const TestPage(content: 'Child Level'),
            scopeName: 'ChildLevelScope',
            parentScope: parentScope,
            // No autoDispose specified, has parent → should default to false
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Child Level'), findsOneWidget);
    });

    testWidgets('should respect explicit autoDispose setting', (tester) async {
      final parentScope = ZenScopeManager.getOrCreateScope(
        name: 'SomeParent',
        autoDispose: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => BasicTestModule(),
            page: const TestPage(content: 'Explicit'),
            scopeName: 'ExplicitScope',
            parentScope: parentScope,
            autoDispose: true, // Explicit override
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Explicit'), findsOneWidget);
    });

    testWidgets('should properly dispose auto-dispose scopes', (tester) async {
      ZenScopeManager.disposeAll();

      // Create parent scope manually using ZenScopeManager (persistent)
      final parentScope = ZenScopeManager.getOrCreateScope(
        name: 'ParentScope',
        autoDispose: false, // Make it persistent so it won't auto-dispose
      );

      // Register a dummy service in parent to make it realistic
      parentScope.put<TestService>(TestService('parent-service'));

      ZenScope? childScope;

      // Test just the child widget with auto-dispose
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => ChildTestModule(),
            page: ScopeAwarePage(
              onScopeReceived: (scope) => childScope = scope,
            ),
            scopeName: 'AutoDisposeChild',
            parentScope: parentScope, // Use persistent parent
            autoDispose: true, // Child will auto-dispose
            useParentScope: true, // 🔥 THIS IS KEY - prevents cleanup of parent
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify child scope was created with parent
      expect(childScope, isNotNull);
      expect(childScope!.parent, equals(parentScope));
      expect(parentScope.isDisposed, isFalse);

      // Remove child widget (should dispose child scope)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Child Removed')),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify child disposed, parent survived
      expect(childScope!.isDisposed, isTrue);
      expect(parentScope.isDisposed, isFalse);
    });
  });

  group('ZenRoute Automatic Scope Cleanup', () {
    testWidgets(
        'should automatically clean up scopes when navigating back to routes with useParentScope=false',
        (tester) async {
      // Track which controllers and services get disposed
      final disposedControllers = <String>[];
      final disposedServices = <String>[];

      // Create the main app with proper routing
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => HomeModule(disposedServices),
            page: HomePage(
              onNavigateToDepartments: () =>
                  Navigator.of(tester.element(find.byType(HomePage))).push(
                MaterialPageRoute(
                  builder: (context) => ZenRoute(
                    moduleBuilder: () => DepartmentsModule(
                        disposedControllers, disposedServices),
                    page: DepartmentsPage(
                      onNavigateToDetail: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ZenRoute(
                            moduleBuilder: () => DepartmentDetailModule(
                                disposedControllers, disposedServices),
                            page: DepartmentDetailPage(
                              onNavigateToEmployee: () =>
                                  Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ZenRoute(
                                    moduleBuilder: () => EmployeeModule(
                                        disposedControllers, disposedServices),
                                    page: EmployeePage(
                                      onNavigateHome: () =>
                                          Navigator.of(context)
                                              .pushAndRemoveUntil(
                                        MaterialPageRoute(
                                          builder: (context) => ZenRoute(
                                            moduleBuilder: () =>
                                                HomeModule(disposedServices),
                                            page: const TestPage(
                                                content: 'Home Again'),
                                            scopeName: 'HomeScope2',
                                            useParentScope:
                                                false, // Reset point
                                          ),
                                        ),
                                        (route) =>
                                            false, // Remove all previous routes
                                      ),
                                    ),
                                    scopeName: 'EmployeeScope',
                                    useParentScope: true,
                                  ),
                                ),
                              ),
                            ),
                            scopeName: 'DepartmentDetailScope',
                            useParentScope: true,
                          ),
                        ),
                      ),
                    ),
                    scopeName: 'DepartmentsScope',
                    useParentScope: true,
                  ),
                ),
              ),
            ),
            scopeName: 'HomeScope',
            useParentScope: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify home scope exists and page is displayed
      expect(ZenScopeManager.getScope('HomeScope'), isNotNull);
      expect(find.text('Home'), findsOneWidget);

      // Navigate to Departments
      await tester.tap(find.text('Go to Departments'));
      await tester.pumpAndSettle();

      // Verify departments scope exists
      expect(ZenScopeManager.getScope('HomeScope'), isNotNull);
      expect(ZenScopeManager.getScope('DepartmentsScope'), isNotNull);
      expect(find.text('Departments'), findsOneWidget);

      // Navigate to Department Detail
      await tester.tap(find.text('Go to Detail'));
      await tester.pumpAndSettle();

      // Verify department detail scope exists
      expect(ZenScopeManager.getScope('HomeScope'), isNotNull);
      expect(ZenScopeManager.getScope('DepartmentsScope'), isNotNull);
      expect(ZenScopeManager.getScope('DepartmentDetailScope'), isNotNull);
      expect(find.text('Department Detail'), findsOneWidget);

      // Navigate to Employee
      await tester.tap(find.text('Go to Employee'));
      await tester.pumpAndSettle();

      // Verify all scopes exist (navigation stack: Home -> Departments -> Detail -> Employee)
      expect(ZenScopeManager.getScope('HomeScope'), isNotNull);
      expect(ZenScopeManager.getScope('DepartmentsScope'), isNotNull);
      expect(ZenScopeManager.getScope('DepartmentDetailScope'), isNotNull);
      expect(ZenScopeManager.getScope('EmployeeScope'), isNotNull);
      expect(find.text('Employee'), findsOneWidget);

      // Navigate back to Home using pushAndRemoveUntil (simulates reset navigation)
      await tester.tap(find.text('Go to Home'));
      await tester.pumpAndSettle();

      // VERIFICATION: Only the new home scope should remain
      expect(ZenScopeManager.getScope('HomeScope2'), isNotNull);
      expect(ZenScopeManager.getScope('HomeScope'), isNull);
      expect(ZenScopeManager.getScope('DepartmentsScope'), isNull);
      expect(ZenScopeManager.getScope('DepartmentDetailScope'), isNull);
      expect(ZenScopeManager.getScope('EmployeeScope'), isNull);

      // Verify all controllers and services were disposed
      expect(disposedControllers,
          containsAll(['departments', 'department-detail', 'employee']));
      expect(disposedServices,
          containsAll(['departments', 'department-detail', 'employee']));

      expect(find.text('Home Again'), findsOneWidget);
    });

    testWidgets(
        'should cleanup scopes via stack tracking when popping back to useParentScope=false route',
        (tester) async {
      ZenConfig.logLevel = ZenLogLevel.debug; // Enable to see cleanup logs

      // Simulate the exact scenario from your logs
      final disposedScopes = <String>[];

      // 1. Start with Home (useParentScope=false)
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => TrackingModule('Home', disposedScopes),
            page: const TestPage(content: 'Home'),
            scopeName: 'HomeScope',
            useParentScope: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Add Departments to stack
      ZenScopeStackTracker.pushScope('DepartmentsScope', useParentScope: true);
      ZenScopeManager.getOrCreateScope(
          name: 'DepartmentsScope', autoDispose: false);

      // Add DepartmentDetail to stack
      ZenScopeStackTracker.pushScope('DepartmentDetailScope',
          useParentScope: true);
      ZenScopeManager.getOrCreateScope(
          name: 'DepartmentDetailScope', autoDispose: false);

      // Add EmployeeProfile to stack
      ZenScopeStackTracker.pushScope('EmployeeProfileScope',
          useParentScope: true);
      ZenScopeManager.getOrCreateScope(
          name: 'EmployeeProfileScope', autoDispose: false);

      // Verify stack is built
      final stack = ZenScopeStackTracker.getCurrentStack();
      expect(stack, contains('HomeScope'));
      expect(stack, contains('DepartmentsScope'));
      expect(stack, contains('DepartmentDetailScope'));
      expect(stack, contains('EmployeeProfileScope'));

      // Simulate popping back to HomeScope (like in your logs)
      ZenScopeStackTracker.popScope('EmployeeProfileScope');
      ZenScopeStackTracker.popScope('DepartmentDetailScope');
      ZenScopeStackTracker.popScope('DepartmentsScope');

      // At this point, automatic cleanup should have been triggered
      // because we popped back to HomeScope which has useParentScope=false

      // Verify cleanup occurred
      expect(ZenScopeManager.getScope('DepartmentsScope'), isNull);
      expect(ZenScopeManager.getScope('DepartmentDetailScope'), isNull);
      expect(ZenScopeManager.getScope('EmployeeProfileScope'), isNull);
      expect(ZenScopeManager.getScope('HomeScope'), isNotNull); // Should remain

      // Verify only HomeScope and RootScope remain
      final remainingScopes = ZenScopeManager.getAllScopes()
          .where((scope) => !scope.isDisposed)
          .map((scope) => scope.name)
          .toList();

      expect(remainingScopes, containsAll(['HomeScope', 'RootScope']));
      expect(remainingScopes.length, equals(2));
    });

    testWidgets(
        'should prevent controller accumulation across multiple navigation cycles',
        (tester) async {
      // This test simulates the original problem: controllers accumulating
      CountingController.resetGlobalCount();

      // Test multiple complete navigation cycles using separate test runs
      for (int cycle = 1; cycle <= 3; cycle++) {
        // Create a fresh app for each cycle to simulate real app usage
        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/home',
            routes: {
              '/home': (context) => ZenRoute(
                    moduleBuilder: () => BasicTestModule(),
                    page: const HomePage2(),
                    scopeName: 'HomeScope',
                    useParentScope: false, // Reset point
                  ),
              '/feature': (context) => ZenRoute(
                    moduleBuilder: () => CountingModule(),
                    page: const FeaturePage(),
                    scopeName: 'FeatureScope',
                    useParentScope: true,
                  ),
            },
          ),
        );
        await tester.pumpAndSettle();

        // Verify home page is displayed
        expect(find.text('Home Page'), findsOneWidget);
        expect(find.text('Go to Feature'), findsOneWidget);

        // Navigate to feature page
        await tester.tap(find.text('Go to Feature'));
        await tester.pumpAndSettle();

        // Verify feature page is displayed and controller is created
        expect(find.text('Feature Page'), findsOneWidget);
        expect(find.text('Back to Home'), findsOneWidget);

        // Verify scope exists and controller was created
        final featureScope = ZenScopeManager.getScope('FeatureScope');
        expect(featureScope, isNotNull);
        expect(featureScope!.exists<CountingController>(), isTrue);

        // Navigate back to home using route replacement (triggers cleanup)
        await tester.tap(find.text('Back to Home'));
        await tester.pumpAndSettle();

        // Verify we're back home
        expect(find.text('Home Page'), findsOneWidget);

        // Verify feature scope is cleaned up
        expect(ZenScopeManager.getScope('FeatureScope'), isNull);
      }

      // Verify no controller accumulation occurred
      // If cleanup is working properly, count should be 0 (all disposed)
      expect(CountingController.globalCreationCount, equals(0),
          reason:
              'Controllers should be properly disposed after each cycle, not accumulated');
    });
  });

  group('ZenModulePage Error Handling', () {
    testWidgets('should handle module registration errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => FailingModule(),
            page: const TestPage(content: 'Should not see this'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show error UI
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text('Failed to load module'), findsOneWidget);
      expect(find.textContaining('Registration failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should handle module initialization errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => InitFailingModule(),
            page: const TestPage(content: 'Should not see this'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show error UI
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text('Failed to load module'), findsOneWidget);
      expect(find.textContaining('Initialization failed'), findsOneWidget);
    });

    testWidgets('should show custom error widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => FailingModule(),
            page: const TestPage(content: 'Should not see this'),
            onError: (error) => Container(
              key: const ValueKey('custom-error'),
              child: Text('Custom Error: $error'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('custom-error')), findsOneWidget);
      expect(find.text('Custom Error: Exception: Registration failed'),
          findsOneWidget);
    });

    testWidgets('should retry on error', (tester) async {
      var failCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () {
              failCount++;
              if (failCount == 1) {
                return FailingModule();
              }
              return BasicTestModule();
            },
            page: const TestPage(content: 'Success after retry'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show error first
      expect(find.text('Failed to load module'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Should show success page
      expect(find.text('Success after retry'), findsOneWidget);
      expect(failCount, 2);
    });
  });

  group('ZenModulePage Scope Management Integration', () {
    testWidgets('should integrate with ZenScopeManager correctly',
        (tester) async {
      final module = BasicTestModule();

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: const TestPage(content: 'Managed'),
            scopeName: 'ManagedScope',
            autoDispose: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify scope is tracked by ZenScopeManager
      expect(ZenScopeManager.isTracking('ManagedScope'), isTrue);
      final scope = ZenScopeManager.getScope('ManagedScope');
      expect(scope, isNotNull);
      expect(scope!.name, 'ManagedScope');

      // Verify service is accessible through scope
      final service = scope.find<TestService>();
      expect(service, isNotNull);
      expect(service!.name, 'basic');
    });

    testWidgets('should handle auto-dispose scopes correctly', (tester) async {
      ZenScope? capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => BasicTestModule(),
            page: ScopeAwarePage(
              onScopeReceived: (scope) => capturedScope = scope,
            ),
            scopeName: 'AutoDisposeScope',
            autoDispose: true, // This makes it auto-dispose
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Auto-dispose scopes ARE tracked while active, but not as persistent scopes
      expect(ZenScopeManager.isTracking('AutoDisposeScope'), isTrue);

      // The scope itself should exist and work
      expect(capturedScope, isNotNull);
      expect(capturedScope!.name, 'AutoDisposeScope');

      // Service should be accessible
      final service = capturedScope!.find<TestService>();
      expect(service, isNotNull);
      expect(service!.name, 'basic');

      // Store reference to verify disposal later
      final scopeToCheck = capturedScope!;

      // Now dispose the widget by replacing it
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Widget Disposed'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // NOW the auto-dispose scope should no longer be tracked
      expect(ZenScopeManager.isTracking('AutoDisposeScope'), isFalse);

      // And the scope should be disposed
      expect(scopeToCheck.isDisposed, isTrue);
    });
  });

  group('ZenModulePage Widget Tree Integration', () {
    testWidgets('should provide scope to descendant widgets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => BasicTestModule(),
            page: const ScopeConsumerPage(),
            scopeName: 'TreeScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Found service: basic'), findsOneWidget);
    });

    testWidgets('should display TestService from scope', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => BasicTestModule(),
            page: const ZenScopeServiceTestPage(),
            scopeName: 'ServiceTestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Builder found: basic'), findsOneWidget);
    });
  });

  group('ZenBuilder Integration with ZenRoute', () {
    testWidgets('should work with controllers from module scope',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => ControllerTestModule(),
            page: const ZenBuilderInModuleTestPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify both builders show their initial values
      expect(find.text('Scoped Value: 0'), findsOneWidget);
      expect(find.text('Local Value: 0'), findsOneWidget);

      // Get the scoped controller and update it
      final scope =
          tester.element(find.byType(ZenBuilderInModuleTestPage)).zenScope!;
      final controller = scope.find<TestController>()!;
      controller.increment();
      await tester.pump();

      // Verify only the scoped builder updated
      expect(find.text('Scoped Value: 1'), findsOneWidget);
      expect(find.text('Local Value: 0'), findsOneWidget);
    });

    testWidgets('should handle controller lifecycle within ZenRoute',
        (tester) async {
      late ZenScope capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => ControllerTestModule(),
            page: Builder(
              builder: (context) {
                capturedScope = context.zenScope!;
                return const ZenBuilderInModuleTestPage();
              },
            ),
            autoDispose: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify controller exists in scope
      expect(capturedScope.find<TestController>(), isNotNull);

      // Remove the widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Verify scope is disposed
      expect(capturedScope.isDisposed, isTrue);

      // Verify controller is no longer accessible (returns null from disposed scope)
      expect(capturedScope.find<TestController>(), isNull);
    });

    testWidgets('should support multiple ZenBuilders with scope inheritance',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => ControllerTestModule(),
            page: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    ZenBuilder<TestController>(
                      builder: (context, ctrl) => Text('A: ${ctrl.value}'),
                    ),
                    // Fix: Wrap the nested ZenRoute in Flexible or Expanded
                    Flexible(
                      child: ZenRoute(
                        moduleBuilder: () => EmptyTestModule(),
                        useParentScope: true,
                        page: ZenBuilder<TestController>(
                          builder: (context, ctrl) => Text('B: ${ctrl.value}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify both builders show the same value
      expect(find.text('A: 0'), findsOneWidget);
      expect(find.text('B: 0'), findsOneWidget);

      // Update the controller
      final scope = tester.element(find.text('A: 0')).zenScope!;
      final controller = scope.find<TestController>()!;
      controller.increment();
      await tester.pump();

      // Verify both builders updated
      expect(find.text('A: 1'), findsOneWidget);
      expect(find.text('B: 1'), findsOneWidget);
    });

    testWidgets(
        'should resolve named parent scope across navigation boundaries',
        (tester) async {
      // Create persistent parent scope (simulating /departments route)
      final parentScope = ZenScopeManager.getOrCreateScope(
        name: 'DepartmentsScope',
        autoDispose: false,
      );

      final parentModule = ParentTestModule();
      parentModule.register(parentScope);
      await parentModule.onInit(parentScope);

      // Simulate navigation to child route that references parent by name
      ZenScope? childScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => ChildTestModule(),
            page: ScopeAwarePage(
              onScopeReceived: (scope) => childScope = scope,
            ),
            scopeName: 'DepartmentDetailScope',
            useParentScope: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the child found the parent by name
      expect(childScope, isNotNull);
      expect(childScope!.parent, same(parentScope));

      // Verify child can access parent services
      final parentService = childScope!.find<ParentService>();
      expect(parentService, isNotNull);
    });
  });
}

// Additional test pages for widget tree integration
class ScopeConsumerPage extends StatelessWidget {
  const ScopeConsumerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.findInScope<TestService>();
    return Scaffold(
      body: Center(
        child: Text('Found service: ${service.name}'),
      ),
    );
  }
}

class ZenScopeServiceTestPage extends StatelessWidget {
  const ZenScopeServiceTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) {
          final service = context.findInScope<TestService>();
          return Center(
            child: Text('Builder found: ${service.name}'),
          );
        },
      ),
    );
  }
}

// Helper StatefulWidget for the test
// Updated StatefulWidget with proper state management
class _TestScopeWidget extends StatefulWidget {
  final Function(ZenScope) onParentScopeReceived;
  final Function(ZenScope) onChildScopeReceived;

  const _TestScopeWidget({
    required this.onParentScopeReceived,
    required this.onChildScopeReceived,
  });

  @override
  State<_TestScopeWidget> createState() => _TestScopeWidgetState();
}

class _TestScopeWidgetState extends State<_TestScopeWidget> {
  bool showChild = true;
  ZenScope? parentScope;
  bool parentScopeReady = false;

  void _onParentScopeReceived(ZenScope scope) {
    setState(() {
      parentScope = scope;
      parentScopeReady = true;
    });
    widget.onParentScopeReceived(scope);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Parent scope - always present
          Expanded(
            flex: 1,
            child: ZenRoute(
              moduleBuilder: () => ParentTestModule(),
              page: ScopeAwarePage(
                onScopeReceived: _onParentScopeReceived,
              ),
              scopeName: 'ParentScope',
              autoDispose: false,
              useParentScope: false,
            ),
          ),
          // Child scope - only show when parent is ready
          if (showChild && parentScopeReady && parentScope != null)
            Expanded(
              flex: 1,
              child: ZenRoute(
                moduleBuilder: () => ChildTestModule(),
                page: ScopeAwarePage(
                  onScopeReceived: widget.onChildScopeReceived,
                ),
                scopeName: 'AutoDisposeChild',
                parentScope: parentScope,
                autoDispose: true,
              ),
            )
          else
            Expanded(
              flex: 1,
              child: Center(
                child: Text(showChild
                    ? 'Waiting for parent scope...'
                    : 'Child Removed'),
              ),
            ),
          // Toggle button
          ElevatedButton(
            onPressed: parentScopeReady
                ? () {
                    setState(() {
                      showChild = !showChild;
                    });
                  }
                : null,
            child: Text(showChild ? 'Hide Child' : 'Show Child'),
          ),
        ],
      ),
    );
  }
}

// Test page widgets for navigation
class HomePage extends StatelessWidget {
  final VoidCallback onNavigateToDepartments;

  const HomePage({super.key, required this.onNavigateToDepartments});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Home'),
          ElevatedButton(
            onPressed: onNavigateToDepartments,
            child: const Text('Go to Departments'),
          ),
        ],
      ),
    );
  }
}

class DepartmentsPage extends StatelessWidget {
  final VoidCallback onNavigateToDetail;

  const DepartmentsPage({super.key, required this.onNavigateToDetail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Departments'),
          ElevatedButton(
            onPressed: onNavigateToDetail,
            child: const Text('Go to Detail'),
          ),
        ],
      ),
    );
  }
}

class DepartmentDetailPage extends StatelessWidget {
  final VoidCallback onNavigateToEmployee;

  const DepartmentDetailPage({
    super.key,
    required this.onNavigateToEmployee,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Department Detail'),
          ElevatedButton(
            onPressed: onNavigateToEmployee,
            child: const Text('Go to Employee'),
          ),
        ],
      ),
    );
  }
}

class EmployeePage extends StatelessWidget {
  final VoidCallback onNavigateHome;

  const EmployeePage({super.key, required this.onNavigateHome});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Employee'),
          ElevatedButton(
            onPressed: onNavigateHome,
            child: const Text('Go to Home'),
          ),
        ],
      ),
    );
  }
}

// Test page for navigation cycles
class NavigationTestPage extends StatelessWidget {
  final Function(int) onNavigateToFeature;

  const NavigationTestPage({super.key, required this.onNavigateToFeature});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Navigation Test'),
          ElevatedButton(
            onPressed: () => onNavigateToFeature(1),
            child: const Text('Go to Feature 1'),
          ),
          ElevatedButton(
            onPressed: () => onNavigateToFeature(2),
            child: const Text('Go to Feature 2'),
          ),
          ElevatedButton(
            onPressed: () => onNavigateToFeature(3),
            child: const Text('Go to Feature 3'),
          ),
        ],
      ),
    );
  }
}

// Simple home page for navigation testing
class HomePage2 extends StatelessWidget {
  const HomePage2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Home Page'),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/feature'),
            child: const Text('Go to Feature'),
          ),
        ],
      ),
    );
  }
}

// Simple feature page for navigation testing
class FeaturePage extends StatelessWidget {
  const FeaturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Feature Page'),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false, // Remove all previous routes
            ),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}
