# Zenify

[![pub package](https://img.shields.io/pub/v/zenify.svg)](https://pub.dev/packages/zenify)
[![likes](https://img.shields.io/pub/likes/zenify?logo=dart)](https://pub.dev/packages/zenify/score)
[![pub points](https://img.shields.io/pub/points/zenify?logo=dart)](https://pub.dev/packages/zenify/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Modern Flutter state management** that combines React Query's async superpowers, Riverpod's hierarchical DI, and GetX's simplicity—all in one elegant package.

```dart
// Smart caching, auto-refetch, zero boilerplate
final userQuery = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: (_) => api.getUser(123),
);

// That's it. Caching, loading states, error handling—all handled.
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

### 🔥 React Query Style
A native-inspired implementation of **TanStack Query patterns**: automatic caching, smart refetching, request deduplication, and stale-while-revalidate—seamlessly integrated with your UI.

### 🏗️ Hierarchical Scoped Architecture
Riverpod-inspired scoping with **automatic cleanup**. Dependencies flow naturally from parent to child, and scopes dispose themselves automatically when no longer needed.

### 🎯 Zero Boilerplate
GetX-like reactivity with `.obs()` and `Obx()`. Write less, accomplish more, keep your code clean.

---

## 🚀 Quick Start (30 seconds)

### 1. Install

```yaml
dependencies:
  zenify: ^1.2.1
```

### 2. Initialize

```dart
void main() {
  Zen.init();
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
  CounterController createController() => CounterController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Obx(() => Text('Count: ${controller.count.value}')),
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

[See complete example →](example/counter)

---

## 🔥 Core Features

### 1. Smart Async State (ZenQuery)

The killer feature. React Query patterns for Flutter.

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

### 2. Hierarchical DI with Auto-Cleanup

Organize dependencies naturally with parent-child scopes. When you navigate away, everything cleans up automatically.

```dart
// App-level services (persistent)
class AppModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<AuthService>(AuthService(), isPermanent: true);
    scope.put<DatabaseService>(DatabaseService(), isPermanent: true);
  }
}

// Feature-level services (auto-disposed)
class UserModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // Access parent services
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

**What you get:**
- 🏗️ Natural dependency flow (parent → child)
- 🔄 Automatic disposal (no memory leaks)
- 📦 Clean module organization
- 🧪 Easy testing (swap modules)

**Works with:** GoRouter, AutoRoute, Navigator 2.0, any router you like.

[See Hierarchical Scopes Guide →](doc/hierarchical_scopes_guide.md)

### 3. Zero-Boilerplate Reactivity

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
Obx(() => Text('${controller.todos.length} todos'))
Obx(() => ListView.builder(
  itemCount: controller.filteredTodos.length,
  itemBuilder: (context, i) => TodoItem(controller.filteredTodos[i]),
))
```

**What you get:**
- ⚡ Minimal rebuilds (only affected widgets)
- 🎯 Simple API (`.obs()`, `Obx()`, done)
- 🔒 Type-safe (compile-time checks)
- 🏎️ Zero overhead (built on ValueNotifier)

[See Reactive Core Guide →](doc/reactive_core_guide.md)

---

## 💡 Real-World Examples

### Infinite Scroll with Pagination

```dart
final postsQuery = ZenInfiniteQuery<PostPage>(
  queryKey: ['posts', 'feed'],
  infiniteFetcher: (cursor, token) => api.getPosts(cursor: cursor),
  getNextPageParam: (lastPage) => lastPage.nextCursor,
);

// In UI
ListView.builder(
  itemCount: postsQuery.data.length,
  itemBuilder: (context, index) {
    if (index == postsQuery.data.length - 1) {
      postsQuery.fetchNextPage(); // Load more
    }
    return PostCard(postsQuery.data[index]);
  },
)
```

### Mutations with Optimistic Updates

```dart
final updateUserMutation = ZenMutation<User, UpdateUserArgs>(
  mutationFn: (args) => api.updateUser(args),
  onMutate: (args) {
    // Optimistic update
    final oldUser = userQuery.data.value;
    userQuery.data.value = args.toUser();
    return oldUser; // Context for rollback
  },
  onError: (error, args, context) {
    // Rollback on error
    userQuery.data.value = context as User;
    showError('Update failed');
  },
  onSettled: () {
    // Refresh query
    userQuery.refetch();
  },
);

// Trigger
updateUserMutation.mutate(UpdateUserArgs(name: 'New Name'));
```

### Real-Time Data Streams

```dart
final chatQuery = ZenStreamQuery<List<Message>>(
  queryKey: 'chat-messages',
  streamFn: () => chatService.messagesStream,
);

ZenStreamQueryBuilder<List<Message>>(
  query: chatQuery,
  builder: (context, messages) => ChatList(messages),
  loading: () => LoadingSpinner(),
  error: (error) => ErrorView(error),
);
```

---

## 🛠️ Advanced Features

### Effects for Async Operations

Automatic state management for loading/error/success.

```dart
class UserController extends ZenController {
  late final userEffect = createEffect<User>(name: 'loadUser');

  Future<void> loadUser(String id) async {
    await userEffect.run(() => api.getUser(id));
  }
}

// In UI - automatic state handling
ZenEffectBuilder<User>(
  effect: controller.userEffect,
  onLoading: () => LoadingSpinner(),
  onSuccess: (user) => UserProfile(user),
  onError: (error) => ErrorMessage(error),
)
```

[See Effects Guide →](doc/effects_usage_guide.md)

### Computed Values with Dependency Tracking

```dart
class ShoppingController extends ZenController {
  final items = <CartItem>[].obs();
  final discount = 0.0.obs();

  late final subtotal = computed(() =>
    items.fold(0.0, (sum, item) => sum + item.price)
  );

  late final total = computed(() =>
    subtotal.value * (1 - discount.value)
  );
}

// Automatic updates when items or discount change
Obx(() => Text('Total: \$${controller.total.value}'))
```

### Global Module Registration

Set up your entire app architecture at startup.

```dart
void main() async {
  Zen.init();

  // Register app-wide modules
  await Zen.registerModules([
    CoreModule(),     // Database, logging, storage
    NetworkModule(),  // API clients, connectivity
    AuthModule(),     // Authentication
  ]);

  runApp(MyApp());
}
```

### Performance Control

Fine-grained rebuild control when you need it.

```dart
class DashboardController extends ZenController {
  final stats = <Stat>[].obs();
  final isLoading = false.obs();

  void updateStats() {
    // Only rebuild specific widgets
    update(['stats-widget']);
  }
}

// In UI
ZenBuilder<DashboardController>(
  id: 'stats-widget',
  builder: (context, controller) => StatsChart(controller.stats),
)
```

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
| **Obx** | Need reactive updates | Reactive value changes |
| **ZenBuilder** | Need manual control | `controller.update()` call |
| **ZenQueryBuilder** | Fetching API data | Query state changes |
| **ZenStreamQueryBuilder** | Real-time data streams | Stream events |
| **ZenEffectBuilder** | Async operations | Effect state changes |
| **ZenConsumer** | Accessing dependencies | Manual (no auto-rebuild) |

**90% of the time, you'll use:**
- `ZenView` for pages
- `Obx` for reactive UI
- `ZenQueryBuilder` for API calls

---

## 🔧 Configuration

### Basic Setup

```dart
void main() {
  Zen.init();

  // Environment-based config
  if (kReleaseMode) {
    ZenConfig.applyEnvironment(ZenEnvironment.production);
  } else {
    ZenConfig.applyEnvironment(ZenEnvironment.development);
  }

  runApp(MyApp());
}
```

### Custom Configuration

```dart
ZenConfig.configure(
  level: ZenLogLevel.info,
  performanceTracking: true,
);
```

### Query Defaults

```dart
final customDefaults = ZenQueryConfig(
  staleTime: Duration(minutes: 5),
  cacheTime: Duration(hours: 1),
  retryCount: 3,
  refetchOnFocus: true,
  refetchOnReconnect: true,
);
```

---

## 🧪 Testing

Zenify is built for testing from the ground up.

```dart
void main() {
  setUp(() {
    Zen.testMode();
    Zen.clearQueryCache();
  });

  tearDown(() {
    Zen.reset();
  });

  test('counter increments', () {
    final controller = CounterController();
    expect(controller.count.value, 0);

    controller.increment();
    expect(controller.count.value, 1);

    controller.dispose();
  });
}
```

**Mock dependencies easily:**

```dart
test('user service test', () {
  Zen.testMode()
    .mock<ApiClient>(FakeApiClient())
    .mock<AuthService>(FakeAuthService());

  final userService = UserService();
  final user = await userService.getCurrentUser();

  expect(user.name, 'Test User');
});
```

[See Testing Guide →](doc/testing_guide.md)

---

## 📚 Complete Documentation

### Core Guides
- [Reactive Core Guide](doc/reactive_core_guide.md) - Reactive values, collections, computed properties
- [ZenQuery Guide](doc/zen_query_guide.md) - Async state, caching, mutations
- [Effects Guide](doc/effects_usage_guide.md) - Async operations with state management
- [Hierarchical Scopes](doc/hierarchical_scopes_guide.md) - Advanced DI patterns
- [State Management Patterns](doc/state_management_patterns.md) - Architectural patterns
- [Testing Guide](doc/testing_guide.md) - Testing strategies and utilities

### Examples
- [Counter](example/counter) - Simple reactive state
- [Todo App](example/todo) - CRUD operations
- [E-commerce](example/ecommerce) - Real-world patterns
- [Hierarchical Scopes Demo](example/hierarchical_scopes) - Advanced DI
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
- 🏗️ Building something complex? → [Hierarchical Scopes Guide](doc/hierarchical_scopes_guide.md)
- 🧪 Setting up tests? → [Testing Guide](doc/testing_guide.md)

**Experience the zen of Flutter development.** ✨