# Zenify

[![pub package](https://img.shields.io/pub/v/zenify.svg)](https://pub.dev/packages/zenify)
[![likes](https://img.shields.io/pub/likes/zenify?logo=dart)](https://pub.dev/packages/zenify/score)
[![pub points](https://img.shields.io/pub/points/zenify?logo=dart)](https://pub.dev/packages/zenify/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A modern state management library for Flutter that brings true "zen" to your development experience. Clean, intuitive, and powerful.

## Why Zenify?
**Stop fighting with state management.** Zenify offers an elegant solution that keeps your codebase clean and your mind at peace:
- **🚀 Less Boilerplate**: Write less code while accomplishing more
- **🏗️ Module System**: Organize dependencies into clean, reusable modules
- **🔗 Natural Hierarchy**: Nested scopes that automatically inherit from parents
- **⚡ Flexible Reactivity**: Choose between automatic UI updates or manual control
- **🔒 Strong Type Safety**: Catch errors at compile-time with enhanced type constraints
- **✨ Elegant Async Handling**: Built-in effects system for loading, error, and success states
- **🔍 Production-Safe Logging**: Type-safe, environment-based configuration with granular log levels
- **🧪 Testing Ready**: Comprehensive testing utilities out of the box

## What Makes Zenify Different?

Zenify builds on the shoulders of giants, taking inspiration from excellent libraries like **GetX**, **Provider**, and **Riverpod**. Our focus is on bringing **hierarchical dependency injection** and **automatic lifecycle management** to Flutter state management.

**Zenify's unique strengths:**
- 🏗️ **Native hierarchical scopes** - Dependencies flow naturally from parent to child
- 🔄 **Automatic cleanup** - No manual disposal needed, prevents memory leaks
- ✨ **Built-in async effects** - Loading/error states handled automatically
- 🧪 **Production-validated** - Currently being tested in real-world migration

## 🔄 Familiar Patterns, Enhanced Features

If you're familiar with **GetX**, you'll feel right at home! Zenify draws inspiration from Jonny Borges' excellent work, preserving the reactive patterns, keeping the api very similar,
while adding enhanced capabilities for complex applications.

We've also incorporated proven concepts from **Riverpod's** hierarchical scoping and **Provider's** context-based inheritance to create a comprehensive solution.


## Development Status

> **🚧 Active Development Phase**
>
> **Progress: Real-world production migration in progress** ⚙️
>
> Zenify is currently in active development with a **real-world production migration underway**. While the core APIs are stable and thoroughly tested, we're continuously improving based on real production feedback.
>
> **What this means for you:**
> - ✅ **Core features are production-ready** - Hierarchical DI, reactive state, and effects system
> - ✅ **Comprehensive test coverage** - Memory leak detection, lifecycle tests, performance benchmarks
> - ✅ **Real-world validation** - Currently migrating a production Flutter app to Zenify
> - ⚠️ **API refinements possible** - Minor breaking changes may occur before v1.0
> - 📈 **Rapid improvements** - Features and optimizations added based on production usage
>
> **Perfect for:** New projects, prototypes, and developers who want cutting-edge state management
>
> **Consider waiting if:** You need absolute API stability for large existing codebases

## Quick Start (30 seconds)
### 1. Install
```yaml
dependencies:
  zenify: ^0.6.2
```

### 2. Initialize
``` dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Type-safe configuration (recommended) ✨
  if (kReleaseMode) {
    ZenConfig.applyEnvironment(ZenEnvironment.production);
  } else {
    ZenConfig.applyEnvironment(ZenEnvironment.development);
  }
  
  //OR
  
  // Fine-grained control
  ZenConfig.configure(
    level: ZenLogLevel.info,
    performanceTracking: true,
  );
  
  runApp(const MyApp());
}
```
### 3. Create Your First Controller
``` dart
class CounterController extends ZenController {
  final count = 0.obs();
  
  void increment() => count.value++;
  void decrement() => count.value--;
}
```
### 4. Optional) Register a Service
``` dart
class LoggingService extends ZenService {
    @override
    void onInit() {/* setup sinks, files, etc. */}

    @override
    void onClose() {/* flush and close */}
}

// Permanent by default when using Zen.put
Zen.put<LoggingService>(LoggingService());
```
### 5. Use in Your Page
``` dart
class CounterPage extends ZenView<CounterController> {
  @override
  CounterController createController() => CounterController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: Column(
          children: [
            Obx(() => Text('Count: ${controller.count.value}')),
            ElevatedButton(
              onPressed: controller.increment,
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
```
**That's it!** You have a fully reactive counter with automatic cleanup and type safety.
## ⚡ Performance Highlights
- **Minimal Rebuilds**: Only affected widgets update, not entire subtrees
- **Memory Efficient**: Automatic scope cleanup prevents leaks and dangling references
- **Zero Overhead**: Built on Flutter's optimized ValueNotifier foundation
- **Smart Disposal**: Intelligent lifecycle management with hierarchical cleanup
- **Production Tested**: Real-world app migration validates performance at scale

_See [Performance Guide](doc/performance_guide.md) for detailed benchmarks_
## Production-Ready Reactive System
**Beyond basic reactive state** - Zenify includes a comprehensive reactive system designed for production applications:
### RxFuture - Reactive Async Operations
``` dart
class DataController extends ZenController {
  late final RxFuture<List<User>> usersFuture;

  @override
  void onInit() {
    super.onInit();
    usersFuture = RxFuture.fromFactory(() => userService.getUsers());
  }

  void refreshData() => usersFuture.refresh(); // Automatic loading states
}

// In UI - automatic state management
Obx(() {
  if (controller.usersFuture.isLoading) return CircularProgressIndicator();
  if (controller.usersFuture.hasError) return ErrorWidget(controller.usersFuture.errorMessage);
  if (controller.usersFuture.hasData) return UserList(users: controller.usersFuture.data!);
  return SizedBox.shrink();
})
```
### RxComputed - Smart Dependency Tracking
``` dart
class ShoppingController extends ZenController {
  final cartItems = <CartItem>[].obs();
  final taxRate = 0.08.obs();

  @override
  void onInit() {
    super.onInit();
    
    // These automatically update when dependencies change
    subtotal = computed(() => cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity)));
    tax = computed(() => subtotal.value * taxRate.value);
    total = computed(() => subtotal.value + tax.value);
  }

  void addItem(CartItem item) {
    cartItems.add(item); // All computed values automatically update!
  }
}

// In UI - automatic updates
Obx(() => Text('Subtotal: \$${controller.subtotal.value.toStringAsFixed(2)}'))
Obx(() => Text('Tax: \$${controller.tax.value.toStringAsFixed(2)}'))
Obx(() => Text('Total: \$${controller.total.value.toStringAsFixed(2)}'))
```
### RxResult - Production Error Handling
``` dart
class UserController extends ZenController {
  Future<void> saveUser(User user) async {
    final result = await RxResult.tryExecuteAsync(() => userService.saveUser(user), 'save user');
    
    result.onSuccess((savedUser) {
      users.add(savedUser);
      showSuccess('User saved successfully');
    });
    
    result.onFailure((error) {
      showError('Failed to save user: ${error.message}');
    });
  }

  // Safe list operations with error handling
  void updateUserSafely(int index, User newUser) {
    final result = users.trySetAt(index, newUser);
    if (result.isFailure) showError('Invalid index: $index');
  }
}
```
### Advanced Reactive Patterns
``` dart
class AdvancedController extends ZenController {
  final searchQuery = ''.obs();
  final products = <Product>[].obs();
  final isLoading = false.obs();

  @override
  void onInit() {
    super.onInit();

    // Debounced search with error handling
    searchQuery.debounce(Duration(milliseconds: 500), (query) async {
      if (query.isEmpty) return products.clear();

      isLoading.value = true;
      final result = await RxResult.tryExecuteAsync(() => productService.search(query));
      
      result.onSuccess((results) => products.assignAll(results));
      result.onFailure((error) => showError('Search failed: ${error.message}'));
      
      isLoading.value = false;
    });
  }
}
```
**Benefits:**
- ✨ **Comprehensive error handling** with graceful degradation
- **Smart dependency tracking** with automatic cleanup
- **Type-safe async operations** with built-in loading states
- **Production-validated** with real-world error scenarios

## Handle Async Operations with Effects
``` dart
class UserController extends ZenController {
  late final userEffect = createEffect<User>(name: 'user');
  
  Future<void> loadUser() async {
    await userEffect.run(() => api.getUser());
  }
}

// In your UI - automatic loading states
ZenEffectBuilder<User>(
  effect: controller.userEffect,
  onLoading: () => const CircularProgressIndicator(),
  onSuccess: (user) => UserProfile(user),
  onError: (error) => ErrorMessage(error),
)
```
**Benefits:**
- ✨ **Automatic state management** - Loading, success, error handled for you
- **Retry logic** - Built-in error recovery and retry mechanisms
- **Type safety** - Full compile-time guarantees for async operations
- **Testing friendly** - Easy to mock and test different states

## Flexible Widget System
Choose the right widget for your needs:
### ZenConsumer - Efficient Dependency Access
``` dart
// Access services efficiently
ZenConsumer<CartService>(
  builder: (cartService) => cartService != null
    ? CartIcon(itemCount: cartService.itemCount)
    : const EmptyCartIcon(),
)

// Access optional dependencies gracefully
ZenConsumer<AuthService>(
  tag: 'premium',
  builder: (authService) => authService?.isAuthenticated.value == true
    ? const PremiumFeatures()
    : const UpgradePrompt(),
)
```
### ZenBuilder - Performance Control
``` dart
class PerformanceOptimizedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Only rebuilds when controller.update(['header']) is called
        ZenBuilder<DashboardController>(
          id: 'header',
          builder: (context, controller) => AppBar(
            title: Text(controller.title),
            actions: [
              IconButton(
                icon: Icon(controller.settingsIcon),
                onPressed: controller.openSettings,
              ),
            ],
          ),
        ),

        // Only rebuilds when controller.update(['content']) is called
        ZenBuilder<DashboardController>(
          id: 'content',
          builder: (context, controller) => Expanded(
            child: ListView.builder(
              itemCount: controller.items.length,
              itemBuilder: (context, index) => ItemWidget(item: controller.items[index]),
            ),
          ),
        ),
      ],
    );
  }
}
```
### Obx - Reactive Updates
``` dart
class ReactiveWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Zen.find<CounterController>();

    return Column(
      children: [
        // Automatically rebuilds when counter.value changes
        Obx(() => Text('Count: ${controller.counter.value}')),

        // Multiple reactive values
        Obx(() => AnimatedContainer(
          duration: Duration(milliseconds: 300),
          color: controller.isActive.value ? Colors.green : Colors.red,
          child: Text('Status: ${controller.status.value}'),
        )),
      ],
    );
  }
}
```
### Widget Comparison

| Widget | Purpose | Rebuild Trigger | Best For |
|--------|---------|------------------|----------|
| **ZenView** | Page base class | Automatic lifecycle | Full pages with controllers |
| **ZenRoute** | Route navigation | Route lifecycle | Module/scope management |
| **ZenConsumer** | Dependency access | Manual | Optional service access |
| **ZenBuilder** | Manual updates | `controller.update()` | Performance optimization |
| **Obx** | Reactive updates | Reactive value changes | Simple reactive widgets |
| **ZenEffectBuilder** | Async operations | Effect state changes | Loading/Error/Success states |
| **ZenControllerScope** | Custom lifecycle | Manual scope control | Explicit lifecycle management |

## Global Module Registration
Set up your entire app's dependency architecture at startup:
``` dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Zenify
  ZenConfig.applyEnvironment(ZenEnvironment.development);
  
  // Register global modules
  await Zen.registerModules([
    // Core infrastructure
    CoreModule(),        // Database, storage, logging
    NetworkModule(),     // API clients, connectivity
    AuthModule(),        // Authentication, user management
   
  ]);
  
  runApp(const MyApp());
}

class CoreModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // Global services available everywhere
    Zen.put<DatabaseService>(DatabaseService(), permanent: true);
    Zen.put<CacheService>(CacheService(), permanent: true);
    Zen.put<LoggingService>(LoggingService(), permanent: true);
  }
}

// Access anywhere in your app
class AnyController extends ZenController {
  // These are automatically available from global registration
  final database = Zen.find<DatabaseService>();
  final cache = Zen.find<CacheService>();
  final logger = Zen.find<LoggingService>();
}
```
**Benefits:**
- ️ **Centralized setup** - Configure your entire app architecture in one place
- **Hot reload friendly** - Services persist across development iterations
- **Testing support** - Easy to swap modules for testing
- **Feature isolation** - Keep related dependencies grouped together

## Services (ZenService) 
Long-lived app-wide services (e.g., auth, logging, cache) with safe lifecycle.

- Lifecycle:
    - `onInit()` runs when the service first initializes
    - `onClose()` runs during disposal
    - `isInitialized` is true only after a successful `onInit()`
- DI behavior:
    - `Zen.put(instance)`: `ZenService` defaults to `isPermanent = true` and initializes via lifecycle manager
    - `Zen.putLazy(factory)`: permanence is explicit (default `false`); instance is created and initialized on first `Zen.find()`
    - `Zen.putFactory(factory)`: unchanged; always creates a new instance (no permanence)
    - `Zen.find()`: auto-initializes a `ZenService` on first access (covers lazy/scoped resolutions)

Example:
``` dart
class AuthService extends ZenService {
    late final StreamSubscription _tokenSub;

    @override
    void onInit() {
        _tokenSub = tokenStream.listen(_handleToken);
    }

    @override
    void onClose() {
        _tokenSub.cancel();
    }

    void _handleToken(String token) {/* ... */}
}

// Registration: permanent by default for services
Zen.put<AuthService>(AuthService());

// Lazy registration (make permanent explicitly if desired)
Zen.putLazy<AuthService>(() => AuthService(), isPermanent: true);

// Usage anywhere
final auth = Zen.find<AuthService>(); // auto-initializes if needed
```

## Organize with Modules
Scale your app with clean dependency organization:
``` dart
// Define module with controller
class UserModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.putLazy<UserService>(() => UserService());
    scope.putLazy<UserController>(() => UserController());
  }
}

// Use in routes with automatic cleanup
ZenRoute(
  moduleBuilder: () => UserModule(),
  page: UserProfilePage(), // Page extends ZenView<UserController>
  scopeName: 'UserScope'
)

// Page doesn't need createController() - gets it from module
class UserProfilePage extends ZenView<UserController> {
  // No createController override needed!
  // ZenView automatically finds UserController from the module
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Profile')),
      body: Obx(() => Text('User: ${controller.userName.value}')),
    );
  }
}
```
**Benefits:**
- 🗂️ **Organized Dependencies** - Group related services together
- 🔄 **Automatic Cleanup** - Modules dispose when routes change
- 🏗️ **Hierarchical Inheritance** - Child modules access parent services
- 🧪 **Testing Friendly** - Swap modules for testing

## ️ Advanced Features
**For complex applications:**
- **️ Route-Based Scoping** - Automatic module lifecycle with navigation using `ZenRoute`
- ** Hierarchical Dependency Injection** - Parent-child scope inheritance with `ZenScopeWidget`
- ** Tagged Dependencies** - Multiple instances with smart resolution
- ** Performance Monitoring** - Built-in metrics and leak detection
- ** Comprehensive Testing** - Mocking, lifecycle, and memory leak tests
- ** Advanced Lifecycle Hooks** - Module initialization and disposal callbacks

### ZenRoute - Route-Based Module Management
``` dart
// Automatic module lifecycle tied to navigation
class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/product':
        return MaterialPageRoute(
          builder: (_) => ZenRoute(
            moduleBuilder: () => ProductModule(),
            page: ProductDetailPage(),
            scopeName: 'ProductScope',
          ),
        );
    }
  }
}
```
### ZenScopeWidget - Custom Scoping
``` dart
// Create scopes at any widget level
showModalBottomSheet(
  context: context,
  builder: (context) => ZenScopeWidget(
    moduleBuilder: () => FilterModule(),
    scopeName: 'FilterScope',
    child: const FilterBottomSheet(),
  ),
);
```
## 📱 Best Practices

### 🎯 Widget Selection

1. **ZenView**: Use as base class for pages with controllers (⭐ recommended)
2. **ZenRoute**: Use for route-based module and scope management (⭐ navigation)
3. **ZenConsumer**: Use for accessing any dependency efficiently with null safety
4. **ZenBuilder**: Use for manual update control with ZenControllers
5. **Obx**: Use for reactive state with automatic rebuilds
6. **ZenEffectBuilder**: Use for async operations with loading/error/success states
7. **ZenControllerScope**: Use when you need explicit lifecycle control

### 🏗️ Module Organization

1. **Feature Modules**: Create specific modules for each major feature/route
2. **Core Modules**: Register shared services in global/parent modules
3. **Hierarchy Design**: Keep scope depth reasonable (max 3-4 levels)
4. **Dependency Checking**: Always verify required dependencies exist in parent scopes
5. **Lifecycle Hooks**: Use `onInit` and `onClose` for resource management

### ⚡ Performance Optimization

1. **Use Effects**: Leverage `ZenEffect` for async operations with built-in state management
2. **Selective Updates**: Use `ZenBuilder` with specific IDs for fine-grained updates
3. **Lazy Loading**: Use `putLazy()` for dependencies that aren't immediately needed
4. **Computed Values**: Use computed properties for derived state instead of manual calculations
5. **Memory Management**: Dispose controllers and effects properly in `onClose`

### 🛡️ Error Handling

1. **Use RxResult**: For operations that can fail gracefully
2. **Try* Methods**: Leverage try* methods for safe reactive operations
3. **Global Handlers**: Configure global error handling for production
4. **Fallback Values**: Provide graceful fallbacks for missing dependencies
5. **Logging**: Log errors appropriately for debugging

### 🧪 Testing Strategy

1. **Unit Tests**: Test controllers in isolation using dependency injection
2. **Widget Tests**: Use `ZenTestScope` for component testing
3. **Integration Tests**: Test module interactions and lifecycle
4. **Mock Dependencies**: Replace services with mocks for testing
5. **Memory Tests**: Verify proper cleanup and disposal

### 📁 Code Organization

1. **Single Responsibility**: Keep controllers focused on single responsibilities
2. **Feature-Based Structure**: Organize by feature, not by type
3. **Hierarchical Scopes**: Use scope hierarchy for logical dependency flow
4. **Clear Naming**: Use descriptive names for scopes and modules
5. **Documentation**: Document complex reactive logic and dependencies

### 🚫 Common Anti-Patterns to Avoid

1. **DON'T** mix UI logic in controllers
2. **DON'T** create circular dependencies between services
3. **DON'T** forget to dispose resources in `onClose`
4. **DON'T** use excessive scope nesting (>4 levels)
5. **DON'T** ignore error handling in production code

### 📋 Quick Checklist

Before releasing to production:
- ✅ Controllers have single responsibilities
- ✅ Async operations use effects or proper error handling
- ✅ Resources are properly disposed in `onClose()`
- ✅ Dependencies are organized in logical modules
- ✅ Critical paths have comprehensive tests
- ✅ Error states have user-friendly fallbacks
- ✅ Performance-critical sections use targeted updates
- ✅ Scope hierarchy is clean and purposeful

_Explore [Advanced Guides](doc/) for production patterns and comprehensive examples_
## Complete Documentation
**New to Zenify?** Start with the guides that match your needs:
### Core Guides
- **[Reactive Core Guide](doc/reactive_core_guide.md)** - Master reactive values, collections, and computed properties
- **[Effects Usage Guide](doc/effects_usage_guide.md)** - Master async operations with built-in loading/error states
- **[State Management Patterns](doc/state_management_patterns.md)** - Architectural patterns and best practices
- **[Hierarchical Scopes Guide](doc/hierarchical_scopes_guide.md)** - Advanced dependency injection and scope management

### Examples & Learning
- **[Counter App](example/counter)** - Simple reactive state (5 minutes)
- **[Todo App](example/todo)** - CRUD operations with effects (10 minutes)
- **[E-commerce App](example/ecommerce)** - Real-world patterns (20 minutes)
- **[Hierarchical Scopes Demo](example/hierarchical_scopes)** - Advanced dependency patterns
- **[Showcase App](example/zenify_showcase)** - All features demonstrated

### Quick References _(Coming Soon)_
- **Core Concepts** - Controllers, reactive state, and UI widgets
- **API Reference** - Complete method and class documentation
- **Migration Guide** - Moving from other state management solutions
- **Testing Guide** - Unit and widget testing with Zenify

## Key Features at a Glance
### ZenView - Direct Controller Access
``` dart
class ProductPage extends ZenView<ProductController> {
  @override
  Widget build(BuildContext context) {
    // Direct access - no Zen.find() needed!
    return Text(controller.productName.value);
  }
}
```
### Smart Effects System
``` dart
// Automatic state management for async operations
late final dataEffect = createEffect<List<Item>>(name: 'data');

await dataEffect.run(() => api.fetchData());
// Loading, success, and error states handled automatically
```
### Hierarchical Dependency Injection
``` dart
// Parent scope provides shared services
ZenRoute(
  moduleBuilder: () => AppModule(),
  page: HomePage(),
  scopeName: 'AppScope',
)

// Child widgets automatically access parent dependencies
final authService = Zen.find<AuthService>(); // Available everywhere
```
### Flexible Reactivity
``` dart
// Option 1: Automatic reactive updates
Obx(() => Text('Count: ${controller.count.value}'))

// Option 2: Manual control for performance
ZenBuilder<Controller>(
  id: 'specific-section',
  builder: (context, controller) => ExpensiveWidget(controller.data),
)
// Only rebuilds when controller.update(['specific-section']) is called
```
## Credits
Zenify draws inspiration from several excellent state management libraries:
- **GetX** by Jonny Borges - For the intuitive reactive syntax and dependency injection approach
- **Provider** by Remi Rousselet - For context-based dependency inheritance concepts
- **Riverpod** by Remi Rousselet - For improved type safety and testability patterns

## Community & Support
- **Found a bug?** [Open an issue](https://github.com/sdegenaar/zenify/issues)
- **Have an idea?** [Start a discussion](https://github.com/sdegenaar/zenify/discussions)
- **Need help?** Check our [comprehensive guides](doc/)
- **Want to contribute?** See [CONTRIBUTING.md](CONTRIBUTING.md)

## License
Zenify is released under the [MIT License](LICENSE).
## 🚀 Ready to Get Started?
**Choose your path:**
- 👋 **New to Zenify?** → Start with [Counter Example](example/counter) (5 min)
- 🏗️ **Building something real?** → See [E-commerce Example](example/ecommerce) (20 min)
- 🔄 **Migrating from GetX/Provider?** → Check [Migration Guide](doc/migration_guide.md)
- 🏢 **Enterprise project?** → Review [Hierarchical Scopes Guide](doc/hierarchical_scopes_guide.md)

**Questions? We're here to help!**
- 💬 [Start a Discussion](https://github.com/sdegenaar/zenify/discussions)
- 📚 [Browse Documentation](doc/)
- 🐛 [Report Issues](https://github.com/sdegenaar/zenify/issues)

**Ready to bring zen to your Flutter development?** Start exploring and experience the difference! ✨
