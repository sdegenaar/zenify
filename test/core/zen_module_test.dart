// test/core/zen_module_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// =============================================================================
// TEST SERVICES AND CONTROLLERS
// =============================================================================

class TestService {
  final String name;
  bool initialized = false;
  bool disposed = false;

  TestService(this.name);

  void initialize() => initialized = true;
  void dispose() => disposed = true;
}

class HttpClient {
  final String baseUrl;
  bool isConnected = false;

  HttpClient([this.baseUrl = 'https://api.example.com']);

  void connect() => isConnected = true;
  void disconnect() => isConnected = false;
}

class AuthService {
  final HttpClient httpClient;
  bool isAuthenticated = false;

  AuthService(this.httpClient);

  void login() => isAuthenticated = true;
  void logout() => isAuthenticated = false;
}

class DatabaseService {
  final String connectionString;
  bool isConnected = false;

  DatabaseService(this.connectionString);

  void connect() => isConnected = true;
  void disconnect() => isConnected = false;
}

class UserService {
  final AuthService authService;
  final DatabaseService databaseService;

  UserService(this.authService, this.databaseService);

  String getCurrentUser() => isAuthenticated ? 'user123' : 'guest';
  bool get isAuthenticated => authService.isAuthenticated;
}

class TestController extends ZenController {
  final String controllerName;
  bool initCalled = false;
  bool readyCalled = false;
  bool disposeCalled = false;

  TestController(this.controllerName);

  @override
  void onInit() {
    super.onInit();
    initCalled = true;
  }

  @override
  void onReady() {
    super.onReady();
    readyCalled = true;
  }

  @override
  void onClose() {
    disposeCalled = true;
    super.onClose();
  }
}

// =============================================================================
// TEST MODULES
// =============================================================================

class BasicModule extends ZenModule {
  @override
  String get name => 'BasicModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService('basic'));
  }
}

class InitializingModule extends ZenModule {
  bool initCalled = false;

  @override
  String get name => 'InitializingModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService('initializing'));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    initCalled = true;
    final service = scope.find<TestService>();
    service?.initialize();
  }
}

class NetworkModule extends ZenModule {
  @override
  String get name => 'NetworkModule';

  @override
  void register(ZenScope scope) {
    scope.put<HttpClient>(HttpClient());
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    final client = scope.find<HttpClient>();
    client?.connect();
  }
}

class AuthModule extends ZenModule {
  @override
  String get name => 'AuthModule';

  @override
  List<ZenModule> get dependencies => [NetworkModule()];

  @override
  void register(ZenScope scope) {
    final httpClient = scope.find<HttpClient>();
    scope.put<AuthService>(AuthService(httpClient!));
  }
}

class DatabaseModule extends ZenModule {
  @override
  String get name => 'DatabaseModule';

  @override
  void register(ZenScope scope) {
    scope.put<DatabaseService>(DatabaseService('test://database'));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    final db = scope.find<DatabaseService>();
    db?.connect();
  }
}

class UserModule extends ZenModule {
  @override
  String get name => 'UserModule';

  @override
  List<ZenModule> get dependencies => [AuthModule(), DatabaseModule()];

  @override
  void register(ZenScope scope) {
    final authService = scope.find<AuthService>();
    final databaseService = scope.find<DatabaseService>();
    scope.put<UserService>(UserService(authService!, databaseService!));
  }
}

// Circular dependency modules
class CircularA extends ZenModule {
  @override
  String get name => 'CircularA';

  @override
  List<ZenModule> get dependencies => [CircularB()];

  @override
  void register(ZenScope scope) {
    scope.put<String>('A', tag: 'A');
  }
}

class CircularB extends ZenModule {
  @override
  String get name => 'CircularB';

  @override
  List<ZenModule> get dependencies => [CircularA()];

  @override
  void register(ZenScope scope) {
    scope.put<String>('B', tag: 'B');
  }
}

// Failing modules
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

// Async module
class AsyncModule extends ZenModule {
  bool asyncOperationCompleted = false;

  @override
  String get name => 'AsyncModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService('async'));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final service = scope.find<TestService>();
    service?.initialize();
    asyncOperationCompleted = true;
  }
}

// Diamond dependency pattern modules
class ModuleD extends ZenModule {
  @override
  String get name => 'ModuleD';

  @override
  void register(ZenScope scope) {
    scope.put<String>('D', tag: 'D');
  }
}

class ModuleE extends ZenModule {
  @override
  String get name => 'ModuleE';

  @override
  void register(ZenScope scope) {
    scope.put<String>('E', tag: 'E');
  }
}

class ModuleF extends ZenModule {
  @override
  String get name => 'ModuleF';

  @override
  void register(ZenScope scope) {
    scope.put<String>('F', tag: 'F');
  }
}

class ModuleB extends ZenModule {
  @override
  String get name => 'ModuleB';

  @override
  List<ZenModule> get dependencies => [ModuleD()];

  @override
  void register(ZenScope scope) {
    scope.put<String>('B', tag: 'B');
  }
}

class ModuleC extends ZenModule {
  @override
  String get name => 'ModuleC';

  @override
  List<ZenModule> get dependencies => [ModuleE(), ModuleF()];

  @override
  void register(ZenScope scope) {
    scope.put<String>('C', tag: 'C');
  }
}

class ModuleA extends ZenModule {
  @override
  String get name => 'ModuleA';

  @override
  List<ZenModule> get dependencies => [ModuleB(), ModuleC()];

  @override
  void register(ZenScope scope) {
    scope.put<String>('A', tag: 'A');
  }
}

// Controller module
class ControllerModule extends ZenModule {
  @override
  String get name => 'ControllerModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestController>(TestController('module-controller'));
  }
}

// Factory modules
class LazyModule extends ZenModule {
  int factoryCallCount = 0;

  @override
  String get name => 'LazyModule';

  @override
  void register(ZenScope scope) {
    scope.putLazy<TestService>(() {
      factoryCallCount++;
      return TestService('lazy-$factoryCallCount');
    });
  }
}

class FactoryModule extends ZenModule {
  int factoryCallCount = 0;

  @override
  String get name => 'FactoryModule';

  @override
  void register(ZenScope scope) {
    scope.putFactory<TestService>(() {
      factoryCallCount++;
      return TestService('factory-$factoryCallCount');
    });
  }
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.reset();
    Zen.init();
    ZenConfig.applyEnvironment(ZenEnvironment.test);
  });

  tearDown(() {
    Zen.reset();
  });

  group('Basic Module Registration', () {
    test('should register and load a basic module', () async {
      await Zen.registerModules([BasicModule()]);

      final service = Zen.find<TestService>();
      expect(service.name, 'basic');
      expect(Zen.hasModule('BasicModule'), isTrue);
    });

    test('should call module onInit after registration', () async {
      final module = InitializingModule();
      await Zen.registerModules([module]);

      expect(module.initCalled, isTrue);
      final service = Zen.find<TestService>();
      expect(service.initialized, isTrue);
    });

    test('should auto-initialize controllers', () async {
      await Zen.registerModules([ControllerModule()]);

      final controller = Zen.find<TestController>();
      expect(controller.initCalled, isTrue);
      expect(controller.readyCalled, isTrue);
    });
  });

  group('Dependency Resolution', () {
    test('should resolve simple dependency chain', () async {
      await Zen.registerModules([AuthModule()]);

      expect(Zen.hasModule('NetworkModule'), isTrue);
      expect(Zen.hasModule('AuthModule'), isTrue);

      final httpClient = Zen.find<HttpClient>();
      final authService = Zen.find<AuthService>();

      expect(httpClient.isConnected, isTrue);
      expect(authService.httpClient, same(httpClient));
    });

    test('should resolve complex dependency graph (diamond pattern)', () async {
      await Zen.registerModules([ModuleA()]);

      // All modules should be loaded
      for (final name in [
        'ModuleA',
        'ModuleB',
        'ModuleC',
        'ModuleD',
        'ModuleE',
        'ModuleF'
      ]) {
        expect(Zen.hasModule(name), isTrue);
      }

      // All dependencies should exist
      for (final tag in ['A', 'B', 'C', 'D', 'E', 'F']) {
        expect(Zen.find<String>(tag: tag), tag);
      }
    });

    test('should resolve multi-dependency module', () async {
      await Zen.registerModules([UserModule()]);

      final userService = Zen.find<UserService>();
      expect(userService.authService, isNotNull);
      expect(userService.databaseService, isNotNull);
      expect(userService.databaseService.isConnected, isTrue);
    });
  });

  group('Error Handling', () {
    test('should detect circular dependencies', () async {
      expect(
        () => Zen.registerModules([CircularA()]),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Circular dependency'),
        )),
      );

      expect(Zen.hasModule('CircularA'), isFalse);
      expect(Zen.hasModule('CircularB'), isFalse);
    });

    test('should handle registration failure', () async {
      expect(
        () => Zen.registerModules([FailingModule()]),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Registration failed'),
        )),
      );

      expect(Zen.hasModule('FailingModule'), isFalse);
    });

    test('should handle initialization failure', () async {
      expect(
        () => Zen.registerModules([InitFailingModule()]),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Initialization failed'),
        )),
      );

      expect(Zen.hasModule('InitFailingModule'), isFalse);
    });
  });

  group('Async Operations', () {
    test('should handle async initialization', () async {
      final stopwatch = Stopwatch()..start();
      final asyncModule = AsyncModule();

      await Zen.registerModules([asyncModule]);

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, greaterThan(90));

      final service = Zen.find<TestService>();
      expect(service.initialized, isTrue);
      expect(asyncModule.asyncOperationCompleted, isTrue);
    });

    test('should handle concurrent registration', () async {
      final futures = [
        Zen.registerModules([NetworkModule()]),
        Zen.registerModules([DatabaseModule()]),
      ];

      await Future.wait(futures);

      expect(Zen.hasModule('NetworkModule'), isTrue);
      expect(Zen.hasModule('DatabaseModule'), isTrue);
      expect(Zen.find<HttpClient>().isConnected, isTrue);
      expect(Zen.find<DatabaseService>().isConnected, isTrue);
    });
  });

  group('Scoped Registration', () {
    test('should register modules in specific scopes', () async {
      final testScope = Zen.createScope(name: 'test-scope');

      await Zen.registerModules([BasicModule()], scope: testScope);

      expect(testScope.find<TestService>(), isNotNull);
      expect(Zen.findOrNull<TestService>(), isNull);

      testScope.dispose();
    });

    test('should handle scoped dependency chains', () async {
      final testScope = Zen.createScope(name: 'scoped-test');

      await Zen.registerModules([AuthModule()], scope: testScope);

      expect(testScope.find<HttpClient>(), isNotNull);
      expect(testScope.find<AuthService>(), isNotNull);
      expect(Zen.findOrNull<HttpClient>(), isNull);
      expect(Zen.findOrNull<AuthService>(), isNull);

      testScope.dispose();
    });
  });

  group('Factory Patterns', () {
    test('should handle lazy factories', () async {
      final lazyModule = LazyModule();
      await Zen.registerModules([lazyModule]);

      expect(lazyModule.factoryCallCount, 0);

      final service = Zen.find<TestService>();
      expect(service.name, 'lazy-1');
      expect(lazyModule.factoryCallCount, 1);

      final serviceAgain = Zen.find<TestService>();
      expect(serviceAgain, same(service));
      expect(lazyModule.factoryCallCount, 1);
    });

    test('should handle instance factories', () async {
      final factoryModule = FactoryModule();
      await Zen.registerModules([factoryModule]);

      final service1 = Zen.find<TestService>();
      expect(service1.name, 'factory-1');
      expect(factoryModule.factoryCallCount, 1);

      final service2 = Zen.find<TestService>();
      expect(service2.name, 'factory-2');
      expect(factoryModule.factoryCallCount, 2);
      expect(service1, isNot(same(service2)));
    });
  });

  group('Module Management', () {
    test('should provide module information', () async {
      await Zen.registerModules([BasicModule(), NetworkModule()]);

      expect(Zen.getModule('BasicModule'), isNotNull);
      expect(Zen.getModule('NetworkModule'), isNotNull);
      expect(Zen.getModule('NonExistent'), isNull);

      final allModules = Zen.getAllModules();
      expect(allModules.length, 2);
      expect(allModules.containsKey('BasicModule'), isTrue);
      expect(allModules.containsKey('NetworkModule'), isTrue);
    });

    test('should provide debug information', () async {
      await Zen.registerModules([AuthModule()]);

      final modulesDump = ZenDebug.dumpModules();
      expect(modulesDump, contains('NetworkModule'));
      expect(modulesDump, contains('AuthModule'));
    });

    test('should handle module replacement', () async {
      await Zen.registerModules([BasicModule()]);
      expect(Zen.find<TestService>().name, 'basic');

      // Clear and register new
      Zen.deleteAll(force: true);
      ZenModuleRegistry.clear();

      await Zen.registerModules([BasicModule()]);
      expect(Zen.find<TestService>().name, 'basic');
    });
  });

  group('Performance', () {
    test('should handle multiple modules efficiently', () async {
      final modules = <ZenModule>[];
      for (int i = 0; i < 10; i++) {
        modules.add(_TestModule('Module$i', 'value$i'));
      }

      final stopwatch = Stopwatch()..start();
      await Zen.registerModules(modules);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500));

      for (int i = 0; i < 10; i++) {
        expect(Zen.hasModule('Module$i'), isTrue);
        expect(Zen.find<String>(tag: 'test$i'), 'value$i');
      }
    });
  });
}

// Helper module for dynamic testing
class _TestModule extends ZenModule {
  final String _name;
  final String _value;

  _TestModule(this._name, this._value);

  @override
  String get name => _name;

  @override
  void register(ZenScope scope) {
    scope.put<String>(_value, tag: 'test${_name.replaceAll('Module', '')}');
  }
}
