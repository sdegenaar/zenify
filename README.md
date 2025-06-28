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

## What Makes Zenify Different?

Zenify builds on the shoulders of giants, taking inspiration from excellent libraries like **GetX**, **Provider**, and **Riverpod**. Our focus is on bringing **hierarchical dependency injection** and **automatic lifecycle management** to Flutter state management.

**Zenify's unique strengths:**
- 🏗️ **Native hierarchical scopes** - Dependencies flow naturally from parent to child
- 🔄 **Automatic cleanup** - No manual disposal needed, prevents memory leaks
- ✨ **Built-in async effects** - Loading/error states handled automatically
- 🧪 **Production-validated** - Currently being tested in real-world migration

**When to consider Zenify:**
- You need complex dependency hierarchies (multi-module apps)
- You want automatic lifecycle management
- You're building new projects and can embrace cutting-edge tools
- You value minimal boilerplate with maximum power

**When to stick with established solutions:**
- You need absolute stability for large existing codebases
- Your team is already productive with current tools
- You prefer the mature ecosystem of existing libraries

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
``` yaml
dependencies:
  zenify:
    git:
      url: https://github.com/sdegenaar/zenify.git
      ref: v0.4.1
  # Will be available on pub.dev soon as: zenify: ^0.4.1
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
## ⚡ Performance Highlights
- **Minimal Rebuilds**: Only affected widgets update
- **Memory Efficient**: Automatic scope cleanup prevents leaks
- **Zero Overhead**: Built on Flutter's ValueNotifier foundation
- **Production Tested**: Real-world app migration validates performance

_See [Performance Guide](doc/performance_guide.md) for detailed benchmarks_
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
``` dart
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

### Quick References *(Coming Soon)*
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
