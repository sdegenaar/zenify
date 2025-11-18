# ZenQuery Guide

**Production-ready async state management for Flutter**

ZenQuery brings React Query/TanStack Query patterns to Flutter with a clean, intuitive API. It handles caching, deduplication, retries, and background refetching automatically.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core Concepts](#core-concepts)
3. [Configuration](#configuration)
4. [Advanced Features](#advanced-features)
5. [Best Practices](#best-practices)
6. [API Reference](#api-reference)

---

## Quick Start

### Basic Query
```
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
```
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

```
// Simple key
queryKey: 'users'

// Parameterized key
queryKey: 'user:$userId'

// Hierarchical key
queryKey: 'users:$userId:posts:$postId'
```

### Query States

Queries have four states:
```
enum ZenQueryStatus {
  idle,    // Not fetched yet
  loading, // Currently fetching
  success, // Successfully fetched
  error,   // Failed to fetch
}
```

### Stale While Revalidate (SWR)

Show cached data immediately while fetching fresh data in the background
```
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
```
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

### ### Per-Query Configuration
```
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

## Advanced Features

### Optimistic Updates

Update UI instantly, rollback on error:
```
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
```
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
```
// Refetch single query
await userQuery.refetch();

// Refetch multiple queries
await ZenQueryCache.instance.refetchQueries((key) => key.startsWith('user:'));
```

### Query Deduplication

Automatic - concurrent requests with the same key share a single fetch:
```
// All three will trigger only ONE API call
final future1 = userQuery.fetch();
final future2 = userQuery.fetch();
final future3 = userQuery.fetch();

await Future.wait([future1, future2, future3]);
// ✅ Single request, three listeners
```

### Initial Data

Provide initial data to avoid loading state:
```
final userQuery = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: () => api.getUser(123),
  initialData: User(id: 123, name: 'Loading...'),
);

// Widget shows initial data immediately, then updates when fetched
```

### Background Refetching

Keep data fresh automatically:
```
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
```
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
```
// Real-time data (stock prices, chat messages)
staleTime: Duration(seconds: 5)

// Frequently updated (notifications, feed)
staleTime: Duration(seconds: 30)

// Stable data (user profile, settings)
staleTime: Duration(minutes: 5)

// Rarely changes (terms of service, config)
staleTime: Duration(hours: 1)
```

### 3. Register Queries in DI

Make queries accessible across your app:
```
class UserModule extends ZenModule {
  @override
  void configure() {
    final userQuery = ZenQuery<User>(
      queryKey: 'user:$currentUserId',
      fetcher: () => api.getUser(currentUserId),
    );
    
    Zen.put(userQuery, tag: 'userQuery');
  }
}

// Access anywhere
final userQuery = Zen.find<ZenQuery<User>>(tag: 'userQuery');
``` 

### 4. Handle Loading States Gracefully

Show stale data during refetch:
```
ZenQueryBuilder<User>(
  query: userQuery,
  showStaleData: true,
  builder: (context, data) => UserProfile(data),
  loading: () => CircularProgressIndicator(),
);
```

### 5. Dispose Queries Properly

ZenQuery extends ZenController, so it manages its lifecycle automatically when used with dependency injection. Manual disposal is only needed if you create queries outside of the DI system:
```
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
```
ZenQuery<T>({
  required String queryKey,
  required Future<T> Function() fetcher,
  ZenQueryConfig? config,
  T? initialData,
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

### ZenQueryBuilder
```
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
```
// Get cache instance
ZenQueryCache.instance

// Invalidate queries
invalidateQuery(String key)
invalidateQueriesWithPrefix(String prefix)
invalidateQueries(bool Function(String) predicate)

// Refetch queries
refetchQueries(bool Function(String) predicate)

// Get query
getQuery<T>(String key)

// Clear cache
clear()

// Get statistics
getStats()
```

---

## Examples

### Pagination
```
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
```
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
```
class TodoMutation {
  final ZenQuery<List<Todo>> todosQuery;
  
  TodoMutation(this.todosQuery);
  
  Future<void> toggleTodo(Todo todo) async {
    final previousTodos = todosQuery.data.value ?? [];
    
    // Optimistic update
    final updatedTodos = previousTodos.map((t) {
      if (t.id == todo.id) {
        return t.copyWith(completed: !t.completed);
      }
      return t;
    }).toList();
    todosQuery.setData(updatedTodos);
    
    try {
      // Perform mutation
      await api.toggleTodo(todo.id);
      
      // Invalidate to refetch fresh data
      todosQuery.invalidate();
      await todosQuery.refetch();
    } catch (error) {
      // Rollback on error
      todosQuery.setData(previousTodos);
      rethrow;
    }
  }
}
``` 

---


## Troubleshooting

### Query not refetching

Check if data is marked as stale:
```
print(query.isStale); // Should be true for refetch

// Force invalidation
query.invalidate();
```

### Memory leaks

Ensure queries are disposed properly:
```
// When using manually created queries
@override
void dispose() {
  myQuery.dispose();
  super.dispose();
}
``` 

### Concurrent request issues

ZenQuery automatically deduplicates requests with the same key. If you need separate instances, use different keys:
```
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

---

## Migration Guide

### From Provider
```
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
```
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