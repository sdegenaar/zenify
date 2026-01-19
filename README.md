# Zenify

[![pub package](https://img.shields.io/pub/v/zenify.svg)](https://pub.dev/packages/zenify)
[![likes](https://img.shields.io/pub/likes/zenify?logo=dart)](https://pub.dev/packages/zenify/score)
[![pub points](https://img.shields.io/pub/points/zenify?logo=dart)](https://pub.dev/packages/zenify/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Complete state management for Flutter—hierarchical dependency injection, reactive programming, and intelligent async state. Zero boilerplate, automatic cleanup.**

```dart
// Hierarchical DI with automatic cleanup
scope.put<UserService>(UserService());
final service = scope.find<UserService>()!;  // Access from child scopes

// Reactive state that just works
final count = 0.obs();
ZenObserver(() => Text('$count'))  // Auto-rebuilds

// Smart async with caching
final userQuery = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: (_) => api.getUser(123),
);  // Caching, deduplication, refetching—all handled
```

---

## 🎯 Why Zenify?

Building async-heavy Flutter apps? You're probably fighting:

- 💔 **Manual cache management** - Writing the same cache logic over and over
- 🔄 **Duplicate API calls** - Multiple widgets fetching the same data
- 🏗️ **Memory leaks** - Forgetting to dispose controllers and subscriptions
- 📦 **Boilerplate overload** - Hundreds of lines for simple async state

**Zenify solves all of this.**

---

## ⚡ What Makes Zenify Different

### 🏗️ Hierarchical Scoped Architecture
Riverpod-inspired scoping with **automatic cleanup**. Dependencies flow naturally from parent to child, and scopes dispose themselves automatically when no longer needed. Simple API: `Zen.put()`, `Zen.find()`, `Zen.delete()`.

### 🎯 Zero Boilerplate Reactivity
Reactive system with `.obs()` and `ZenObserver()` (or `Obx()` for GetX users). Write less, accomplish more, keep your code clean. Built on Flutter's ValueNotifier for optimal performance.

### 🔥 React Query Style
A native-inspired implementation of **TanStack Query patterns**: automatic caching, smart refetching, request deduplication, and stale-while-revalidate—built on top of the reactive system.

### 📶 Offline-First Resilience
Don't let network issues break your app. Zenify includes **Robust Persistence**, an **Offline Mutation Queue**, and **Optimistic Updates** out of the box with minimal configuration.

---

## 🏗️ Understanding Scopes (The Foundation)

Zenify organizes dependencies into **three hierarchical levels** with automatic lifecycle management:

### The Three Scope Levels

**🌍 RootScope (Global - App Lifetime)**
- Services like `AuthService`, `CartService`, `ThemeService`
- Lives for entire app session
- Access anywhere via Zen.find<CartService>() or `.to` pattern: `CartService.to.addItem()`

**📦 Module Scope (Feature - Feature Lifetime)**
- Controllers shared across feature pages
- Auto-dispose when leaving feature
- Example: HR feature with `CompanyController` → `DepartmentController` → `EmployeeController`

**📄 Page Scope (Page - Page Lifetime)**
- Page-specific controllers
- Auto-dispose when page pops
- Example: `LoginController`, `ProfileFormController`

### When to Use What

| Scope | Use For | Example             | Lifetime |
|-------|---------|---------------------|----------|
| **RootScope** | Needed across entire app | `Zen.find<T>()`          | App session |
| **Module Scope** | Needed across a feature | Module registration | Feature navigation |
| **Page Scope** | Needed on one page | `createController`  | Single page |

The scope hierarchy automatically manages lifecycle - when you exit a feature, all its controllers clean up automatically. No memory leaks, no manual disposal.

[Learn more about hierarchical scopes →](doc/hierarchical_scopes_guide.md)

---

## 🚀 Quick Start (30 seconds)

### 1. Install

```yaml
dependencies:
  zenify: ^1.6.5
```

### 2. Initialize

```dart
void main() async {
  await Zen.init();
  runApp(MyApp());
}
```

### 3. Create a Controller

```dart
class CounterController extends ZenController {
  final count = 0.obs();
  void increment() => count.value++;
}
```

### 4. Build UI

```dart
class CounterPage extends ZenView<CounterController> {
  @override
  CounterController Function()? get createController => () => CounterController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ZenObserver(() => Text('Count: ${controller.count.value}')),
            ElevatedButton(
              onPressed: controller.increment,
              child: Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**That's it!** Fully reactive with automatic cleanup. No manual disposal, no memory leaks.

> **Note:** `createController` is optional! If your controller is already registered in a module or globally, you can omit it and ZenView will find the controller automatically.

[See complete example →](example/counter)

---

## 🔥 Core Features

### 1. Hierarchical DI with Auto-Cleanup

Organize dependencies naturally with **feature-based modules** and parent-child scopes. When you navigate away, everything cleans up automatically.

```dart
// App-level services (persistent)
class AppModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<AuthService>(AuthService(), isPermanent: true);
    scope.put<DatabaseService>(DatabaseService(), isPermanent: true);
  }
}

// Feature-level controllers (auto-disposed)
class UserModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // Access parent services via Zen.find()
    final db = scope.find<DatabaseService>()!;

    // Register feature-specific dependencies
    scope.putLazy<UserRepository>(() => UserRepository(db));
    scope.putLazy<UserController>(() => UserController());
  }
}

// Use with any router - it's just a widget!
ZenRoute(
  moduleBuilder: () => UserModule(),
  page: UserPage(),
  scopeName: 'UserScope',
)
```

**Core API:**
- `Zen.put<T>()` - Register dependencies
- `Zen.find<T>()` - Retrieve dependencies
- `Zen.delete<T>()` - Remove dependencies

**What you get:**
- 🏗️ Natural dependency flow (parent → child)
- 🔄 Automatic disposal (no memory leaks)
- 📦 Clean module organization
- 🧪 Easy testing (swap modules)

**Works with:** GoRouter, AutoRoute, Navigator 2.0, any router you like.

[See Hierarchical Scopes Guide →](doc/hierarchical_scopes_guide.md)

### 2. Zero-Boilerplate Reactivity

GetX-inspired reactive system built on Flutter's ValueNotifier. Simple, fast, no magic.

```dart
class TodoController extends ZenController {
  // Reactive primitives
  final todos = <Todo>[].obs();
  final filter = Filter.all.obs();

  // Computed values (auto-update)
  List<Todo> get filteredTodos {
    switch (filter.value) {
      case Filter.active: return todos.where((t) => !t.done).toList();
      case Filter.completed: return todos.where((t) => t.done).toList();
      default: return todos.toList();
    }
  }

  // Actions
  void addTodo(String title) => todos.add(Todo(title));
  void toggleTodo(Todo todo) => todo.done = !todo.done;
}

// In UI - automatic rebuilds
ZenObserver(() => Text('${controller.todos.length} todos'))
ZenObserver(() => ListView.builder(
  itemCount: controller.filteredTodos.length,
  itemBuilder: (context, i) => TodoItem(controller.filteredTodos[i]),
))
```

**What you get:**
- ⚡ Minimal rebuilds (only affected widgets)
- 🎯 Simple API (`.obs()`, `ZenObserver()`, done)
- 🔒 Type-safe (compile-time checks)
- 🏎️ Zero overhead (built on ValueNotifier)

[See Reactive Core Guide →](doc/reactive_core_guide.md)

### 3. Smart Async State (ZenQuery)

React Query patterns built on the reactive system.

```dart
// Define once
final userQuery = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: (_) => api.getUser(123),
  config: ZenQueryConfig(
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(hours: 1),
  ),
);

// Use anywhere - automatic caching, deduplication, refetching
ZenQueryBuilder<User>(
  query: userQuery,
  builder: (context, user) => UserProfile(user),
  loading: () => CircularProgressIndicator(),
  error: (error, retry) => ErrorView(error, onRetry: retry),
);
```

**What you get for free:**
- ✅ Automatic caching with configurable staleness
- ✅ Smart deduplication (same key = one request)
- ✅ Background refetch on focus/reconnect
- ✅ Stale-while-revalidate (show cached, fetch fresh)
- ✅ Request cancellation (no wasted bandwidth)
- ✅ Optimistic updates with rollback
- ✅ Infinite scroll pagination
- ✅ Real-time streams support

**Perfect for:** REST APIs, GraphQL, Firebase, any async data source.

[See ZenQuery Guide →](doc/zen_query_guide.md)

### 4. Offline Synchronization Engine (v1.6.0)

Turn your app into an offline-capable powerhouse with **minimal configuration**.

```dart
// Auto-persist data to disk
final postsQuery = ZenQuery<List<Post>>(
  queryKey: 'posts',
  fetcher: (_) => api.getPosts(),
  config: ZenQueryConfig(
    persist: true, 
    networkMode: NetworkMode.offlineFirst,
  ),
);

// Queue mutations when offline
final createPost = ZenMutation<Post, Post>(
  mutationKey: 'create_post', // Enables queuing
  mutationFn: (post) => api.createPost(post),
);
```

**Key Capabilities:**
- 💾 **Storage Agnostic**: Works with Hive, SharedPreferences, SQLite, etc.
- 🔄 **Mutation Queue**: Actions are queued and auto-replayed when online.
- ⚡ **Optimistic Updates**: Update UI immediately, sync later.
- 🌐 **Network Modes**: Control exactly how queries behave offline.

[See Offline Guide →](doc/offline_guide.md)

---

## 💡 Common Patterns

### Global Services with `.to` Pattern

Access services from anywhere without context or injection:

```dart
class CartService extends ZenService {
  static CartService get to => Zen.find<CartService>();

  final items = <CartItem>[].obs();

  void addToCart(Product product) {
    items.add(CartItem.fromProduct(product));
  }

  @override
  void onClose() {
    // Cleanup happens automatically
    super.onClose();
  }
}

// Register once
void main() {
  Zen.init();
  Zen.put<CartService>(CartService(), isPermanent: true);
  runApp(MyApp());
}

// Use anywhere - widgets, controllers, helpers
CartService.to.addToCart(product);
```

### Infinite Scroll Pagination

```dart
final postsQuery = ZenInfiniteQuery<PostPage>(
  queryKey: ['posts'],
  infiniteFetcher: (cursor, token) => api.getPosts(cursor: cursor),
);

// Auto-load next page when reaching end
if (index == postsQuery.data.length - 1) postsQuery.fetchNextPage();
```

### Optimistic Updates

Mutations provide automatic loading/error states, optimistic UI updates, offline queueing, and cache synchronization. [Learn why mutations are better than direct API calls →](doc/offline_guide.md#35-why-use-mutations-vs-direct-api-calls)

```dart
// ✨ Easy way: Use helpers (recommended)
final createPost = ZenMutation.listPut<Post>(
  queryKey: 'posts',
  mutationFn: (post) => api.createPost(post),
  onError: (err, post) => logger.error('Create failed', err), // Rollback automatic!
);

// Advanced: Manual control for complex scenarios
final mutation = ZenMutation<User, UpdateArgs>(
  onMutate: (args) => userQuery.data.value = args.toUser(),
  onError: (err, args, old) => userQuery.data.value = old, // Manual rollback
);
```

### Real-Time Streams

```dart
final chatQuery = ZenStreamQuery<List<Message>>(
  queryKey: 'chat',
  streamFn: () => chatService.messagesStream,
);
```

[See complete patterns with detailed examples →](doc/real_world_patterns.md)

---

## 🛠️ Advanced Features

- **Effects** - Automatic loading/error/success state management ([guide](doc/effects_usage_guide.md))
- **Computed Values** - Auto-updating derived state with dependency tracking
- **Global Modules** - Register app-wide dependencies at startup
- **Performance Control** - Choose between reactive (`.obs()` + `ZenObserver`) or manual (`update()` + `ZenBuilder`)
- **Workers** - Debounce, throttle, and interval-based reactive handlers
- **Devtools** - Built-in inspector overlay for debugging scopes and queries

[See detailed examples →](doc/real_world_patterns.md)

---

## 🎓 Learning Path

**New to Zenify?** Start here:

1. **5 minutes**: [Counter Example](example/counter) - Basic reactivity
2. **10 minutes**: [Todo Example](example/todo) - CRUD with effects
3. **15 minutes**: [ZenQuery Guide](doc/zen_query_guide.md) - Async state management
4. **20 minutes**: [E-commerce Example](example/ecommerce) - Real-world patterns

**Building something complex?**

- [Hierarchical Scopes Guide](doc/hierarchical_scopes_guide.md) - Advanced DI patterns
- [State Management Patterns](doc/state_management_patterns.md) - Architectural patterns
- [Testing Guide](doc/testing_guide.md) - Unit, widget, and integration tests

---

## 📱 Widget Quick Reference

Choose the right widget for your use case:

| Widget | Use When | Rebuilds On |
|--------|----------|-------------|
| **ZenView** | Building pages with controllers | Automatic lifecycle |
| **ZenRoute** | Need module/scope per route | Route navigation |
| **ZenObserver** | Need reactive updates | Reactive value changes |
| **ZenBuilder** | Need manual control | `controller.update()` call |
| **ZenQueryBuilder** | Fetching API data | Query state changes |
| **ZenStreamQueryBuilder** | Real-time data streams | Stream events |
| **ZenEffectBuilder** | Async operations | Effect state changes |
| **ZenConsumer** | Accessing dependencies | Manual (no auto-rebuild) |

**90% of the time, you'll use:**
- `ZenView` for pages
- `ZenObserver` for reactive UI
- `ZenQueryBuilder` for API calls

---

## 🔧 Configuration

```dart
void main() {
  Zen.init();

  // Optional: Configure logging and performance tracking
  ZenConfig.configure(level: ZenLogLevel.info, performanceTracking: true);

  // Optional: Set global query defaults
  final queryClient = ZenQueryClient(
    defaultOptions: ZenQueryClientOptions(
      queries: ZenQueryConfig(
        staleTime: Duration(minutes: 5),
        cacheTime: Duration(hours: 1),
      ),
    ),
  );
  Zen.put(queryClient);

  runApp(MyApp());
}
```

---

## 🧪 Testing

Built for testing from the ground up with mocking support:

```dart
void main() {
  setUp(() => Zen.testMode().clearQueryCache());
  tearDown(() => Zen.reset());

  test('counter increments', () {
    final controller = CounterController();
    controller.increment();
    expect(controller.count.value, 1);
  });

  test('mock dependencies', () {
    Zen.testMode().mock<ApiClient>(FakeApiClient());
    // Test code uses mock automatically
  });
}
```

[See complete testing guide →](doc/testing_guide.md)

---

## 📚 Complete Documentation

### Core Guides
- [Reactive Core Guide](doc/reactive_core_guide.md) - Reactive values, collections, computed properties
- [ZenQuery Guide](doc/zen_query_guide.md) - Async state, caching, mutations
- [Offline-First Guide](doc/offline_guide.md) - Persistence & Synchronization
- [Effects Guide](doc/effects_usage_guide.md) - Async operations with state management
- [Hierarchical Scopes](doc/hierarchical_scopes_guide.md) - Advanced DI patterns
- [State Management Patterns](doc/state_management_patterns.md) - Architectural patterns
- [Testing Guide](doc/testing_guide.md) - Testing strategies and utilities

### Examples
- [Counter](example/counter) - Simple reactive state
- [Todo App](example/todo) - CRUD operations
- [E-commerce](example/ecommerce) - Real-world patterns
- [Hierarchical Scopes Demo](example/hierarchical_scopes) - Advanced DI
- [ZenQuery Demo](example/zenify_query) - Async state management
- [Offline Demo](example/zen_offline) - Persistence & Queues (New!)
- [Showcase](example/zenify_showcase) - All features

---

## 🙏 Inspired By

Zenify stands on the shoulders of giants:

- **[GetX](https://pub.dev/packages/get)** by Jonny Borges - For intuitive reactive patterns
- **[Riverpod](https://pub.dev/packages/riverpod)** by Remi Rousselet - For hierarchical scoping
- **[React Query](https://tanstack.com/query)** by Tanner Linsley - For smart async state

---

## 💬 Community & Support

- 🐛 **Found a bug?** [Report it](https://github.com/sdegenaar/zenify/issues)
- 💡 **Have an idea?** [Discuss it](https://github.com/sdegenaar/zenify/discussions)
- 📚 **Need help?** Check our [documentation](doc/)

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file

---

## 🚀 Ready to Get Started?

```bash
# Add to pubspec.yaml
flutter pub add zenify

# Try the examples
cd example/counter && flutter run
```

**Choose your path:**
- 👋 New to Zenify? → [5-minute Counter Tutorial](example/counter)
- 🔥 Want async superpowers? → [ZenQuery Guide](doc/zen_query_guide.md)
- 📶 Need offline support? → [Offline Guide](doc/offline_guide.md)
- 🏗️ Building something complex? → [Hierarchical Scopes Guide](doc/hierarchical_scopes_guide.md)
- 🧪 Setting up tests? → [Testing Guide](doc/testing_guide.md)

**Experience the zen of Flutter development.** ✨