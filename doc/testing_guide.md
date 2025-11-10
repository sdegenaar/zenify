# Zenify Testing Documentation

Complete guide to testing with Zenify - from unit tests to integration tests## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Test Mode API](#test-mode-api)
4. [Testing Utilities](#testing-utilities)
5. [Testing Patterns](#testing-patterns)
6. [Widget Testing](#widget-testing)
7. [Integration Testing](#integration-testing)
8. [Advanced Topics](#advanced-topics)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

## Overview

Zenify provides a designed for maximum developer experience and testability. Our testing system includes: **top-tier
testing architecture**

- ✅ **Fluent Test Mode API** - Chainable mocking interface
- ✅ **Isolated Test Scopes** - True test isolation
- ✅ **Reactive Testing Utilities** - Track state changes effortlessly
- ✅ **Comprehensive Test Helpers** - Reduce boilerplate
- ✅ - Prevent leaks and accumulation **Memory-Safe Testing**
- ✅ - Full testing stack **Widget & Integration Testing**

## Quick Start

### Setup

Add Zenify's testing utilities to your test file:

``` dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    // Initialize Zen in test mode
    Zen.reset();
    Zen.init();
    ZenConfig.configureTest();
  });

  tearDown(() {
    // Clean up after each test
    Zen.reset();
  });
}
```

Your First Test

``` dart
test('user service returns user data', () {
  // Arrange - Mock dependencies
  Zen.testMode()
    .mock<ApiClient>(FakeApiClient())
    .mock<AuthService>(FakeAuthService());

  // Act
  final userService = Zen.find<UserService>();
  final user = userService.getCurrentUser();

  // Assert
  expect(user.name, 'Test User');
});
```

Test Mode API
The Zen.testMode() API provides a fluent interface for test setup.
Basic Mocking

``` dart
// Mock a single dependency
Zen.testMode().mock<AuthService>(FakeAuthService());

// Chain multiple mocks
Zen.testMode()
.mock<AuthService>(FakeAuthService())
.mock<ApiClient>(MockApiClient())
.mock<Database>(InMemoryDatabase());

// Mock with tags
Zen.testMode()
.mock<Logger>(FileLogger(), tag: 'file')
.mock<Logger>(ConsoleLogger(), tag: 'console');
```

Mock Types

1. Instance Mock - Replace with concrete instance

``` dart
Zen.testMode().mock<AuthService>(FakeAuthService());
```

2. Lazy Mock - Replace with factory

``` dart
   Zen.testMode().mockLazy<ApiClient>(
   () => MockApiClient()..setupDefaults(),
   );
```

3. Factory Mock - Create fresh instance each time

``` dart
Zen.testMode().mockFactory<RequestId>(
  () => RequestId.generate(), // New ID each call
);
```

4. Batch Mock - Mock multiple at once

``` dart
   Zen.testMode().mockAll({
   AuthService: FakeAuthService(),
   ApiClient: MockApiClient(),
   CacheService: InMemoryCacheService(),
   });
```

Isolated Scopes
Create completely isolated test environments:

``` dart
test('isolated scope test', () {
  final testScope = Zen.testMode().isolatedScope(name: 'MyTest');
  
  // Register dependencies in isolated scope
  testScope.put<AuthService>(FakeAuthService());
  
  // Use the scope
  final auth = testScope.find<AuthService>();
  
  // Clean up
  testScope.dispose();
});
```

Using Mocktail/Mockito
Zenify works seamlessly with popular mocking frameworks:

``` dart
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

test('login with mocktail', () async {
// Create mock
final mockAuth = MockAuthService();

// Setup expectations
when(() => mockAuth.login(any(), any()))
.thenAnswer((_) async => User(id: '123', name: 'Test'));

// Inject into Zenify
Zen.testMode().mock<AuthService>(mockAuth);

// Test your code
final controller = LoginController();
await controller.login('user', 'pass');

// Verify
verify(() => mockAuth.login('user', 'pass')).called(1);
});
```

Testing Utilities
Zenify provides powerful utilities to simplify testing.
ZenTestContainer
Create isolated test environments with pre-configured dependencies:

``` dart
test('test container example', () async {
  final container = ZenTestContainer(name: 'UserTest');
  
  // Register dependencies
  container.put<ApiClient>(FakeApiClient());
  container.putLazy<UserService>(() => UserService());
  
  // Use dependencies
  final userService = container.get<UserService>();
  final users = await userService.fetchUsers();
  
  expect(users, isNotEmpty);
  
  // Automatic cleanup
  container.dispose();
});
```

ZenTestContainer API

``` dart
// Registration
container.put<T>(instance);                          // Register instance (eager singleton)
container.putLazy<T>(() => T());                     // Lazy singleton
container.putLazy<T>(() => T(), alwaysNew: true);    // Factory (new instance each find)

// Access
container.find<T>();                     // Find (returns null)
container.get<T>();                      // Get (throws if not found)
container.exists<T>();                   // Check existence

// Lifecycle
container.clear();                       // Clear all dependencies
container.dispose();                     // Dispose container
```

RxTester - Track Reactive Changes
This is unique to Zenify! Track all changes to reactive values:

``` dart
test('reactive value changes', () async {
  final counter = 0.obs;
  final tester = RxTester(counter);
  
  // Perform actions
  counter.value = 1;
  counter.value = 2;
  counter.value = 3;
  
  // Verify change history
  expect(tester.changes, [1, 2, 3]);
  expect(tester.lastValue, 3);
  expect(tester.hasChanged, isTrue);
  
  // Or use convenience method
  expect(tester.expectChanges([1, 2, 3]), isTrue);
  
  // Cleanup
  tester.dispose();
});
```

RxTester API

``` dart
final tester = RxTester(myRx);

tester.changes              // List of all changes
tester.lastValue            // Most recent value
tester.hasChanged           // Whether any changes occurred
tester.expectChanges([...]) // Verify exact change sequence
tester.reset()              // Clear change history
tester.dispose()            // Cleanup
```

ZenTestUtils - Helper Functions

``` dart
// Run test in isolated environment
await ZenTestUtils.runInTestEnvironment(
  (container) async {
    container.put<Database>(InMemoryDb());
    
    // Your test code
    final service = container.get<UserService>();
    await service.createUser('test');
  },
  setup: (container) {
    // Optional setup
    container.put<Logger>(NoOpLogger());
  },
);

// Wait for reactive updates
await ZenTestUtils.pump();

// Wait for specific duration (debounce/throttle testing)
await ZenTestUtils.wait(Duration(milliseconds: 500));

// Verify reactive changes
final isValid = await ZenTestUtils.verifyReactiveChanges(
  myRx,
  [1, 2, 3], // Expected changes
  () async {
    // Action that triggers changes
    myRx.value = 1;
    await Future.delayed(Duration.zero);
    myRx.value = 2;
    await Future.delayed(Duration.zero);
    myRx.value = 3;
  },
);
expect(isValid, isTrue);
```

Testing Patterns
Recipe 1: Testing Controllers

``` dart
class CounterController extends ZenController {
  final count = 0.obs;
    
  void increment() {
    count.value++;
  }
}

test('counter controller increments', () {
  final container = ZenTestContainer();
  final controller = container.register<CounterController>(
    () => CounterController(),
  );

  expect(controller.count.value, 0);

  controller.increment();
  expect(controller.count.value, 1);

  container.dispose();
});
```

Recipe 2: Testing Authentication Flow

``` dart
class AuthController extends ZenController {
  final AuthService _auth = Zen.find();
  final isLoggedIn = false.obs;
  final user = Rx<User?>(null);
  
  Future<void> login(String email, String password) async {
    final result = await _auth.login(email, password);
    isLoggedIn.value = true;
    user.value = result;
  }
}

test('authentication flow', () async {
  // Mock auth service
  final mockAuth = MockAuthService();
  when(() => mockAuth.login(any(), any()))
    .thenAnswer((_) async => User(id: '1', name: 'Test'));
  
  Zen.testMode().mock<AuthService>(mockAuth);
  
  // Test controller
  final controller = AuthController();
  await controller.login('test@example.com', 'password');
  
  expect(controller.isLoggedIn.value, isTrue);
  expect(controller.user.value?.name, 'Test');
  
  verify(() => mockAuth.login('test@example.com', 'password')).called(1);
});
```

Recipe 3: Testing Reactive Computations

``` dart
test('computed values update correctly', () {
final firstName = 'John'.obs;
final lastName = 'Doe'.obs;

final fullName = computed(() => '${firstName.value} ${lastName.value}');
final tester = RxTester(fullName);

expect(fullName.value, 'John Doe');

firstName.value = 'Jane';
expect(fullName.value, 'Jane Doe');
expect(tester.changes, ['Jane Doe']);

lastName.value = 'Smith';
expect(fullName.value, 'Jane Smith');
expect(tester.expectChanges(['Jane Doe', 'Jane Smith']), isTrue);

tester.dispose();
fullName.dispose();
});
```

Recipe 4: Testing Async Operations

``` dart
test('async operations with RxFuture', () async {
  final apiClient = FakeApiClient();
  Zen.testMode().mock<ApiClient>(apiClient);
  
  final rxFuture = RxFuture.fromFactory(() => apiClient.fetchUsers());
  
  // Initially loading
  expect(rxFuture.isLoading, isTrue);
  
  // Wait for completion
  await Future.delayed(Duration(milliseconds: 100));
  
  // Should have data
  expect(rxFuture.hasData, isTrue);
  expect(rxFuture.data, isNotNull);
  expect(rxFuture.hasError, isFalse);
});

test('async error handling', () async {
  final apiClient = FakeApiClient()..shouldFail = true;
  Zen.testMode().mock<ApiClient>(apiClient);
  
  final rxFuture = RxFuture.fromFactory(() => apiClient.fetchUsers());
  
  await Future.delayed(Duration(milliseconds: 100));
  
  expect(rxFuture.hasError, isTrue);
  expect(rxFuture.errorMessage, contains('Failed'));
});
```

Recipe 5: Testing with Scoped Dependencies

``` dart
test('scoped dependencies', () {
  // Create parent scope
  final parentScope = Zen.createScope(name: 'Parent');
  parentScope.put<Database>(InMemoryDatabase());

  // Create child scope
  final childScope = Zen.createScope(
    name: 'Child',
    parent: parentScope,
  );

  // Child can access parent's dependencies
  final db = childScope.find<Database>();
  expect(db, isNotNull);
  expect(db, same(parentScope.find<Database>()));

  // Cleanup
  childScope.dispose();
  parentScope.dispose();
});
```

Widget Testing
Testing with ZenBuilder

``` dart
testWidgets('ZenBuilder updates on controller change', (tester) async {
  Zen.testMode().mock<ApiClient>(FakeApiClient());
  
  await tester.pumpWidget(
    MaterialApp(
      home: ZenBuilder<CounterController>(
        create: () => CounterController(),
        builder: (context, controller) {
          return Text('Count: ${controller.count.value}');
        },
      ),
    ),
  );
  
  // Initial state
  expect(find.text('Count: 0'), findsOneWidget);
  
  // Get controller and modify
  final controller = Zen.find<CounterController>();
  controller.increment();
  
  await tester.pump();
  
  // Updated state
  expect(find.text('Count: 1'), findsOneWidget);
});
```

Testing with Obx

``` dart
testWidgets('Obx rebuilds on reactive change', (tester) async {
  final counter = 0.obs;

  await tester.pumpWidget(
  MaterialApp(
    home: Obx(() => Text('Count: ${counter.value}')),
    ),
  );

  expect(find.text('Count: 0'), findsOneWidget);

  counter.value = 5;
  await tester.pump();

  expect(find.text('Count: 5'), findsOneWidget);
});
```

Testing with ZenRoute

``` dart
testWidgets('ZenRoute with module', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ZenRoute(
        moduleBuilder: () => TestModule(),
        page: Builder(
          builder: (context) {
            final service = context.findInScope<TestService>();
            return Text('Service: ${service.name}');
          },
        ),
      ),
    ),
  );
  
  await tester.pumpAndSettle();
  
  expect(find.text('Service: test'), findsOneWidget);
});
```

Testing Navigation

``` dart
testWidgets('navigation cleans up scopes', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
    home: ZenRoute(
      moduleBuilder: () => HomeModule(),
      page: HomePage(),
      scopeName: 'HomeScope',
     ),
    ),
  );

  await tester.pumpAndSettle();

  // Verify scope exists
  expect(ZenScopeManager.getScope('HomeScope'), isNotNull);

  // Navigate away
  await tester.tap(find.text('Go to Settings'));
  await tester.pumpAndSettle();

  // Verify scope was cleaned up (if autoDispose: true)
  expect(ZenScopeManager.getScope('HomeScope'), isNull);
});
```

Integration Testing
Full Feature Testing

``` dart
testWidgets('complete login flow', (tester) async {
  // Setup test environment
  final mockAuth = MockAuthService();
  when(() => mockAuth.login(any(), any()))
    .thenAnswer((_) async => User(id: '1', name: 'Test User'));
  
  Zen.testMode()
    .mock<AuthService>(mockAuth)
    .mock<ApiClient>(FakeApiClient());
  
  // Pump app
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();
  
  // Verify login screen
  expect(find.text('Login'), findsOneWidget);
  
  // Enter credentials
  await tester.enterText(find.byType(TextField).first, 'test@example.com');
  await tester.enterText(find.byType(TextField).last, 'password');
  
  // Tap login
  await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
  await tester.pumpAndSettle();
  
  // Verify navigation to home
  expect(find.text('Welcome, Test User'), findsOneWidget);
  
  // Verify mock was called
  verify(() => mockAuth.login('test@example.com', 'password')).called(1);
});
```

Testing Memory Safety

``` dart
testWidgets('prevents controller accumulation', (tester) async {
  var creationCount = 0;

  // Create multiple navigation cycles
  for (var i = 0; i < 3; i++) {
    await tester.pumpWidget(
      MaterialApp(
        home: ZenRoute(
          moduleBuilder: () => CountingModule(() => creationCount++),
          page: TestPage(),
          scopeName: 'TestScope$i',
          autoDispose: true,
         ),
       ),
     );
     await tester.pumpAndSettle();

     // Navigate away
     await tester.pumpWidget(MaterialApp(home: SizedBox()));
     await tester.pumpAndSettle();
   }

  // Verify no accumulation
  expect(creationCount, 3); // Created 3 times

  // Verify all scopes disposed
  expect(ZenScopeManager.getAllScopes().length, 1); // Only root remains
});
```

Advanced Topics
Testing Timing Operators

``` dart
test('debounce operator', () async {
  final search = ''.obs;
  final debounced = <String>[];
  
  search.debounce(Duration(milliseconds: 300), (value) {
    debounced.add(value);
  });
  
  // Type quickly
  search.value = 'a';
  search.value = 'ab';
  search.value = 'abc';
  
  // Wait for debounce
  await ZenTestUtils.wait(Duration(milliseconds: 400));
  
  // Only last value should be emitted
  expect(debounced, ['abc']);
});

test('throttle operator', () async {
  final clicks = 0.obs;
  final throttled = <int>[];
  
  clicks.throttle(Duration(milliseconds: 100), (value) {
    throttled.add(value);
  });
  
  // Rapid clicks
  for (var i = 0; i < 5; i++) {
    clicks.value++;
    await ZenTestUtils.wait(Duration(milliseconds: 30));
  }
  
  await ZenTestUtils.wait(Duration(milliseconds: 200));
  
  // Should throttle to fewer emissions
  expect(throttled.length, lessThan(5));
});
```

Testing Computed Dependencies

``` dart
test('computed tracks dynamic dependencies', () {
  final useFirst = true.obs;
  final first = 1.obs;
  final second = 2.obs;

  final result = computed(() {
    return useFirst.value ? first.value : second.value;
  });

  expect(result.value, 1);
  expect(result.dependencies.length, 2); // Tracks useFirst and first

  useFirst.value = false;
  expect(result.value, 2);

  // Now tracks useFirst and second
  expect(result.dependencies.contains(second), isTrue);
});
```

Custom Test Controllers

``` dart
class TestableController extends ZenController {
  // Add test-specific tracking
  final methodCalls = <String>[];
  
  void trackCall(String method) {
    methodCalls.add(method);
  }
  
  @override
  void onInit() {
    super.onInit();
    trackCall('onInit');
  }
  
  @override
  void onClose() {
    trackCall('onClose');
    super.onClose();
  }
}

test('verify controller lifecycle', () {
  final controller = TestableController();
  expect(controller.methodCalls, ['onInit']);
  
  controller.dispose();
  expect(controller.methodCalls, ['onInit', 'onClose']);
});
```

Best Practices
✅ DO: Use setUp/tearDown

``` dart
void main() {
  setUp(() {
    Zen.reset();
    Zen.init();
    ZenConfig.configureTest();
  });

  tearDown(() {
    Zen.reset();
  });
}
```

✅ DO: Use Test Containers for Isolation

``` dart
test('isolated test', () async {
  await ZenTestUtils.runInTestEnvironment((container) async {
    // Test runs in isolated environment
    container.put<Service>(FakeService());
    // ...
  });
});
```

✅ DO: Verify Mock Interactions

``` dart
test('verify service called', () {
  final mock = MockService();
  Zen.testMode().mock<Service>(mock);

  // Test code...

  verify(() => mock.doSomething()).called(1);
});
```

✅ DO: Clean Up Resources

``` dart
test('cleanup resources', () {
  final tester = RxTester(myRx);
  final controller = MyController();
  
  // Test code...
  
  tester.dispose();
  controller.dispose();
});
```

❌ DON'T: Share State Between Tests

``` dart
// ❌ BAD - Global state
final globalService = MyService();

test('test 1', () {
  globalService.doSomething();
});

// ✅ GOOD - Isolated state
test('test 1', () {
  final service = MyService();
  service.doSomething();
});
```

❌ DON'T: Forget to Wait for Async

``` dart
// ❌ BAD - Missing await
test('async test', () {
  myController.loadData(); // Returns Future
  expect(myController.data.value, isNotNull); // Will fail!
});

// ✅ GOOD - Proper async handling
test('async test', () async {
  await myController.loadData();
  expect(myController.data.value, isNotNull);
});
```

Troubleshooting
Issue: Tests Contaminate Each Other
Problem: State from one test affects another
Solution: Ensure proper cleanup in tearDown:

``` dart
tearDown(() {
  Zen.reset();
  ZenScopeManager.disposeAll();
});
```

Issue: Controller Not Found
Problem: Zen.find<MyController>() returns null
Solution: Ensure controller is registered:

``` dart
test('find controller', () {
  // Register first
  Zen.put<MyController>(MyController());
  
  // Then find
  final controller = Zen.find<MyController>();
  expect(controller, isNotNull);
});
```

Issue: Widget Not Rebuilding
Problem: Reactive value changes but widget doesn't update
Solution: Ensure proper reactive access:

``` dart
// ❌ BAD - Doesn't track
Obx(() => Text('Count: ${controller.count}')); // Missing .value

// ✅ GOOD - Tracks reactivity
Obx(() => Text('Count: ${controller.count.value}'));
```

Issue: Memory Leaks in Tests
Problem: Controllers/scopes accumulate across tests
Solution: Use auto-dispose and verify cleanup:

``` dart
testWidgets('no memory leak', (tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pumpWidget(
      MaterialApp(
        home: ZenRoute(
          moduleBuilder: () => MyModule(),
          page: MyPage(),
          autoDispose: true, // Enable auto-dispose
        ),
      ),
    );
    await tester.pumpWidget(SizedBox()); // Remove
  }
  
  // Verify only root scope remains
  expect(ZenScopeManager.getAllScopes().length, 1);
});
```

Summary
Zenify provides industry-leading testing capabilities that rival or exceed other state management solutions:
✅ Fluent Test API - Mock dependencies with clean, chainable syntax
✅ Isolated Scopes - True test isolation without global state contamination
✅ Reactive Testing - RxTester for effortless state change tracking
✅ Memory Safety - Built-in protection against leaks and accumulation
✅ Comprehensive Utilities - Reduce boilerplate with helper functions
✅ Widget Testing - Seamless integration with Flutter's test framework
✅ Integration Testing - Full-stack testing support
Next Steps
Explore the API Reference for detailed documentation
Check out Example Tests in the repository
Join the community for testing tips and patterns
Happy Testing! 🧪