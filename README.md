# ZenState
A modern, flexible state management library for Flutter that bridges the gap between local reactive state and global state management, offering both a seamless migration path from GetX-like patterns to Riverpod and supporting a permanent hybrid approach where different state management techniques coexist in the same application.

> Version 0.1.6 brings enhanced controller lifecycle management, improved performance optimizations, and better testing utilities.
>

## Why ZenState?
ZenState serves two complementary purposes:
1. It provides a migration path for large Flutter applications transitioning from simpler state management approaches (like GetX) to more robust solutions (like Riverpod) without rewriting the entire codebase at once.
2. It enables a hybrid state management approach where you can permanently use different patterns for different parts of your application based on their specific requirements.

### Key Advantages:
- ✅ **Hierarchical Scopes**: Nested controller access with proper dependency inheritance
- ✅ **Module System**: Organized dependency registration with clear boundaries
- ✅ **Dependency Safety**: Automatic circular dependency detection and resolution
- ✅ **Gradual Migration**: Keep existing code working while transitioning parts of your app
- ✅ **Hybrid Architecture**: Use the right state management approach for each specific use case
- ✅ **Unified Syntax**: Similar API across different state management levels
- ✅ **Reduced Boilerplate**: Concise syntax for common state operations
- ✅ **Flexibility**: Choose the right approach for different scenarios
- ✅ **Performance Monitoring**: Built-in metrics to identify bottlenecks
- ✅ **Async Operations**: Built-in effect system for handling loading states
- ✅ **State Bridging**: Seamlessly bridge between local and global state
- ✅ **Reactive Base**: Core reactive primitives for building reactive systems
- ✅ **RX Bridge**: Connect reactive state with Riverpod providers
- ✅ **Zen Effects**: Handle async operations with built-in loading, error, and success states
- ✅ **Enhanced Type Safety**: Generic type constraints throughout the library with compile-time type checking
- ✅ **Performance Optimizations**: Intelligent rebuild management and memory efficiency improvements
- ✅ **Enhanced Testing Utilities**: Better support for testing reactive state

## Acknowledgments
ZenState draws inspiration from and builds upon the patterns established by:
- [GetX](https://pub.dev/packages/get) - For its intuitive reactive state management syntax and simplicity
- [Riverpod](https://riverpod.dev/) - For its robust, testable provider-based architecture

This library aims to bridge the gap between these approaches and provide a migration path for teams looking to transition from one pattern to another.
## The Four Levels of State Management
ZenState introduces a unique approach with four distinct levels of state management that can coexist in the same application:
1. () - Similar to GetX's reactive values **Level 1: Local Reactive State**`Rx<T>`
2. () - Bridge between local state and Riverpod **Level 2: Transitional Riverpod**`RxNotifier<T>`
3. - Standard Riverpod patterns for complex state **Level 3: Pure Riverpod**
4. - Fine-grained control for performance-critical sections **Level 4: Manual Updates**

This tiered approach lets you adopt more advanced patterns incrementally, focusing on the most important parts of your application first.
## Quick Start
### Installation
Add ZenState to your : `pubspec.yaml`
``` yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^[latest_version]
  zenify:
    git:
      url: https://github.com/sdegenaar/zenify.git
      ref: v0.1.6
```
### Initialize ZenState
``` dart
void main() {
  // Initialize for development environment
  ZenConfig.applyEnvironment('dev');
  
  // Create and provide the Riverpod container
  final container = ProviderContainer();
  Zen.init(container);
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}
```
### Your First ZenController
``` dart
class CounterController extends ZenController {
  // Level 1: Local state (GetX-like)
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
ZenState now supports hierarchical scoping for controllers, allowing for better organization and access patterns:
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
Organize your controllers with the new module system:
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
  // Initialize ZenState
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
ZenState now automatically detects and reports circular dependencies:
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
## Migration Path Examples
### Level 1: Local Reactive State
Similar to GetX's approach, perfect for starting your migration: `.obs`
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
### Level 2: Transitional Riverpod
Bridge the gap with RxNotifier that creates Riverpod providers:
``` dart
// In controller
final counter = RxNotifier<int>(0);
late final counterProvider = counter.createProvider(debugName: 'counter');

void increment() {
  counter + 1;  // Same syntax as Level 1
}

// In UI - use RiverpodObx for automatic rebuilds with Riverpod
RiverpodObx((ref) {
  final count = ref.watch(controller.counterProvider);
  return Text('Count: $count');
});
```
### Level 3: Pure Riverpod
Fully embrace Riverpod for complex state management:
``` dart
// In controller or separate file
static final usersProvider = StateNotifierProvider<UsersNotifier, List<User>>(
  (ref) => UsersNotifier(),
  name: 'users',
);

// In UI - use standard Riverpod Consumer
Consumer(
  builder: (context, ref, _) {
    final users = ref.watch(usersProvider);
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) => UserListItem(users[index]),
    );
  },
);
```
### Level 4: Manual Updates
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
ZenState can automatically manage controller lifecycles based on routes:
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
ZenState now provides enhanced testing utilities:
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
- **Beta Stage**: While more stable, this library is still in beta with potential bugs
- **API Stability**: Some breaking changes may occur in future versions
- **Performance**: Still being optimized for very large-scale applications
- **Documentation**: Continuously improving but may have some gaps

## Roadmap
- **Phase 5: Developer Experience** (Coming Next)
  - Comprehensive debugging tools
  - Visual state inspector
  - Code generation utilities
  - Migration assistants

- Expanded documentation and examples
- Additional performance optimizations
- More advanced reactive patterns
- Expanded testing utilities

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
## License
This project is licensed under the MIT License - see the LICENSE file for details.
