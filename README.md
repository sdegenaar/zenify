# ZenState
A modern, flexible state management library for Flutter that bridges the gap between local reactive state and global state management, offering both a seamless migration path from GetX-like patterns to Riverpod and supporting a permanent hybrid approach where different state management techniques coexist in the same application.

> **IMPORTANT:** This is a first pass implementation and is NOT PRODUCTION READY. Use at your own risk in development environments only. APIs may change significantly in future versions.
>

## Why ZenState?
ZenState serves two complementary purposes:

1. It provides a migration path for large Flutter applications transitioning from simpler state management approaches (like GetX) to more robust solutions (like Riverpod) without rewriting the entire codebase at once.

2. It enables a hybrid state management approach where you can permanently use different patterns for different parts of your application based on their specific requirements.

### Key Advantages:
- ✅ **Gradual Migration**: Keep existing code working while transitioning parts of your app
- ✅ **Hybrid Architecture**: Use the right state management approach for each specific use case
- ✅ **Unified Syntax**: Similar API across different state management levels
- ✅ **Reduced Boilerplate**: Concise syntax for common state operations
- ✅ **Flexibility**: Choose the right approach for different scenarios
- ✅ **Performance Monitoring**: Built-in metrics to identify bottlenecks


## Acknowledgments

ZenState draws inspiration from and builds upon the patterns established by:

- [GetX](https://pub.dev/packages/get) - For its intuitive reactive state management syntax and simplicity
- [Riverpod](https://riverpod.dev/) - For its robust, testable provider-based architecture

This library aims to bridge the gap between these approaches and provide a migration path for teams looking to transition from one pattern to another.

## The Four Levels of State Management

ZenState introduces a unique approach with four distinct levels of state management that can coexist in the same application:
1. **Level 1: Local Reactive State** () - Similar to GetX's reactive values `Rx<T>`
2. () - Bridge between local state and Riverpod **Level 2: Transitional Riverpod**`RxNotifier<T>`
3. Standard Riverpod patterns for complex state **Level 3: Pure Riverpod**
4. **Level 4: Manual Updates** - Fine-grained control for performance-critical sections

This tiered approach lets you adopt more advanced patterns incrementally, focusing on the most important parts of your application first.
## Quick Start
### Installation
Add ZenState to your : `pubspec.yaml`
``` yaml
dependencies:
  flutter:
    sdk: flutter
  riverpod: ^[latest_version]
  flutter_riverpod: ^[latest_version]
  zen_state:
    git:
      url: https://github.com/sdegenaar/zen_state.git
      ref: v0.1.2
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
### Performance Monitoring
``` dart
// Track operation time
ZenMetrics.startTiming('expensiveOperation');
await performExpensiveOperation();
ZenMetrics.stopTiming('expensiveOperation');

// Get insights in development
ZenMetrics.startPeriodicLogging(const Duration(minutes: 1));
```
## Known Limitations
- **Not Production Ready**: This is an experimental library with potential bugs
- **API Stability**: Breaking changes are likely in future versions
- **Performance**: Not fully optimized for large-scale applications
- **Documentation**: Still evolving and may have gaps
- **Testing Support**: Limited testing utilities at this stage

## Roadmap
- Comprehensive documentation and examples
- Performance benchmarks and optimizations
- Enhanced testing utilities
- More worker types and reactive patterns
- Better debuggability and developer tools

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
## License
This project is licensed under the MIT License - see the LICENSE file for details.