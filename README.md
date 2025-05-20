# Zenify
A modern, flexible state management library for Flutter offering an intuitive approach to reactive state management with a clean, concise API.

> Version 0.1.6 brings enhanced controller lifecycle management, improved performance optimizations, and better testing utilities.
>

## Why Zenify?
Zenify (formerly ZenState) provides a lightweight yet powerful approach to Flutter state management focused on:
### Key Advantages:
- ✅ Hierarchical Scopes: Nested controller access with proper dependency inheritance
- ✅ Module System: Organized dependency registration with clear boundaries
- ✅ Dependency Safety: Automatic circular dependency detection and resolution
- ✅ Unified Syntax: Consistent API for state management operations
- ✅ Reduced Boilerplate: Concise syntax for common state operations
- ✅ Flexibility: Choose the right approach for different scenarios
- ✅ Performance Monitoring: Built-in metrics to identify bottlenecks
- ✅ Async Operations: Built-in effect system for handling loading states
- ✅ Reactive Base: Core reactive primitives for building reactive systems
- ✅ Zen Effects: Handle async operations with built-in loading, error, and success states
- ✅ Enhanced Type Safety: Generic type constraints throughout the library with compile-time type checking
- ✅ Performance Optimizations: Intelligent rebuild management and memory efficiency improvements
- ✅ Enhanced Testing Utilities: Better support for testing reactive state

## Quick Start
### Installation
Add Zenify to your pubspec.yaml:
``` yaml
dependencies:
  flutter:
    sdk: flutter
  zenify:
    git:
      url: https://github.com/sdegenaar/zenify.git
      ref: v0.1.6
```
### Initialize Zenify
``` dart
void main() {
  // Initialize for development environment
  ZenConfig.applyEnvironment('dev');
  
  runApp(const MyApp());
}
```
### Your First ZenController
``` dart
class CounterController extends ZenController {
  // Local state
  RxInt counter = 0.obs();
  
  void increment() {
    counter + 1;  // Simple operator syntax
  }
}
```
### Using in Widgets
``` dart
class CounterView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenControllerScope<CounterController>(
      create: () => CounterController(),
      child: Scaffold(
        body: Center(
          child: Obx(() {
            final controller = Zen.find<CounterController>()!;
            return Text('Count: ${controller.counter.value}');
          }),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Zen.find<CounterController>()!.increment(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```
## Dependency Management
### Hierarchical Scopes
Zenify supports hierarchical scoping for controllers, allowing for better organization and access patterns:
``` dart
// Create nested scopes
ZenControllerScope<ParentController>(
  create: () => ParentController(),
  child: ZenControllerScope<ChildController>(
    create: () => ChildController(),
    child: Builder(
      builder: (context) {
        // Child controllers can access parent controllers
        final child = Zen.find<ChildController>();
        final parent = Zen.find<ParentController>(); // Available due to hierarchical scope
        return YourWidget();
      },
    ),
  ),
);
```
### Module System
Organize your controllers with the module system:
``` dart
// Define a module for related controllers
class AuthModule extends ZenModule {
  @override
  void registerDependencies() {
    // Register controllers with various lifetimes
    register<AuthController>(
      () => AuthController(), 
      permanent: true,
    );
    
    register<UserProfileController>(
      () => UserProfileController(),
      lazy: true, // Only initialized when first requested
    );
  }
}

// In your app initialization
void main() {
  // Initialize Zenify
  ZenConfig.applyEnvironment('dev');
  
  // Register all modules
  Zen.registerModules([
    AuthModule(),
    SettingsModule(),
    FeatureModule(),
  ]);
  
  runApp(const MyApp());
}
```
### Circular Dependency Detection
Zenify automatically detects and reports circular dependencies:
``` dart
// This would trigger a clear error message instead of an infinite loop
class ServiceA extends ZenController {
  late final ServiceB serviceB;
  
  ServiceA() {
    serviceB = Zen.find<ServiceB>()!;
  }
}

class ServiceB extends ZenController {
  late final ServiceA serviceA;
  
  ServiceB() {
    serviceA = Zen.find<ServiceA>()!;
  }
}
```
## State Management Approaches
Zenify provides intuitive reactive state management:
### Reactive State
``` dart
// In controller
RxInt counter = 0.obs();
RxString name = 'John'.obs();
RxBool isActive = true.obs();
RxList<String> items = <String>[].obs();

//or 
//final name = rxString('John');
//final isActive = rxBool(true);
//final items = rxList<String>([]);

// Update values with familiar syntax
void updateName() {
  name + ' Doe';  // Append to string
  isActive.toggle();  // Toggle boolean
  items.value.add('New Item');
  items.refresh();  // Notify listeners for collections
}

// In UI - use Obx for automatic rebuilds
Obx(() => Text('Name: ${controller.name.value}'));
```
### Manual Updates
For fine-grained control and maximum performance:
``` dart
// In controller
int manualCounter = 0;

void incrementAll() {
  manualCounter++;
  update();  // Update all ZenBuilder widgets
}

void incrementSection(String sectionId) {
  manualCounter++;
  update([sectionId]);  // Update only specific section
}

// In UI
ZenBuilder<MyController>(
  id: 'counter-section',
  builder: (controller) => Text('${controller.manualCounter}'),
);
```
## Advanced Features
### Automatic Lifecycle Management
Zenify can automatically manage controller lifecycles based on routes:
``` dart
void main() {
  // Create route observer for auto-disposing controllers
  final routeObserver = ZenRouteObserver();

  // Register controllers for routes
  routeObserver.registerForRoute('/home', [HomeController]);
  routeObserver.registerForRoute('/profile', [ProfileController]);

  MaterialApp(
    navigatorObservers: [routeObserver],
    // ...
  );
}
```
### Workers for Reactive Operations
``` dart
// In controller constructor
ZenWorkers.debounce(
  searchQuery,
  (query) => performSearch(query),
  duration: const Duration(milliseconds: 500),
);

ZenWorkers.ever(
  isLoggedIn,
  (loggedIn) => loggedIn ? navigateToHome() : navigateToLogin(),
);
```
### Zen Effects for Async Operations
``` dart
// In controller
final userEffect = ZenEffect<User>();

Future<void> loadUser(int userId) async {
  userEffect.loading(); // Set loading state
  try {
    final user = await userRepository.getUser(userId);
    userEffect.success(user); // Set success state with data
  } catch (e) {
    userEffect.error(e); // Set error state
  }
}

// In UI
ZenEffectBuilder<User>(
  effect: controller.userEffect,
  onLoading: () => CircularProgressIndicator(),
  onError: (error) => Text('Error: $error'),
  onSuccess: (user) => UserDetailCard(user),
);
```
### Performance Monitoring
``` dart
// Track operation time
ZenMetrics.startTiming('expensiveOperation');
await performExpensiveOperation();
ZenMetrics.stopTiming('expensiveOperation');

// Get insights in development
ZenMetrics.startPeriodicLogging(const Duration(minutes: 1));
```
## Testing Support
Zenify provides enhanced testing utilities:
``` dart
// Testing a controller with dependencies
void main() {
  testWidgets('Counter increments test', (tester) async {
    // Setup test environment
    final testContainer = ZenTestContainer();
    
    // Register mocks
    testContainer.register<ApiService>(() => MockApiService());
    
    // Register controller under test
    testContainer.register<CounterController>(() => CounterController());
    
    // Run test with provided container
    await tester.pumpWidget(
      ZenTestScope(
        container: testContainer,
        child: CounterTestWidget(),
      ),
    );
    
    // Perform test actions and assertions
    final controller = testContainer.find<CounterController>();
    expect(controller.counter.value, 0);
    controller.increment();
    expect(controller.counter.value, 1);
  });
}
```
## Known Limitations
- Beta Stage: While more stable, this library is still in beta with potential bugs
- API Stability: Some breaking changes may occur in future versions
- Performance: Still being optimized for very large-scale applications
- Documentation: Continuously improving but may have some gaps

## Roadmap
- Phase 5: Developer Experience (Coming Next)
  - Comprehensive debugging tools
  - Visual state inspector
  - Code generation utilities

- Expanded documentation and examples
- Additional performance optimizations
- More advanced reactive patterns
- Expanded testing utilities

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
## License
This project is licensed under the MIT License - see the LICENSE file for details.
