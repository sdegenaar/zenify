# Zenify

[![pub package](https://img.shields.io/pub/v/zenify.svg)](https://pub.dev/packages/zenify)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A modern state management library for Flutter that brings true "zen" to your development experience. Clean, intuitive, and powerful.

## Why Zenify?

**Stop fighting with state management.** Zenify offers an elegant solution that keeps your codebase clean and your mind at peace:

- **🚀 Less Boilerplate**: Write less code while accomplishing more
- **🏗️ Module System**: Organize dependencies into clean, reusable modules
- **🔗 Natural Hierarchy**: Nested scopes that automatically inherit from parents
- **⚡ Flexible Reactivity**: Choose between automatic UI updates or manual control
- **🔒 Strong Type Safety**: Catch errors at compile-time with enhanced type constraints
- **✨ Elegant Async Handling**: Built-in effects system for loading, error, and success states
- **🧪 Testing Ready**: Comprehensive testing utilities out of the box

## Quick Start (30 seconds)

### 1. Install
```yaml
dependencies:
  zenify:
    git:
      url: https://github.com/sdegenaar/zenify.git
      ref: v0.4.0
```

### 2. Initialize
``` dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ZenConfig.applyEnvironment('dev');
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
### 4. Use in Your Page
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

## Organize with Modules

Scale your app with clean dependency organization:

```dart
// Define feature modules
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
  page: UserProfilePage(),
  scopeName: 'UserScope',
  useParentScope: true, // Inherit from parent scopes
)

// Controllers get dependencies automatically
class UserController extends ZenController {
  final userService = Zen.find<UserService>(); // Available from module
}

```
**Benefits:**
- 🗂️ **Organized Dependencies** - Group related services together
- 🔄 **Automatic Cleanup** - Modules dispose when routes change
- 🏗️ **Hierarchical Inheritance** - Child modules access parent services
- 🧪 **Testing Friendly** - Swap modules for testing

## Complete Documentation
**New to Zenify?** Start with the guides that match your needs:
### Core Guides
- **[Reactive Core Guide](docs/reactive_core_guide.md)** - Master reactive values, collections, and computed properties
- **[Effects Usage Guide](docs/effects_usage_guide.md)** - Master async operations with built-in loading/error states
- **[State Management Patterns](docs/state_management_patterns.md)** - Architectural patterns and best practices
- **[Hierarchical Scopes Guide](docs/hierarchical_scopes_guide.md)** - Advanced dependency injection and scope management

### Examples & Learning
- **[Counter App](examples/counter)** - Simple reactive state (5 minutes)
- **[Todo App](examples/todo)** - CRUD operations with effects (10 minutes)
- **[E-commerce App](examples/ecommerce)** - Real-world patterns (20 minutes)
- **[Hierarchical Scopes Demo](examples/hierarchical_scopes)** - Advanced dependency patterns
- **[Showcase App](examples/zenify_showcase)** - All features demonstrated

### Quick References
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
## Community & Support
- **Found a bug?** [Open an issue](https://github.com/sdegenaar/zenify/issues)
- **Have an idea?** [Start a discussion](https://github.com/sdegenaar/zenify/discussions)
- **Need help?** Check our [comprehensive guides](docs/)
- **Want to contribute?** See [CONTRIBUTING.md](CONTRIBUTING.md)

## License
Zenify is released under the [MIT License](LICENSE).
**Ready to bring zen to your Flutter development?** Start with the [Counter Example](examples/counter) and explore the [comprehensive guides](docs/) to master advanced patterns.
