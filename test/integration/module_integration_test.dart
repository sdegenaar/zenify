// test/integration/module_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Mock services for testing
class NetworkService {
  bool initialized = false;

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    return {'success': true, 'token': 'mock-token'};
  }

  void initialize() {
    initialized = true;
  }
}

class AuthService {
  final NetworkService networkService;
  String? _token;

  AuthService({required this.networkService});

  String? get token => _token;
  bool get isLoggedIn => _token != null;

  Future<bool> login(String username, String password) async {
    final response = await networkService.post('/login', {
      'username': username,
      'password': password,
    });

    if (response['success'] == true) {
      _token = response['token'];
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await networkService.post('/logout', {});
    _token = null;
  }
}

class ProfileRepository {
  final AuthService authService;

  ProfileRepository({required this.authService});

  Future<Map<String, dynamic>> getUserProfile() async {
    if (!authService.isLoggedIn) {
      throw Exception('Not authenticated');
    }

    // Return mock profile
    return {
      'id': '123',
      'name': 'Test User',
      'email': 'test@example.com'
    };
  }
}

// Test controllers that use these services
class AuthController extends ZenController {
  final AuthService authService;

  AuthController({required this.authService});

  bool isLoggedIn = false;
  String? error;

  Future<bool> login(String username, String password) async {
    try {
      isLoggedIn = await authService.login(username, password);
      error = null;
      update();
      return isLoggedIn;
    } catch (e) {
      error = e.toString();
      isLoggedIn = false;
      update();
      return false;
    }
  }
}

class ProfileController extends ZenController {
  final ProfileRepository profileRepository;

  ProfileController({required this.profileRepository});

  Map<String, dynamic>? profile;
  String? error;
  bool isLoading = false;

  Future<void> loadProfile() async {
    isLoading = true;
    error = null;
    update();

    try {
      profile = await profileRepository.getUserProfile();
    } catch (e) {
      error = e.toString();
      profile = null;
    } finally {
      isLoading = false;
      update();
    }
  }
}

// Define modules for testing using the actual ZenModule API
class NetworkModule extends ZenModule {
  final NetworkService? _testService; // Optional test service injection

  NetworkModule({NetworkService? testService}) : _testService = testService;

  @override
  String get name => 'NetworkModule';

  @override
  void register(ZenScope scope) {
    // Use test service if provided, otherwise create new one
    final networkService = _testService ?? NetworkService();
    scope.put<NetworkService>(networkService);

    // Initialize the service
    networkService.initialize();
  }
}

class AuthModule extends ZenModule {
  @override
  String get name => 'AuthModule';

  @override
  void register(ZenScope scope) {
    // Find network service (should have been registered by NetworkModule)
    final networkService = scope.find<NetworkService>();
    if (networkService == null) {
      throw Exception('NetworkService dependency not found');
    }

    // Register auth service with its dependencies
    final authService = AuthService(networkService: networkService);
    scope.put<AuthService>(authService);

    // Register auth controller
    final authController = AuthController(authService: authService);
    scope.put<AuthController>(authController);
  }
}

class ProfileModule extends ZenModule {
  @override
  String get name => 'ProfileModule';

  @override
  void register(ZenScope scope) {
    // Find auth service (should have been registered by AuthModule)
    final authService = scope.find<AuthService>();
    if (authService == null) {
      throw Exception('AuthService dependency not found');
    }

    // Register profile repository
    final profileRepository = ProfileRepository(authService: authService);
    scope.put<ProfileRepository>(profileRepository);

    // Register profile controller
    final profileController = ProfileController(profileRepository: profileRepository);
    scope.put<ProfileController>(profileController);
  }
}

// Helper function to register modules in the correct order
void registerModulesInOrder(ZenScope scope) {
  // Register modules in dependency order manually
  final networkModule = NetworkModule();
  final authModule = AuthModule();
  final profileModule = ProfileModule();

  // Register in correct order
  networkModule.register(scope);
  authModule.register(scope);
  profileModule.register(scope);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize Zen
    Zen.init();
    ZenConfig.enableDebugLogs = false; // Disable logs for cleaner test output
  });

  tearDown(() {
    // Clean up after each test
    Zen.reset();
  });

  group('ZenModule Integration', () {
    test('should register and initialize a single module', () {
      // Create a test scope
      final testScope = Zen.createScope(name: 'single-module-test');

      // Register the network module
      final networkModule = NetworkModule();
      networkModule.register(testScope);

      // Verify that the module was registered
      final networkService = testScope.find<NetworkService>();
      expect(networkService, isNotNull);
      expect(networkService!.initialized, true);

      // Clean up
      testScope.dispose();
    });

    test('should register modules with dependencies in correct order', () {
      // Create a test scope
      final testScope = Zen.createScope(name: 'module-dependencies-test');

      // Register modules in dependency order
      registerModulesInOrder(testScope);

      // Verify that all dependencies were registered
      final networkService = testScope.find<NetworkService>();
      final authService = testScope.find<AuthService>();
      final profileRepository = testScope.find<ProfileRepository>();

      expect(networkService, isNotNull);
      expect(authService, isNotNull);
      expect(profileRepository, isNotNull);

      // Verify that dependencies are properly wired up
      expect(authService!.networkService, same(networkService));
      expect(profileRepository!.authService, same(authService));

      // Clean up
      testScope.dispose();
    });

    test('should provide controllers registered through modules', () {
      // Create a test scope
      final testScope = Zen.createScope(name: 'controllers-test');

      // Register modules in dependency order
      registerModulesInOrder(testScope);

      // Test 1: Verify all controllers are available
      final authController = testScope.find<AuthController>();
      final profileController = testScope.find<ProfileController>();

      expect(authController, isNotNull);
      expect(profileController, isNotNull);

      // Test 2: Verify all services are available
      final networkService = testScope.find<NetworkService>();
      final authService = testScope.find<AuthService>();
      final profileRepository = testScope.find<ProfileRepository>();

      expect(networkService, isNotNull);
      expect(authService, isNotNull);
      expect(profileRepository, isNotNull);

      // Test 3: Verify controller dependencies are correctly wired
      expect(authController!.authService, same(authService));
      expect(profileController!.profileRepository, same(profileRepository));

      // Test 4: Verify service dependencies are correctly wired
      expect(authService!.networkService, same(networkService));
      expect(profileRepository!.authService, same(authService));

      // Test 5: Verify singleton behavior - same instances should be returned
      final authController2 = testScope.find<AuthController>();
      final profileController2 = testScope.find<ProfileController>();
      final networkService2 = testScope.find<NetworkService>();

      expect(authController2, same(authController));
      expect(profileController2, same(profileController));
      expect(networkService2, same(networkService));

      // Test 6: Verify controller lifecycle - should be initialized and ready
      expect(authController.isInitialized, isTrue);
      expect(profileController.isInitialized, isTrue);

      // Test 7: Verify hierarchical scope lookup works
      final childScope = Zen.createScope(name: 'child-scope', parent: testScope);

      // Controllers should be found from parent scope
      expect(childScope.find<AuthController>(), same(authController));
      expect(childScope.find<ProfileController>(), same(profileController));
      expect(childScope.find<NetworkService>(), same(networkService));

      // But not when searching only in child scope
      expect(childScope.findInThisScope<AuthController>(), isNull);
      expect(childScope.findInThisScope<ProfileController>(), isNull);
      expect(childScope.findInThisScope<NetworkService>(), isNull);

      // Test 8: Verify all dependencies exist in scope
      expect(testScope.exists<AuthController>(), isTrue);
      expect(testScope.exists<ProfileController>(), isTrue);
      expect(testScope.exists<AuthService>(), isTrue);
      expect(testScope.exists<ProfileRepository>(), isTrue);
      expect(testScope.exists<NetworkService>(), isTrue);

      // Test 9: Verify type-based lookups work
      final allControllers = testScope.findAllOfType<ZenController>();
      expect(allControllers.length, equals(2));
      expect(allControllers, containsAll([authController, profileController]));

      // Test 10: Verify functional capabilities
      expect(authController.isLoggedIn, isFalse);
      expect(authController.error, isNull);

      expect(profileController.profile, isNull);
      expect(profileController.error, isNull);
      expect(profileController.isLoading, isFalse);

      // Test 11: Verify service functionality
      expect(networkService!.initialized, isTrue);
      expect(authService.isLoggedIn, isFalse);
      expect(authService.token, isNull);

      // Test 12: Verify shared service instances
      expect(authService.networkService, same(networkService));
      expect(profileRepository.authService, same(authService));

      // Test 13: Verify permanent vs temporary dependencies
      // Controllers should be temporary by default
      expect(testScope.delete<AuthController>(), isTrue);
      expect(testScope.delete<ProfileController>(), isTrue);

      // Clean up
      childScope.dispose();
      testScope.dispose();
    });

    test('should handle tag conflicts and replacements', () {
      final testScope = Zen.createScope(name: 'tag-conflict-test');

      // Register initial service
      final networkService1 = NetworkService();
      testScope.put<NetworkService>(networkService1, tag: 'api');

      // Replace with new service (same tag)
      final networkService2 = NetworkService();
      testScope.put<NetworkService>(networkService2, tag: 'api');

      // Should have the new service, not the old one
      expect(testScope.find<NetworkService>(tag: 'api'), same(networkService2));
      expect(testScope.find<NetworkService>(tag: 'api'), isNot(same(networkService1)));

      testScope.dispose();
    });

    test('should integrate modules with the dependency injection system', () async {
      // Create a test scope
      final testScope = Zen.createScope(name: 'integration-test');

      // Register modules
      registerModulesInOrder(testScope);

      // Get controllers
      final authController = testScope.find<AuthController>();
      final profileController = testScope.find<ProfileController>();

      // Test login flow
      final loginResult = await authController!.login('testuser', 'password');
      expect(loginResult, true);
      expect(authController.isLoggedIn, true);

      // Test profile loading flow
      await profileController!.loadProfile();
      expect(profileController.isLoading, false);
      expect(profileController.error, isNull);
      expect(profileController.profile, isNotNull);
      expect(profileController.profile!['name'], 'Test User');

      // Clean up
      testScope.dispose();
    });

    test('should support scoped module registration', () {
      // Create a test scope
      final testScope = Zen.createScope(name: 'scoped-module-test');

      // Create a custom scope as a child of the test scope
      final customScope = Zen.createScope(name: 'CustomScope', parent: testScope);

      // Register the network module in the custom scope
      final networkModule = NetworkModule();
      networkModule.register(customScope);

      // Verify that dependencies are registered in the scope
      final networkService = customScope.find<NetworkService>();
      expect(networkService, isNotNull);
      expect(networkService!.initialized, true);

      // But not in the parent scope's own dependencies
      final rootNetworkService = testScope.findInThisScope<NetworkService>();
      expect(rootNetworkService, isNull);

      // Clean up
      customScope.dispose();
      testScope.dispose();
    });

    test('should support module re-registration with different configurations', () {
      // Create a test scope
      final testScope = Zen.createScope(name: 're-registration-test');

      // Register network module in the root scope
      final networkModule1 = NetworkModule();
      networkModule1.register(testScope);

      // Create a custom scope
      final customScope = Zen.createScope(name: 'TestScope', parent: testScope);

      // Register the same module in the custom scope
      final networkModule2 = NetworkModule();
      networkModule2.register(customScope);

      // Get services from both scopes
      final rootNetworkService = testScope.findInThisScope<NetworkService>();
      final testNetworkService = customScope.findInThisScope<NetworkService>();

      // Verify they are different instances
      expect(rootNetworkService, isNotNull);
      expect(testNetworkService, isNotNull);
      expect(identical(rootNetworkService, testNetworkService), isFalse);

      // Clean up
      customScope.dispose();
      testScope.dispose();
    });

    test('should handle end-to-end authentication and profile flow', () async {
      // Create a test scope
      final testScope = Zen.createScope(name: 'e2e-test');

      // Register modules
      registerModulesInOrder(testScope);

      // Get controllers
      final authController = testScope.find<AuthController>();
      final profileController = testScope.find<ProfileController>();

      // Initially not logged in
      expect(authController!.isLoggedIn, false);

      // Try to load profile before login (should fail)
      await profileController!.loadProfile();
      expect(profileController.error, isNotNull);
      expect(profileController.profile, isNull);

      // Log in
      final loginSuccess = await authController.login('testuser', 'password');
      expect(loginSuccess, true);
      expect(authController.isLoggedIn, true);

      // Now load profile (should succeed)
      await profileController.loadProfile();
      expect(profileController.error, isNull);
      expect(profileController.profile, isNotNull);
      expect(profileController.profile!['email'], 'test@example.com');

      // Check that the entire dependency chain is properly connected
      final authService = testScope.find<AuthService>();
      expect(authService!.isLoggedIn, true);
      expect(authService.token, 'mock-token');

      // Clean up
      testScope.dispose();
    });

    test('should handle lazy module registration', () {
      // Create a test scope
      final testScope = Zen.createScope(name: 'lazy-module-test');

      bool networkServiceCreated = false;
      bool authServiceCreated = false;

      // Register lazy network service
      testScope.putLazy<NetworkService>(() {
        networkServiceCreated = true;
        final service = NetworkService();
        service.initialize();
        return service;
      });

      // Register lazy auth service
      testScope.putLazy<AuthService>(() {
        authServiceCreated = true;
        final networkService = testScope.find<NetworkService>();
        return AuthService(networkService: networkService!);
      });

      // Services should not be created yet
      expect(networkServiceCreated, false);
      expect(authServiceCreated, false);

      // Access auth service (should create both due to dependency)
      final authService = testScope.find<AuthService>();
      expect(authService, isNotNull);
      expect(networkServiceCreated, true);
      expect(authServiceCreated, true);

      // Subsequent access should return same instances
      final networkService = testScope.find<NetworkService>();
      final authService2 = testScope.find<AuthService>();

      expect(authService2, same(authService));
      expect(authService!.networkService, same(networkService));

      // Clean up
      testScope.dispose();
    });

    test('should handle factory module registration', () {
      // Create a test scope
      final testScope = Zen.createScope(name: 'factory-module-test');

      int networkServiceCount = 0;

      // Register factory for network service (new instance each time)
      testScope.putFactory<NetworkService>(() {
        networkServiceCount++;
        final service = NetworkService();
        service.initialize();
        return service;
      });

      // First access
      final networkService1 = testScope.find<NetworkService>();
      expect(networkService1, isNotNull);
      expect(networkService1!.initialized, true);
      expect(networkServiceCount, 1);

      // Second access should create new instance
      final networkService2 = testScope.find<NetworkService>();
      expect(networkService2, isNotNull);
      expect(networkService2!.initialized, true);
      expect(networkServiceCount, 2);

      // Should be different instances
      expect(identical(networkService1, networkService2), false);

      // Clean up
      testScope.dispose();
    });

    test('should properly clean up modules when scope is disposed', () {
      // Create a test scope
      final testScope = Zen.createScope(name: 'cleanup-test');

      // Create a custom scope
      final customScope = Zen.createScope(name: 'CustomScope', parent: testScope);

      // Register auth and network modules in the custom scope
      final networkModule = NetworkModule();
      final authModule = AuthModule();

      networkModule.register(customScope);
      authModule.register(customScope);

      // Verify registration
      expect(customScope.find<NetworkService>(), isNotNull);
      expect(customScope.find<AuthService>(), isNotNull);
      expect(customScope.find<AuthController>(), isNotNull);

      // Dispose the scope
      customScope.dispose();

      // Create a new scope with the same name
      final newScope = Zen.createScope(name: 'CustomScope', parent: testScope);

      // Verify nothing is registered in the new scope
      expect(newScope.findInThisScope<NetworkService>(), isNull);
      expect(newScope.findInThisScope<AuthService>(), isNull);
      expect(newScope.findInThisScope<AuthController>(), isNull);

      // Clean up
      newScope.dispose();
      testScope.dispose();
    });

    test('should handle module registration with tagged services', () {
      final testScope = Zen.createScope(name: 'tagged-services-test');

      // Create a service instance for testing
      final testNetworkService = NetworkService();

      // Register module with the test service
      final networkModule = NetworkModule(testService: testNetworkService);
      networkModule.register(testScope);

      // Verify that the exact service was registered
      final foundService = testScope.find<NetworkService>();
      expect(foundService, isNotNull);
      expect(foundService, same(testNetworkService));
      expect(foundService!.initialized, isTrue);

      testScope.dispose();
    });

    test('should support hierarchical module inheritance', () {
      // Create scope hierarchy
      final rootScope = Zen.createScope(name: 'RootScope');
      final childScope = Zen.createScope(name: 'ChildScope', parent: rootScope);
      final grandchildScope = Zen.createScope(name: 'GrandchildScope', parent: childScope);

      // Register network module in root
      final networkModule = NetworkModule();
      networkModule.register(rootScope);

      // Register auth module in child
      final authModule = AuthModule();
      authModule.register(childScope);

      // Register profile module in grandchild
      final profileModule = ProfileModule();
      profileModule.register(grandchildScope);

      // Verify hierarchical access
      final networkFromRoot = rootScope.find<NetworkService>();
      final networkFromChild = childScope.find<NetworkService>();
      final networkFromGrandchild = grandchildScope.find<NetworkService>();

      expect(networkFromRoot, isNotNull);
      expect(networkFromChild, same(networkFromRoot)); // Inherited from parent
      expect(networkFromGrandchild, same(networkFromRoot)); // Inherited from grandparent

      // Auth service should be accessible from child and grandchild
      expect(rootScope.findInThisScope<AuthService>(), isNull);
      expect(childScope.find<AuthService>(), isNotNull);
      expect(grandchildScope.find<AuthService>(), isNotNull);

      // Profile should only be in grandchild
      expect(rootScope.find<ProfileRepository>(), isNull);
      expect(childScope.find<ProfileRepository>(), isNull);
      expect(grandchildScope.find<ProfileRepository>(), isNotNull);

      // Clean up
      grandchildScope.dispose();
      childScope.dispose();
      rootScope.dispose();
    });
  });
}