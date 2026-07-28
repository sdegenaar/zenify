# ZenQuery Example - Zenify Architecture

This document explains how this example follows Zenify's architectural patterns and best practices.

## Directory Structure

```
lib/
├── main.dart                 # App entry point, module registration, simple navigation
├── models/                   # Data models (User, Post, Comment, etc.)
│   └── models.dart
├── services/                 # Services and API layer
│   └── api_service.dart
├── controllers/              # Business logic controllers
│   └── query_basics_controller.dart (example)
├── modules/                  # Zenify modules for DI
│   └── zen_query_module.dart
└── pages/                    # UI views (widgets)
    ├── query_basics_page.dart
    ├── mutation_page.dart
    ├── infinite_query_page.dart
    ├── stream_query_page.dart
    └── advanced_features_page.dart
```

## Architectural Decisions

### 1. **Main.dart - Simple & Clean** ✅

Following the Zenify pattern from `hierarchical_scopes` and `ecommerce` examples:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Zen
  Zen.init();

  // 2. Configure logging
  ZenConfig.applyEnvironment(ZenEnvironment.development);
  ZenLogger.init(logHandler: ...);

  // 3. Register modules
  await Zen.registerModules([ZenQueryModule()]);

  // 4. Run app
  runApp(const ZenQueryApp());
}
```

**Why StatefulWidget for HomePage?**
- **UI State Only**: `TabController` is pure UI state, not business logic
- **No Business Logic**: HomePage just coordinates navigation
- **Follows Flutter Best Practices**: TabController needs `TickerProviderStateMixin`
- **Clean Separation**: Business logic lives in page-specific controllers

### 2. **Module System** ✅

Modules provide dependency injection and initialization:

```dart
class ZenQueryModule extends ZenModule {
  @override
  String get name => 'ZenQueryModule';

  @override
  Future<void> register(ZenScope scope) async {
    // Register shared services here
    // scope.putLazy(() => ApiService());

    ZenLogger.logInfo('ZenQuery Module registered');
  }

  @override
  List<String> get dependencies => [];
}
```

**Benefits:**
- Centralized dependency management
- Lazy initialization of services
- Dependency ordering
- Clean app initialization

### 3. **Controller Organization** ✅

Controllers are **embedded in page files** for this example. Here's why:

**Current Approach (Embedded):**
```dart
// In mutation_page.dart
class MutationPage extends ZenView<MutationController> { ... }
class MutationController extends ZenController { ... }
```

**Alternative Approach (Separate Files):**
```dart
// In controllers/mutation_controller.dart
class MutationController extends ZenController { ... }

// In pages/mutation_page.dart
import '../controllers/mutation_controller.dart';
class MutationPage extends ZenView<MutationController> { ... }
```

**Why Embedded for This Example:**
1. **Educational Purpose**: Easier to see controller and view together
2. **Page-Specific Logic**: Each controller is only used by one page
3. **Simpler Navigation**: No need to jump between files when learning

**When to Separate:**
- **Shared Controllers**: When multiple views use the same controller
- **Complex Logic**: Controllers with 200+ lines
- **Team Standards**: For larger teams with strict file organization
- **Reusability**: When controllers are tested independently

### 4. **ZenView Pattern** ✅

All pages use `ZenView` for automatic controller lifecycle:

```dart
// Route provides the controller
ZenProvider.create<QueryBasicsController>(
  create: () => QueryBasicsController(),
  child: const QueryBasicsPage(),
)

// The page consumes it
class QueryBasicsPage extends ZenView<QueryBasicsController> {
  const QueryBasicsPage({super.key});

  @override
  Widget build(BuildContext context, QueryBasicsController controller) {
    // Access controller via injected parameter
    return ListView(...);
  }
}
```

**Benefits:**
- Automatic `onInit()` / `onClose()` lifecycle
- Built-in controller disposal
- Type-safe controller access
- Memory leak prevention

### 5. **Services Pattern** 🔧

`ApiService` is a **static utility class** rather than a service:

```dart
class ApiService {
  static Future<User> getUser(int id) async { ... }
  static Future<List<Post>> getPosts(...) async { ... }
}
```

**Why Static?**
- **Stateless**: No instance state to manage
- **Mock API**: Not a real service requiring initialization
- **Simple**: No DI needed for static methods

**For Real Apps:**
```dart
class ApiService extends ZenService {
  late final HttpClient _client;

  @override
  void onInit() {
    _client = HttpClient();
  }

  Future<User> getUser(int id) async { ... }

  @override
  void onClose() {
    _client.close();
  }
}

// In module
scope.putLazy(() => ApiService(), isPermanent: true);
```

## Zenify Patterns Used

### ✅ Reactive State
```dart
final count = 0.obs();
final user = Rx<User?>(null);
```

### ✅ Computed Properties
```dart
late final displayText = computed(() => 'Count: ${count.value}');
```

### ✅ Workers
```dart
ZenWorkers.ever(observable, (value) { ... });
ZenWorkers.debounce(observable, callback, duration);
ZenWorkers.interval(ticker, callback, duration);
```

### ✅ Queries & Mutations
```dart
final userQuery = ZenQuery<User>(
  queryKey: 'user:1',
  fetcher: (token) => api.getUser(1),
);

final updateMutation = ZenMutation<Post, UpdateRequest>(
  mutationFn: (request) => api.updatePost(request),
  onMutate: (request) { /* optimistic update */ },
  onSuccess: (data, vars, context) { /* update cache */ },
);
```

### ✅ Lifecycle Management
```dart
class MyController extends ZenController {
  @override
  void onInit() {
    super.onInit();
    // Initialize resources
  }

  @override
  void onClose() {
    // Clean up resources
    super.onClose();
  }
}
```

## Best Practices Applied

1. ✅ **Module system for app initialization**
2. ✅ **Proper logging configuration**
3. ✅ **ZenView for automatic lifecycle**
4. ✅ **Controllers manage business logic**
5. ✅ **Views are pure presentation**
6. ✅ **Services for shared stateful resources**
7. ✅ **Static utilities for stateless helpers**
8. ✅ **Clean disposal in onClose()**
9. ✅ **Type-safe reactive state**
10. ✅ **Proper error handling**

## Comparison with Other Examples

### Counter Example
- **Simpler**: No modules, single controller
- **Educational**: Shows all features in one file
- **Use Case**: Learning Zenify basics

### Hierarchical Scopes Example
- **Complex**: Multiple scopes, parent-child relationships
- **Modules**: AppModule with shared services
- **Routes**: ZenRoute for scope management
- **Use Case**: Enterprise apps with feature isolation

### This (ZenQuery) Example
- **Medium Complexity**: Module system, multiple pages
- **Focus**: ZenQuery features (queries, mutations, streams)
- **Organization**: Page-based with embedded controllers
- **Use Case**: Learning async state management patterns

## When to Extract Controllers

**Keep Embedded When:**
- Controller is page-specific
- < 150 lines of code
- Only one view uses it
- Educational/example code

**Extract to `controllers/` When:**
- Shared between multiple views
- \> 200 lines of code
- Need independent unit testing
- Team convention requires it
- Building a library/package

## Summary

This example demonstrates **pragmatic Zenify architecture**:

1. ✅ **Modules** for app-level setup
2. ✅ **StatefulWidget** for pure UI state (TabController)
3. ✅ **ZenView + Controllers** for business logic
4. ✅ **Embedded controllers** for simplicity (valid pattern)
5. ✅ **Static services** for stateless utilities
6. ✅ **Proper logging** and configuration

The architecture is **production-ready** while remaining **easy to understand** for developers learning ZenQuery.
