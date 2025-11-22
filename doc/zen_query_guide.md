
# ZenQuery Guide

**Production-ready async state management for Flutter**

ZenQuery brings React Query/TanStack Query patterns to Flutter with a clean, intuitive API. It handles caching, deduplication, retries, and background refetching automatically.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core Concepts](#core-concepts)
3. [Configuration](#configuration)
4. [Mutations](#mutations)
5. [Advanced Features](#advanced-features)
6. [Best Practices](#best-practices)
7. [API Reference](#api-reference)
8. [Scope Integration](#scope-integration)
9. [Examples](#examples)
10. [Troubleshooting](#troubleshooting)
11. [Performance Tips](#performance-tips)
12. [Migration Guide](#migration-guide)

---

## Quick Start

### Basic Query
```dart
// Create a query
final userQuery = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: () => api.getUser(123),
);

// Use in widget
ZenQueryBuilder<User>(
  query: userQuery,
  builder: (context, user) => Text(user.name),
  loading: () => CircularProgressIndicator(),
  error: (error, retry) => ErrorWidget(error: error, onRetry: retry),
);
```

### With Configuration
```dart
final userQuery = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: () => api.getUser(123),
  config: ZenQueryConfig(
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(hours: 1),
    retryCount: 3,
  ),
);
``` 

---

## Core Concepts

### Query Keys

Query keys uniquely identify queries and enable:
- **Deduplication**: Same key = same request
- **Cache management**: Invalidate by key or pattern
- **Debugging**: Track queries by identifier
```dart
// Simple key
queryKey: 'users'

// Parameterized key
queryKey: 'user:$userId'

// Hierarchical key
queryKey: 'users:$userId:posts:$postId'
```

### Query States

Queries have four states:
```dart
enum ZenQueryStatus {
  idle,    // Not fetched yet
  loading, // Currently fetching
  success, // Successfully fetched
  error,   // Failed to fetch
}
``` 

### Stale While Revalidate (SWR)

Show cached data immediately while fetching fresh data in the background:
```dart
ZenQueryBuilder<User>(
  query: userQuery,
  showStaleData: true, // Default: true
  builder: (context, data) => UserProfile(data),
);
```

---

## Configuration

### Global Defaults

Set defaults for all queries:
```dart
// Define custom defaults
const myDefaults = ZenQueryConfig(
  staleTime: Duration(minutes: 5),
  cacheTime: Duration(hours: 1),
  retryCount: 3,
);

// Use in queries
final query = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: () => api.getUser(123),
  config: myDefaults,
);
``` 

### Per-Query Configuration
```dart
final query = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: () => api.getUser(123),
  config: ZenQueryConfig(
    // Cache configuration
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(hours: 1),

    // Refetch behavior
    refetchOnMount: true,
    refetchOnFocus: false,
    refetchOnReconnect: true,
    refetchInterval: Duration(minutes: 10),
    enableBackgroundRefetch: true,

    // Error handling
    retryCount: 3,
    retryDelay: Duration(seconds: 1),
    exponentialBackoff: true,
  ),
);
```

### Configuration Options Explained

| Option | Default | Description |
|--------|---------|-------------|
| `staleTime` | 30s | How long data is considered fresh |
| `cacheTime` | 5min | How long unused data stays in cache |
| `refetchOnMount` | true | Refetch when component mounts |
| `refetchOnFocus` | false | Refetch when window gains focus |
| `refetchOnReconnect` | true | Refetch on network reconnect |
| `refetchInterval` | null | Background refetch interval |
| `enableBackgroundRefetch` | false | Enable automatic background refetching |
| `retryCount` | 3 | Number of retry attempts |
| `retryDelay` | 1s | Base delay between retries |
| `exponentialBackoff` | true | Increase delay exponentially |

---

## Mutations

While `ZenQuery` handles fetching data (reads), `ZenMutation` handles changing data (writes).

```dart
final loginMutation = ZenMutation<User, LoginArgs>(
  mutationFn: (args) => api.login(args.username, args.password),
  onSuccess: (user, args) {
    // Navigate or show success
  },
  onError: (error, args) {
    // Show error snackbar
  }
);

// Trigger
loginMutation.mutate(LoginArgs('user', 'pass'));
```

### Reactive State
Mutations provide reactive state for your UI:
```dart
Obx(() {
  if (mutation.isLoading.value) return CircularProgressIndicator();
  return ElevatedButton(onPressed: () => mutation.mutate(args), ...);
})
```

### Side Effects & Invalidation
The power of mutations comes from `onSettled`, which runs after success or error. Use it to invalidate queries so they automatically refetch fresh data.

```dart
final addPostMutation = ZenMutation<Post, String>(
  mutationFn: (content) => api.createPost(content),
  onSettled: (_, __, ___) {
    // Mark 'posts' as stale. Any active UI showing posts will immediately refetch.
    ZenQueryCache.instance.invalidateQuery('posts');
  }
);
```

---

## Advanced Features

### Optimistic Updates

Update UI instantly, rollback on error:
```dart
void updateUser(User newUser) {
  // Save current data for rollback
  final previousUser = userQuery.data.value;

  // Optimistic update
  userQuery.setData(newUser);

  // Perform actual update
  api.updateUser(newUser).catchError((error) {
    // Rollback on error
    if (previousUser != null) {
      userQuery.setData(previousUser);
    }
  });
}
``` 

### Cache Invalidation

Mark data as stale to trigger refetch:
```dart
// Invalidate single query
ZenQueryCache.instance.invalidateQuery('user:123');

// Invalidate by prefix (all user queries)
ZenQueryCache.instance.invalidateQueriesWithPrefix('user:');

// Invalidate with custom predicate
ZenQueryCache.instance.invalidateQueries((key) => key.contains('posts'));

// Invalidate specific query
userQuery.invalidate();
```

### Manual Refetching

Force refresh regardless of stale state:
```dart
// Refetch single query
await userQuery.refetch();

// Refetch multiple queries
await ZenQueryCache.instance.refetchQueries((key) => key.startsWith('user:'));

``` 

### Query Deduplication

Automatic - concurrent requests with the same key share a single fetch:
```dart
// All three will trigger only ONE API call
final future1 = userQuery.fetch();
final future2 = userQuery.fetch();
final future3 = userQuery.fetch();

await Future.wait([future1, future2, future3]);
// ✅ Single request, three listeners
```

### Initial Data

Provide initial data to avoid loading state:
```dart
final userQuery = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: () => api.getUser(123),
  initialData: User(id: 123, name: 'Loading...'),
);

// Widget shows initial data immediately, then updates when fetched
``` 

### Background Refetching

Keep data fresh automatically:
```dart
final liveDataQuery = ZenQuery<StockPrice>(
  queryKey: 'stock:AAPL',
  fetcher: () => api.getStockPrice('AAPL'),
  config: ZenQueryConfig(
    refetchInterval: Duration(seconds: 30),
    enableBackgroundRefetch: true,
  ),
);
```

---

## Best Practices

### 1. Use Hierarchical Keys

Organize keys in a hierarchy for easier invalidation:
```dart
// Good ✅
'users'
'users:123'
'users:123:posts'
'users:123:posts:456'

// Can invalidate all user 123 data:
ZenQueryCache.instance.invalidateQueriesWithPrefix('users:123:');
``` 

### 2. Set Appropriate Stale Times

Balance freshness vs performance:
```dart
// Real-time data (stock prices, chat messages)
staleTime: Duration(seconds: 5)

// Frequently updated (notifications, feed)
staleTime: Duration(seconds: 30)

// Stable data (user profile, settings)
staleTime: Duration(minutes: 5)

// Rarely changes (terms of service, config)
staleTime: Duration(hours: 1)
```

### 3. Register Queries in Modules (Recommended)

Make queries accessible and auto-disposable:
```dart
class UserModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // ✅ Recommended: Scoped query with auto-disposal
    scope.putQuery<User>(
      queryKey: 'user:$currentUserId',
      fetcher: () => api.getUser(currentUserId),
    );
  }
}

// Access in widgets via ZenView or Zen.find
final userQuery = Zen.find<ZenQuery<User>>();
``` 

### 4. Handle Loading States Gracefully

Show stale data during refetch:
```dart
ZenQueryBuilder<User>(
  query: userQuery,
  showStaleData: true,
  builder: (context, data) => UserProfile(data),
  loading: () => CircularProgressIndicator(),
);
```

### 5. Dispose Queries Properly

ZenQuery extends ZenController, so it manages its lifecycle automatically when used with dependency injection. Manual disposal is only needed if you create queries outside of the DI system:
```dart
// If created manually, dispose when done
final query = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: () => api.getUser(123),
);

// Later...
query.dispose();
``` 

---

## API Reference

### ZenQuery

#### Constructor
```dart
ZenQuery<T>({
  required String queryKey,
  required Future<T> Function() fetcher,
  ZenQueryConfig? config,
  T? initialData,
  ZenScope? scope,
  bool autoDispose = true,
})
```

#### Properties

- `queryKey`: Unique identifier for the query
- `status`: Current query status (idle, loading, success, error)
- `data`: Current data value
- `error`: Current error value
- `isLoading`: Whether query is currently loading
- `hasData`: Whether query has data
- `hasError`: Whether query has an error
- `isStale`: Whether data needs refetching
- `isRefetching`: Whether query is refetching while having data

#### Methods

- `fetch({bool force = false})`: Fetch data (returns cached if available)
- `refetch()`: Force refetch regardless of cache
- `setData(T newData)`: Manually update data (for optimistic updates)
- `invalidate()`: Mark data as stale
- `reset()`: Reset to initial state

### ZenMutation

#### Constructor
```dart
ZenMutation<TData, TVariables>({
  required Future<TData> Function(TVariables) mutationFn,
  FutureOr<void> Function(TVariables)? onMutate,
  void Function(TData, TVariables)? onSuccess,
  void Function(Object, TVariables)? onError,
  void Function(TData?, Object?, TVariables)? onSettled,
})
```

#### Properties
- `mutate(variables)`: Triggers the mutation
- `isLoading`: Reactive boolean
- `isSuccess`: Boolean status check
- `isError`: Boolean status check
- `data`: The result data (Rx)
- `error`: The error object (Rx)

### ZenQueryBuilder
```dart
ZenQueryBuilder<T>({
  required ZenQuery<T> query,
  required Widget Function(BuildContext, T) builder,
  Widget Function()? loading,
  Widget Function(Object, VoidCallback)? error,
  Widget Function()? idle,
  bool autoFetch = true,
  bool showStaleData = true,
  Widget Function(BuildContext, Widget)? wrapper,
})
``` 

### ZenQueryCache

Singleton for managing multiple queries:
```dart
// Get cache instance
ZenQueryCache.instance

// Invalidate queries
invalidateQuery(String key)
invalidateQueriesWithPrefix(String prefix)
invalidateQueries(bool Function(String) predicate)

// Refetch queries
refetchQueries(bool Function(String) predicate)

// Scope operations
invalidateScope(String scopeId)
refetchScope(String scopeId)
clearScope(String scopeId)
getScopeQueries(String scopeId)
getScopeStats(String scopeId)

// Get query
getQuery<T>(String key)

// Clear cache
clear()

// Get statistics
getStats()

```

---

## Scope Integration

### Overview

ZenQuery supports both **global** and **scoped** modes for flexible lifecycle management:

- **Global queries**: Persist across navigation, ideal for app-wide data
- **Scoped queries**: Auto-dispose with their scope, perfect for feature-specific data

### Global Queries (Default)
```dart
// Get cache instance
ZenQueryCache.instance

// Invalidate queries
invalidateQuery(String key)
invalidateQueriesWithPrefix(String prefix)
invalidateQueries(bool Function(String) predicate)

// Refetch queries
refetchQueries(bool Function(String) predicate)

// Scope operations
invalidateScope(String scopeId)
refetchScope(String scopeId)
clearScope(String scopeId)
getScopeQueries(String scopeId)
getScopeStats(String scopeId)

// Get query
getQuery<T>(String key)

// Clear cache
clear()

// Get statistics
getStats()

``` 

### Scoped Queries (Recommended Pattern)
```dart
class ProductModule extends ZenModule {
  final String productId;

  ProductModule(this.productId);

  @override
  void register(ZenScope scope) {
    // ✅ Recommended: Use putQuery for scoped queries
    scope.putQuery<Product>(
      queryKey: 'product:$productId',
      fetcher: () => api.getProduct(productId),
      config: ZenQueryConfig(staleTime: Duration(minutes: 5)),
    );

    scope.putQuery<List<Review>>(
      queryKey: 'reviews:$productId',
      fetcher: () => api.getReviews(productId),
    );
  }
}

// Queries auto-dispose when route is popped
ZenRoute(
  moduleBuilder: () => ProductModule(productId),
  page: ProductDetailPage(),
  scopeName: 'ProductScope',
);

```

### Manual Scoped Queries (Alternative)
```dart
// Still valid if you need more control
final query = ZenQuery<Product>(
  queryKey: 'product:$productId',
  fetcher: () => api.getProduct(productId),
  scope: scope,
  autoDispose: false, // Custom lifecycle control
);
scope.put(query);
``` 

### Use Cases

#### Feature-Specific Data (Scoped)
```dart
class ProductDetailModule extends ZenModule {
  final String productId;

  ProductDetailModule(this.productId);

  @override
  void register(ZenScope scope) {
    // Product data - scope-specific
    scope.putQuery<Product>(
      queryKey: 'product:$productId',
      fetcher: () => api.getProduct(productId),
    );

    // Reviews - scope-specific
    scope.putQuery<List<Review>>(
      queryKey: 'reviews:$productId',
      fetcher: () => api.getReviews(productId),
    );
  }
}

// Queries auto-dispose when route is popped
ZenRoute(
  moduleBuilder: () => ProductDetailModule(productId),
  page: ProductDetailPage(),
  scopeName: 'ProductScope',
);

```

#### Within Controller Creation
```dart
class ProductController extends ZenController {
  final String productId;

  ProductController(this.productId);

  late final productQuery = ZenQuery<Product>(
    queryKey: 'product:$productId',
    fetcher: () => api.getProduct(productId),
    scope: Zen.currentScope, // ← Implicit scope
  );
}
``` 

#### App-Wide Data (Global)
```dart
class AppModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // User data - global, persists across navigation
    final userQuery = ZenQuery<User>(
      queryKey: 'currentUser',
      fetcher: () => api.getCurrentUser(),
      // No scope parameter = global
    );

    scope.put(userQuery, isPermanent: true);
  }
}
```

### When to Use Each Pattern

**Use Global Queries When:**
- Data is app-wide (user profile, settings)
- Data persists across navigation
- Multiple features access the same data

**Use Scoped Queries When:**
- Data is feature-specific (product details, post comments)
- Data should clear on navigation away
- Module/feature has dedicated queries

**Quick Decision Tree:**
1. Does this data survive navigation? → Global
2. Is this data shared across features? → Global
3. Is this data feature-specific? → Scoped
4. Should this clear when leaving the page? → Scoped

### Scope Operations

#### Invalidate All Queries in Scope
```dart
// Invalidate all queries in a scope (marks as stale)
ZenQueryCache.instance.invalidateScope(scope.id);
``` 

#### Refetch All Queries in Scope
```dart
// Refetch all queries in a scope
await ZenQueryCache.instance.refetchScope(scope.id);
```

#### Clear Scope Cache
```dart
// Remove all queries from a scope
ZenQueryCache.instance.clearScope(scope.id);
``` 

#### Get Scope Statistics
```dart
final stats = ZenQueryCache.instance.getScopeStats(scope.id);
print('Total queries: ${stats['total']}');
print('Loading: ${stats['loading']}');
print('Success: ${stats['success']}');
print('Error: ${stats['error']}');
print('Stale: ${stats['stale']}');
```

### Best Practices for Scoped Queries

1. **Use scoped queries for feature data** - Auto-cleanup prevents memory leaks
2. **Use global queries for shared data** - User profile, app config, etc.
3. **Use `putQuery` in modules** - Simplest and most consistent pattern
4. **Set `autoDispose: true` for temporary data** - Reviews, comments, etc. (default)
5. **Set `autoDispose: false` for persistent cache** - Keep data even after scope disposal
6. **Invalidate scope on data mutations** - Keep related queries in sync

#### Example: E-commerce Product Page
```dart
class ProductPageModule extends ZenModule {
  final String productId;

  ProductPageModule(this.productId);

  @override
  void register(ZenScope scope) {
    // All product-related queries tied to this scope
    scope.putQuery<Product>(
      queryKey: 'product:$productId',
      fetcher: () => api.getProduct(productId),
    );

    scope.putQuery<List<Review>>(
      queryKey: 'reviews:$productId',
      fetcher: () => api.getReviews(productId),
    );

    scope.putQuery<List<Product>>(
      queryKey: 'related:$productId',
      fetcher: () => api.getRelatedProducts(productId),
    );

    // Controller for this page
    scope.putLazy(() => ProductPageController());
  }
}

// Route with automatic cleanup
ZenRoute(
  moduleBuilder: () => ProductPageModule(productId),
  page: ProductDetailPage(),
  scopeName: 'ProductScope',
);

// When user navigates away:
// ✅ All queries auto-dispose
// ✅ Controller auto-disposes
// ✅ Scope cleans up
// ✅ No memory leaks!

``` 

### Benefits

- ✅ **Automatic cleanup** - No manual disposal needed
- ✅ **Cache isolation** - Different features don't interfere
- ✅ **Memory efficient** - Data removed when not needed
- ✅ **Flexible** - Choose global or scoped based on use case
- ✅ **Testable** - Easy to mock and isolate for testing

---

## Examples

### Pagination
```dart
class PostsQuery extends ZenQuery<List<Post>> {
  final int page;

  PostsQuery(this.page) : super(
    queryKey: 'posts:page:$page',
    fetcher: () => api.getPosts(page),
    config: ZenQueryConfig(
      staleTime: Duration(minutes: 5),
    ),
  );
}

// Use in widget
ZenQueryBuilder<List<Post>>(
  query: PostsQuery(currentPage),
  builder: (context, posts) => PostsList(posts),
);
```

### Dependent Queries
```dart
// First query: Get user
final userQuery = ZenQuery<User>(
  queryKey: 'user:$userId',
  fetcher: () => api.getUser(userId),
);

// Second query: Get user's posts (depends on user data)
final postsQuery = ZenQuery<List<Post>>(
  queryKey: 'posts:user:$userId',
  fetcher: () async {
    final user = await userQuery.fetch();
    return api.getUserPosts(user.id);
  },
);
``` 

### Mutations with Optimistic Updates

Use `ZenMutation` for create/update/delete operations. This separates "reads" from "writes" and provides cleaner lifecycle hooks.

```dart
class TodoController extends ZenController {
   // Define the mutation
   late final toggleMutation = ZenMutation<Todo, Todo>(
     mutationFn: (todo) => api.toggleTodo(todo.id),
 
     // 1. Optimistic Update: Update UI before server responds
     onMutate: (todo) async {
        // Cancel any outgoing refetches so they don't overwrite our optimistic update
        // (Not implemented yet, but good practice in future)
    
        // Update the cache immediately
        final todosQuery = Zen.find<ZenQuery<List<Todo>>>();
        final currentList = todosQuery.data.value ?? [];
    
        final optimisticList = currentList.map((t) {
           return t.id == todo.id ? t.copyWith(completed: !t.completed) : t;
        }).toList();
    
        todosQuery.setData(optimisticList);
     },
 
     // 2. On Error: Rollback automatically? 
     // (Currently you must implement rollback logic manually in onError if complex)
     onError: (error, todo) {
        ZenLogger.logError('Failed to toggle todo', error);
        // Trigger a refetch to ensure consistency
        ZenQueryCache.instance.invalidateQuery('todos'); 
     },

     // 3. On Settled: Always refetch to ensure server consistency
     onSettled: (data, error, todo) {
        ZenQueryCache.instance.invalidateQuery('todos');
     }
   );

   // Use it
   void toggle(Todo todo) {
     toggleMutation.mutate(todo);
   }
}
```

Bind to UI easily:
```dart
Obx(() => MyButton(
  isLoading: controller.toggleMutation.isLoading.value,
  onPressed: () => controller.toggle(item),
));
```

---

## Troubleshooting

### Query not refetching

Check if data is marked as stale:
```dart
print(query.isStale); // Should be true for refetch

// Force invalidation
query.invalidate();
``` 

### Memory leaks

Ensure queries are disposed properly:
```dart
// When using manually created queries
@override
void dispose() {
  myQuery.dispose();
  super.dispose();
}
```

### Concurrent request issues

ZenQuery automatically deduplicates requests with the same key. If you need separate instances, use different keys:
```dart
// These will be treated as different queries
final query1 = ZenQuery(queryKey: 'user:123:v1', ...);
final query2 = ZenQuery(queryKey: 'user:123:v2', ...);

``` 

---

## Performance Tips

1. **Set appropriate stale times**: Longer stale times reduce network requests
2. **Use query key prefixes**: Enable batch invalidation
3. **Enable background refetch for critical data**: Keep data fresh without user action
4. **Use initial data**: Avoid loading states for cached data
5. **Implement optimistic updates**: Improve perceived performance
6. **Use scoped queries**: Automatic cleanup prevents memory accumulation

---

## Migration Guide

### From Provider
```dart
// Before (Provider)
class UserProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  Future<void> fetchUser(String id) async {
    _isLoading = true;
    notifyListeners();

    _user = await api.getUser(id);
    _isLoading = false;
    notifyListeners();
  }
}

// After (ZenQuery)
final userQuery = ZenQuery<User>(
  queryKey: 'user:$id',
  fetcher: () => api.getUser(id),
);
```

### From BLoC
```dart
// Before (BLoC)
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserInitial()) {
    on<FetchUser>((event, emit) async {
      emit(UserLoading());
      try {
        final user = await api.getUser(event.id);
        emit(UserLoaded(user));
      } catch (e) {
        emit(UserError(e));
      }
    });
  }
}

// After (ZenQuery)
final userQuery = ZenQuery<User>(
  queryKey: 'user:$id',
  fetcher: () => api.getUser(id),
);
``` 

---

## Summary

**ZenQuery provides:**
- ✅ Automatic caching and deduplication
- ✅ Smart background refetching
- ✅ Built-in retry logic with exponential backoff
- ✅ Optimistic updates with rollback
- ✅ Scope-aware lifecycle management
- ✅ SWR (Stale-While-Revalidate) pattern
- ✅ Zero boilerplate for common patterns

**Perfect for:** REST APIs, GraphQL queries, pagination, infinite scroll, and real-time data feeds.

Ready to simplify your async state management? Start with the [Quick Start](#quick-start) section!