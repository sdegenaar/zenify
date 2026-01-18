
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
  fetcher: (_) => api.getUser(123),
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
  fetcher: (_) => api.getUser(123),
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

You can use a simple string or a list of values (which will be normalized automatically):

```dart
// Simple key
queryKey: 'users'

// Parameterized key (String interpolation) - Prone to typos!
queryKey: 'user:$userId'

// List Key (Recommended) - Type safe & cleaner
queryKey: ['user', userId, 'details'] 
// -> Normalized internally to "['user', 123, 'details']"
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

## Network Cancellation (Network Waste Gap)

ZenQuery automatically handles request cancellation to prevent bandwidth waste and battery drain.

### How it works
1. **Race Conditions**: If a user triggers a refetch while one is already in progress, the old request is cancelled.
2. **Lifecycle**: If a user leaves a screen (disposing the query), the pending request is cancelled.

### Implementing in Fetcher
Your fetcher function receives a `ZenCancelToken`. Pass this to your HTTP client.

**Using Dio:**
```dart
ZenQuery(
  queryKey: 'users',
  fetcher: (token) async {
    // Convert ZenCancelToken to Dio CancelToken
    // (You can make a simple extension for this)
    final dioToken = CancelToken();
    token.onCancel(() => dioToken.cancel());
    
    final response = await dio.get('/users', cancelToken: dioToken);
    return User.fromJson(response.data);
  }
)
```

**Using Http:**
```dart
ZenQuery(
  queryKey: 'users',
  fetcher: (token) async {
    final client = http.Client();
    
    // Register cancellation callback
    token.onCancel(() => client.close());
    
    try {
      final response = await client.get(Uri.parse('...'));
      return User.fromJson(jsonDecode(response.body));
    } finally {
      // Clean up is handled by client.close() on cancel
    }
  }
)
```

---

## Configuration

### Global Defaults

Set defaults for all queries using `ZenQueryClient`:

```dart
// In main.dart
void main() {
  Zen.init();
  
  // Create QueryClient with your app's defaults
  final queryClient = ZenQueryClient(
    defaultOptions: ZenQueryClientOptions(
      queries: ZenQueryConfig(
        staleTime: Duration(minutes: 5),
        cacheTime: Duration(hours: 1),
        retryCount: 3,
      ),
    ),
  );
  
  // Register with Zen DI
  Zen.put(queryClient);
  
  runApp(MyApp());
}

// Queries automatically use these defaults
final query = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: (_) => api.getUser(123),
  // Uses QueryClient defaults
);

// Override specific fields with copyWith
final defaults = Zen.find<ZenQueryClient>().getQueryDefaults();
final customQuery = ZenQuery<User>(
  queryKey: 'user:456',
  fetcher: (_) => api.getUser(456),
  config: defaults.copyWith(
    retryCount: 10,  // Override just this field
  ),
);
```

[See complete QueryClient guide →](query_client_pattern.md)
 

### Per-Query Configuration
```dart
final query = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: (_) => api.getUser(123),
  config: ZenQueryConfig(
    // Cache configuration
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(hours: 1),

    // Refetch behavior
    refetchOnMount: RefetchBehavior.ifStale,
    refetchOnFocus: RefetchBehavior.never,
    refetchOnReconnect: RefetchBehavior.ifStale,
    refetchInterval: Duration(minutes: 10),
    enableBackgroundRefetch: true,

    // Error handling
    retryCount: 3,
    retryCount: 3,
    retryDelay: Duration(seconds: 1),
    // Optional: Custom retry delay function
    retryDelayFn: (attempt, error) => Duration(seconds: 1),
    exponentialBackoff: true,
  ),
);
```

### Configuration Options Explained

| Option | Default | Description |
|--------|---------|-------------|
| `staleTime` | 30s | How long data is considered fresh |
| `cacheTime` | 5min | How long unused data stays in cache |
| `refetchOnMount` | `ifStale` | Refetch when component mounts (`always`, `ifStale`, `never`) |
| `refetchOnFocus` | `never` | Refetch when window gains focus |
| `refetchOnReconnect` | `ifStale` | Refetch on network reconnect |
| `refetchInterval` | null | Background refetch interval |
| `enableBackgroundRefetch` | false | Enable automatic background refetching |
| `retryCount` | 3 | Number of retry attempts |
| `retryDelay` | 200ms | Base delay between retries |
| `retryDelayFn` | null | Custom function for dynamic delay calculation |
| `maxRetryDelay` | 30s | Maximum retry delay cap |
| `retryBackoffMultiplier` | 2.0 | Exponential backoff multiplier |
| `exponentialBackoff` | true | Use exponential backoff for retries |
| `retryWithJitter` | true | Add jitter to retry delays |
| `autoPauseOnBackground` | false | Auto-pause when app backgrounded (opt-in) |
| `refetchOnResume` | false | Refetch stale data on resume (opt-in) |
| `placeholderData` | null | Data to show while initial fetch is pending |


---

## Mutations

Think of **Mutations** as the "Writes" of your application.
While `ZenQuery` is for **Reading** data (like GET requests), `ZenMutation` is for **Changing** it (like POST, PUT, DELETE).

**Why use `ZenMutation` instead of a simple async function?**
- 📊 **Status Tracking**: Automatically tracks `isLoading`, `error`, and `success` states for your UI.
- 📶 **Offline Engine**: Mutations can be **queued** when offline and automatically replayed when online.
- 🎣 **Lifecycle Hooks**: Provides standard places (`onMutate`, `onSettled`) to update cache or show alerts.

```dart
final loginMutation = ZenMutation<User, LoginArgs>(
  mutationFn: (args) => api.login(args.username, args.password),
  
  // Lifecycle hooks
  onMutate: (args) async {
    // Optional: Return a context object (e.g. for rollback)
    return {'startTime': DateTime.now()};
  },
  
  onSuccess: (user, args, context) {
    // Access context returned from onMutate
    final startTime = (context as Map)['startTime'];
    print('Login took ${DateTime.now().difference(startTime)}');
  },
  
  onError: (error, args, context) {
    // Show error snackbar
  },
  
  onSettled: (data, error, args, context) {
    // Always runs (success or error)
  }
);

// Trigger
loginMutation.mutate(
  LoginArgs('user', 'pass'),
  // Optional call-time callbacks (run after the definition callbacks)
  onSuccess: (user, args) => Navigator.pop(context),
);
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
    ZenQueryCache.instance.invalidateQuery(['posts', 'feed']);
  }
);
```

---

## Infinite Queries (Pagination)

Use `ZenInfiniteQuery` for lists that load more data as you scroll.

```dart
final postsQuery = ZenInfiniteQuery<Page>(
  // Use a list key for complex identifiers
  queryKey: ['posts', 'feed', category], 

  // Fetcher receives the page param (null for first page) AND cancel token
  infiniteFetcher: (pageParam, token) => api.getPosts(page: pageParam ?? 1, cancelToken: token),

  // Calculate next page param from response. Return null if no more pages.
  getNextPageParam: (lastPage, allPages) {
    return lastPage.hasMore ? lastPage.nextPage : null;
  },

  // Optional: Bidirectional pagination
  getPreviousPageParam: (firstPage, allPages) {
     return firstPage.hasPrevious ? firstPage.prevPage : null;
  },
);
```

### Using in UI

```dart
ZenQueryBuilder<List<Page>>(
  query: postsQuery,
  // Keep showing old data while loading the next page prevents "flash"
  keepPreviousData: true, 
  builder: (context, pages) {
    // Flatten pages into items
    final allPosts = pages.expand((page) => page.posts).toList();

    return ListView.builder(
      itemCount: allPosts.length + 1,
      itemBuilder: (context, index) {
        if (index == allPosts.length) {
          // Loading indicator at bottom
          if (postsQuery.hasNextPage.value) {
            postsQuery.fetchNextPage();
            return CircularProgressIndicator();
          }
          return SizedBox();
        }
        return PostTile(allPosts[index]);
      },
    );
  }
);
```
 ---

## Stream Queries (Real-time Data)

Handle WebSockets, Firebase streams, and other real-time sources with the same robust API.

```dart
final chatQuery = ZenStreamQuery(
  queryKey: 'chat-messages',
  streamFn: () => chatService.messagesStream,
);

ZenStreamQueryBuilder<List<Message>>(
  query: chatQuery,
  builder: (context, messages) => ChatList(messages),
);
```

---

## Persistence (Offline Support)

Zenify provides an architecture for persisting query data across app restarts. You provide the storage implementation, and Zenify handles the rest (hydration, serialization, expiration).

### 1. Implement Storage
Create a class that implements `ZenStorage`. This allows you to use any backend you prefer (SharedPreferences, Hive, SQLite, etc.).

```dart
class MyStorage implements ZenStorage {
  final SharedPreferences prefs;
  MyStorage(this.prefs);

  @override
  Future<void> write(String key, Map<String, dynamic> json) async {
    await prefs.setString(key, jsonEncode(json));
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final str = prefs.getString(key);
    return str != null ? jsonDecode(str) : null;
  }

  @override
  Future<void> delete(String key) async {
    await prefs.remove(key);
  }
}
```

### 2. Configure Global Storage
Set your storage instance at app startup.

```dart
void main() async {
  final prefs = await SharedPreferences.getInstance();
  ZenQueryCache.instance.setStorage(MyStorage(prefs));
  
  runApp(MyApp());
}
```

### 3. Enable Persistence on Query
Add `persist`, `toJson`, and `fromJson` to your config.

```dart
final userQuery = ZenQuery<User>(
  queryKey: 'user:profile',
  fetcher: (_) => api.getUser(),
  config: ZenQueryConfig(
    persist: true,
    cacheTime: Duration(days: 7), // Keep on disk for 7 days
    fromJson: (json) => User.fromJson(json),
    toJson: (user) => user.toJson(),
  ),
);
```

**How it works:**
1. **Hydration**: On initialization, `ZenQuery` checks storage. If valid data exists, it's loaded immediately.
2. **Background Fetch**: It typically still triggers a background fetch to update stale data (SWR pattern).
3. **Persist**: When a fetch succeeds, the new data is automatically written to storage.

---


## Advanced Features

### Granular Rebuilds (Select)

Optimize performance by listening only to specific parts of your data. This is crucial when fetching large objects but displaying only a small piece of information.

```dart
// Derived query - only updates when 'isOnline' changes
// Ignores changes to other user fields (name, email, etc.)
final isOnlineQuery = userQuery.select((user) => user.isOnline);

// Use in widget
ZenQueryBuilder<bool>(
  query: isOnlineQuery,
  builder: (context, isOnline) => OnlineBadge(isOnline),
);
```

**Key Benefits:**
- ⚡ **Performance**: Widgets only rebuild when the *selected* value changes.
- 🎯 **Focus**: Separate data fetching from view-specific logic.
- 🔄 **Lifecycle**: Derived queries share the parent's lifecycle and state automatically.

### Dependent Queries

Execute queries sequentially by using the `enabled` parameter. This allows you to wait for one query to complete before starting another.

```dart
// 1. Fetch User
final userQuery = ZenQuery<User>(
  queryKey: 'user',
  fetcher: (_) => api.getUser(),
);

// 2. Fetch Posts (depends on User ID)
final postsQuery = ZenQuery<List<Post>>(
  queryKey: ['posts', 'user-posts'], 
  fetcher: (_) => api.getPosts(userQuery.data.value!.id),
  
  // Start disabled
  enabled: false, 
);

// 3. Wire them up in onInit()
@override
void onInit() {
  // Automatically enable/disable posts query based on user data
  ZenWorkers.ever(userQuery.data, (user) {
    postsQuery.enabled.value = user != null;
  });
}
```

**How it works:**
1. `postsQuery` starts in `idle` state because `enabled` is false.
2. `userQuery` fetches data.
3. Worker updates `postsQuery.enabled` to `true`.
4. `postsQuery` automatically triggers `fetch()` because it became enabled and was idle.


### Data Prefetching

Improve perceived performance by pre-loading data before the user needs it (e.g., on button hover or during onboarding).

```dart
// In a service or controller
void onHoverUser(String userId) {
  ZenQueryCache.instance.prefetch(
    queryKey: ['user', userId],
    fetcher: (_) => api.getUser(userId),
    staleTime: Duration(minutes: 5), // Only fetch if stale
  );
}
```

**How it works:**
- Checks cache first. If fresh data exists, does nothing.
- If stale/missing, fetches in background and updates cache.
- When the user navigates to the page, `ZenQuery` will find the fresh data immediately!

### Optimistic Updates

**Easy way with helpers:**
```dart
final updatePost = OptimisticMutation.listUpdate<Post>(
  queryKey: 'posts',
  mutationKey: 'update_post',
  mutationFn: (post) => api.updatePost(post),
  where: (item, updated) => item.id == updated.id,
);

// Use it
updatePost.mutate(updatedPost);
```

See [Offline Guide](offline_guide.md#35-optimistic-updates-instant-feedback) for all helpers (`listAdd`, `listUpdate`, `listRemove`, `add`, `update`, `remove`).

**Manual approach (advanced):**

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

### Smart Refetching (Focus & Network)

Make your app feel alive by automatically updating data when the user returns to the app or network recovers.

**1. Refetch on Window Focus**
Enabled by default in `ZenQueryConfig`. Triggers a refetch when the app enters the `resumed` state (foreground).

**2. Refetch on Reconnect**
Enabled by default, but requires setup. You must provide a connectivity stream to Zenify at startup.

```dart
// main.dart
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  Zen.init();
  
  // Hook up connectivity (using connectivity_plus package)
  Zen.setNetworkStream(
    Connectivity().onConnectivityChanged.map(
      (results) => !results.contains(ConnectivityResult.none)
    )
  );
  
  runApp(MyApp());
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
  fetcher: (_) => api.getUser(123),
  initialData: User(id: 123, name: 'Loading...'),
);

// Widget shows initial data immediately, then updates when fetched
``` 

### Background Refetching

Keep data fresh automatically:
```dart
final liveDataQuery = ZenQuery<StockPrice>(
  queryKey: 'stock:AAPL',
  fetcher: (_) => api.getStockPrice('AAPL'),
  config: ZenQueryConfig(
    refetchInterval: Duration(seconds: 30),
    enableBackgroundRefetch: true,
  ),
);
```

### Pause/Resume (Battery Optimization)

Manually or automatically pause queries to save battery and reduce network usage:

**Manual Control:**
```dart
// Works for all query types
query.pause();        // ZenQuery
streamQuery.pause();  // ZenStreamQuery  
infiniteQuery.pause(); // ZenInfiniteQuery

// Resume
query.resume();
streamQuery.resume();
infiniteQuery.resume();
```

**Automatic Lifecycle Integration (Opt-in):**
```dart
// Works for both queries and streams
final query = ZenQuery<User>(
  queryKey: 'user',
  fetcher: (_) => api.getUser(),
  config: ZenQueryConfig(
    autoPauseOnBackground: true,  // Pause when app backgrounded
    refetchOnResume: true,         // Refetch stale data on resume
  ),
);

final streamQuery = ZenStreamQuery<Message>(
  queryKey: 'chat',
  streamFn: () => chatService.messagesStream,
  config: ZenQueryConfig(
    autoPauseOnBackground: true,  // Pause stream when app backgrounded
  ),
);
```

**Real-time streams (keep active in background):**
```dart
// Chat, location, or live updates - DON'T pause
final liveStream = ZenStreamQuery<Message>(
  queryKey: 'live-chat',
  streamFn: () => chatService.messagesStream,
  config: ZenQueryConfig(
    autoPauseOnBackground: false,  // Keep active (default)
  ),
);
```

**When to use:**
- ✅ Mobile apps for battery optimization
- ✅ Apps with expensive background operations
- ❌ Desktop/web apps (users switch windows frequently)
- ❌ Real-time features (chat, live updates, location tracking)

### Enhanced Retry with Exponential Backoff

Retries now use true exponential backoff with jitter to prevent thundering herd:

```dart
final query = ZenQuery<Data>(
  queryKey: 'api-data',
  fetcher: (_) => api.getData(),
  config: ZenQueryConfig(
    retryCount: 5,
    retryDelay: Duration(milliseconds: 200),      // Base delay
    maxRetryDelay: Duration(seconds: 30),         // Cap
    retryBackoffMultiplier: 2.0,                  // Exponential factor
    retryWithJitter: true,                        // Add randomness
  ),
);
// Retries at: ~200ms, ~400ms, ~800ms, ~1.6s, ~3.2s (with jitter)
```

**Default behavior:**
- Base delay: 200ms (reduced from 1s)
- Multiplier: 2.0 (exponential)
- Max delay: 30s (prevents infinite growth)
- Jitter: enabled (prevents simultaneous retries)

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
      fetcher: (_) => api.getUser(currentUserId),
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

### 5. Lifecycle Management

**Automatic (Recommended):** Create queries in `onInit()` for automatic tracking:
```dart
class MyController extends ZenController {
  late final userQuery;

  @override
  void onInit() {
    super.onInit();
    // ✅ Automatically tracked and disposed!
    userQuery = ZenQuery<User>(
      queryKey: 'user:123',
      fetcher: (_) => api.getUser(123),
    );
  }
}
```

**Scope-Owned:** Register in modules for shared access:
```dart
class FeatureModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.putQuery<User>(
      queryKey: 'user',
      fetcher: (_) => api.getUser(),
    );
    // ✅ Automatically disposed when scope disposes!
  }
    // ✅ Automatically disposed when scope disposes!
  }
}
```

### 6. Always Use Mutations for Writes
Avoid calling API write methods directly. Using `ZenMutation` ensures:
- **Offline Support**: Writes are queued when the network is down.
- **State Management**: `isLoading`, `error`, and `success` states are tracked reactively.
- **Cache Invalidation**: Hook into `onSettled` to automatically refresh related queries.

```dart
// ❌ Avoid:
Future<void> deletePost() async {
  await api.deletePost(id);
  // Manual state management, no offline queue
}

// ✅ Correct:
final deleteMutation = ZenMutation<void, String>(
  mutationKey: 'delete_post',
  mutationFn: (id) => api.deletePost(id),
  onSettled: (_, __, ___, ____) => feedQuery.refetch(),
);
```

**Manual (Rare):** Only needed for standalone queries:
```dart
// Created outside controller or module
final query = ZenQuery<User>(
  queryKey: 'user:123',
  fetcher: (_) => api.getUser(123),
);

// ⚠️ Must manually dispose
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
- `invalidate()`: Mark as stale and refetch if active
- `reset()`: Reset to initial state

### ZenMutation

#### Constructor
```dart
ZenMutation<TData, TVariables>({
  required Future<TData> Function(TVariables) mutationFn,
  FutureOr<Object?> Function(TVariables)? onMutate,
  void Function(TData, TVariables, Object?)? onSuccess,
  void Function(Object, TVariables, Object?)? onError,
  void Function(TData?, Object?, TVariables, Object?)? onSettled,
})
```

#### Properties
- `mutate(variables, {onSuccess, onError, onSettled})`: Triggers the mutation
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
  bool keepPreviousData = false,
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
- **Controller-owned queries**: Automatically tracked and disposed with the controller

---

## Query Lifecycle Management

### Automatic Tracking (Recommended) ⭐

Queries created in a controller's `onInit()` are **automatically tracked and disposed** - no manual cleanup needed!

```dart
class UserController extends ZenController {
  late final userQuery;
  late final postsQuery;

  @override
  void onInit() {
    super.onInit();

    // ✅ Automatically tracked - no wrapper needed!
    userQuery = ZenQuery<User>(
      queryKey: 'user:123',
      fetcher: (_) => api.getUser(123),
    );

    postsQuery = ZenQuery<List<Post>>(
      queryKey: 'posts:123',
      fetcher: (_) => api.getPosts(123),
    );
  }

  @override
  void onClose() {
    // ✅ Queries automatically disposed - no code needed!
    super.onClose();
  }
}
```

**How it works:**
1. When `onInit()` runs, the controller sets itself as the "current parent"
2. Any query created during `onInit()` automatically registers with the parent controller
3. When the controller disposes, all tracked queries are automatically disposed
4. **Zero boilerplate** - impossible to forget cleanup!

**Benefits:**
- ✅ **Zero boilerplate** - No manual `dispose()` calls
- ✅ **Memory leak prevention** - Impossible to forget cleanup
- ✅ **Safe by default** - Works for all query types (`ZenQuery`, `ZenStreamQuery`, `ZenMutation`)

---

### Scope-Owned Queries (Shared Across Controllers)

Queries created in modules are managed by the scope and shared across all controllers in the hierarchy:

```dart
class FeatureModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // ✅ Shared query - available to all controllers in this scope
    scope.putQuery<User>(
      queryKey: 'shared-user',
      fetcher: (_) => api.getUser(),
      config: ZenQueryConfig(staleTime: Duration(minutes: 5)),
    );

    // Automatically disposed when scope disposes
  }
}

// Usage in any controller
class MyController extends ZenController {
  late final ZenQuery<User> userQuery;

  @override
  void onInit() {
    super.onInit();
    // Access shared query from scope
    userQuery = Zen.find<ZenQuery<User>>();
  }

  // No disposal needed - scope handles it!
}
```

**When to use:**
- ✅ Data shared across multiple controllers in a feature
- ✅ Feature-specific data that should dispose with the route
- ✅ Avoiding duplication of queries across controllers

---

### Manual Tracking (Advanced)

For queries created in a controller's constructor (not in `onInit()`), use manual tracking:

```dart
class MyController extends ZenController {
  late final userQuery;

  MyController(String userId) {
    // Created in constructor, not in onInit()
    userQuery = ZenQuery<User>(
      queryKey: 'user:$userId',
      fetcher: (_) => api.getUser(userId),
    );

    // ⚠️ Manual tracking required since it's outside onInit()
    trackController(userQuery);
  }

  @override
  void onClose() {
    // ✅ Auto-disposed because we called trackController()
    super.onClose();
  }
}
```

**When to use:**
- ⚠️ Only when you must create queries in the constructor
- ⚠️ Better to use `late final` + `onInit()` pattern instead

---

### Lifecycle Patterns Summary

| **Pattern** | **Code** | **Disposal** | **Use Case** |
|-------------|----------|--------------|--------------|
| **Automatic (Recommended)** | `late final query` in `onInit()` | Automatic | Controller-owned queries |
| **Scope-Owned** | `scope.putQuery()` in module | Scope handles | Shared across controllers |
| **Manual Tracking** | `trackController(query)` | Automatic via tracking | Constructor-created queries |
| **Global** | No scope parameter | Manual or permanent | App-wide data |

**Best Practice:** Always use `late final` + `onInit()` for automatic tracking ✅

---

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
      fetcher: (_) => api.getProduct(productId),
      config: ZenQueryConfig(staleTime: Duration(minutes: 5)),
    );

    scope.putQuery<List<Review>>(
      queryKey: 'reviews:$productId',
      fetcher: (_) => api.getReviews(productId),
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
  fetcher: (_) => api.getProduct(productId),
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
      fetcher: (_) => api.getProduct(productId),
    );

    // Reviews - scope-specific
    scope.putQuery<List<Review>>(
      queryKey: 'reviews:$productId',
      fetcher: (_) => api.getReviews(productId),
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

#### Within Controller (Automatic Tracking) ⭐
```dart
class ProductController extends ZenController {
  final String productId;
  late final productQuery;

  ProductController(this.productId);

  @override
  void onInit() {
    super.onInit();

    // ✅ Automatically tracked - no manual disposal needed!
    productQuery = ZenQuery<Product>(
      queryKey: 'product:$productId',
      fetcher: (_) => api.getProduct(productId),
    );
  }

  @override
  void onClose() {
    // ✅ Query automatically disposed!
    super.onClose();
  }
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
      fetcher: (_) => api.getCurrentUser(),
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
      fetcher: (_) => api.getProduct(productId),
    );

    scope.putQuery<List<Review>>(
      queryKey: 'reviews:$productId',
      fetcher: (_) => api.getReviews(productId),
    );

    scope.putQuery<List<Product>>(
      queryKey: 'related:$productId',
      fetcher: (_) => api.getRelatedProducts(productId),
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
    fetcher: (_) => api.getPosts(page),
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
  fetcher: (_) => api.getUser(userId),
);

// Second query: Get user's posts (depends on user data)
final postsQuery = ZenQuery<List<Post>>(
  queryKey: 'posts:user:$userId',
  fetcher: (_) async {
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
  fetcher: (_) => api.getUser(id),
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
  fetcher: (_) => api.getUser(id),
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