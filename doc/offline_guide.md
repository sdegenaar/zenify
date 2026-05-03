# 📶 Offline-First Guide

Zenify v1.6.0 transforms from a simple data fetcher into a robust **Offline Synchronization Engine**.

> **🚀 Live Demo**: Check out the complete [Offline Example App](../example/zen_offline) to see these features in action, including optimistic updates and background syncing.

This guide explains how to make your app work flawlessly without an internet connection.

---

## 1. Enabling Offline Support (`ZenStorage`)

Zenify's synchronization engine requires a storage backend to persist query data and mutation queues across app restarts.

### Design Philosophy: Bring Your Own Storage

Zenify ships **zero third-party dependencies** by design. Rather than bundling `shared_preferences`, `hive`, `sqflite`, or any other platform package, Zenify provides a simple 3-method interface — `ZenStorage` — that you implement yourself.

This means you choose exactly what goes into your project.

```dart
// The full interface — just 3 methods:
abstract class ZenStorage {
  Future<void> write(String key, Map<String, dynamic> json);
  Future<Map<String, dynamic>?> read(String key);
  Future<void> delete(String key);
}
```

### Production Adapter: SharedPreferences

This is a production-ready implementation you can copy straight into your project:

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenify/zenify.dart';

class SharedPreferencesStorage implements ZenStorage {
  final String prefix;
  SharedPreferences? _prefs;

  SharedPreferencesStorage({this.prefix = 'zen_query_'});

  // Cache the instance — only calls getInstance() once per app lifecycle
  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  String _key(String key) => '$prefix$key';

  @override
  Future<void> write(String key, Map<String, dynamic> json) async {
    try {
      await (await _instance).setString(_key(key), jsonEncode(json));
    } catch (e) {
      // Never crash the app — log and continue
      debugPrint('ZenStorage write failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    try {
      final raw = (await _instance).getString(_key(key));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('ZenStorage read failed: $e');
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await (await _instance).remove(_key(key));
    } catch (e) {
      debugPrint('ZenStorage delete failed: $e');
    }
  }

  /// Clears only Zenify's keys — leaves all other SharedPreferences intact.
  Future<void> clearAll() async {
    final prefs = await _instance;
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) await prefs.remove(k);
  }
}
```

> **See also**: `example/zen_offline/lib/storage.dart` for the canonical production example with full error handling.

### Production Adapter: Hive (minimal recipe)

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zenify/zenify.dart';

class HiveStorage implements ZenStorage {
  late final Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('zenify_cache');
  }

  @override
  Future<void> write(String key, Map<String, dynamic> json) async =>
      _box.put(key, json);

  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      (_box.get(key) as Map?)?.cast<String, dynamic>();

  @override
  Future<void> delete(String key) async => _box.delete(key);
}
```

### Built-in: InMemoryStorage (testing & debug)

Zenify exports `InMemoryStorage` — a zero-dependency in-memory adapter that ships with the package:

```dart
import 'package:zenify/zenify.dart';

// Perfect for tests:
final storage = InMemoryStorage();
ZenQueryCache.instance.setStorage(storage);

// Or conditionally in your app:
await Zen.init(
  storage: kDebugMode ? InMemoryStorage() : SharedPreferencesStorage(),
);

// Useful extras:
storage.clear();               // Wipe all entries
storage.containsKey('users');  // Check existence
storage.length;                // How many entries
```

### Initialization

Pass your storage instance to `Zen.init()`. This single line enables both **Cache Persistence** and the **Mutation Queue**.

```dart
void main() async {
  await Zen.init(
    storage: SharedPreferencesStorage(),

    // Optional: Register Mutation Handlers (see Section 3)
    mutationHandlers: {
      'create_post': (payload) => api.createPost(payload),
    },
  );

  // Set up network monitoring (required for offline/online detection)
  // Use 'connectivity_plus' or any package that emits a bool stream.
  Zen.setNetworkStream(
    Connectivity().onConnectivityChanged.map(
      (results) => !results.contains(ConnectivityResult.none),
    ),
  );

  runApp(MyApp());
}
```

**Note:** `Zen.setNetworkStream` expects a `Stream<bool>`:
- `true` = device is online
- `false` = device is offline

---

## 2. Persisting Queries

To allow a query to work offline, simply enable persistence in its config.

```dart
final postsQuery = ZenQuery<List<Post>>(
  queryKey: 'posts',
  fetcher: (_) => api.getPosts(),
  config: ZenQueryConfig(
    persist: true, // Only fetch if stale, otherwise hydrate from disk
    networkMode: NetworkMode.offlineFirst, // See Section 4
    toJson: (posts) => {'posts': posts.map((p) => p.toJson()).toList()},
    fromJson: (json) => (json['posts'] as List)
        .map((e) => Post.fromJson(e))
        .toList(),
  ),
);
```

**How it works:**
1. **On Start**: The query automatically loads data from disk (hydration). It updates the UI immediately.
2. **On Fetch**: When new data arrives from the network, it is automatically saved to disk.

---

## 3. Offline Mutations (The Queue)

If a user performs an action (like "Like Post" or "Create Todo") while offline, Zenify automatically queues it.

### Step 1: Add a `mutationKey`

The `mutationKey` is required to identify the mutation in the persistent queue.

```dart
final createPostMutation = ZenMutation<Post, Map<String, dynamic>>(
  mutationKey: 'create_post', // Required for queuing
  mutationFn: (data) => api.createPost(data),
  onSuccess: (post, vars) => print('Posted!'),
);
```

### Step 2: Register a Handler

Since we cannot save Dart functions to disk, you must register a "Handler" for each key in `Zen.init()`.

```dart
await Zen.init(
  storage: MyStorage(),
  mutationHandlers: {
    // This runs when the queue replays in the background
    'create_post': (payload) async {
      await api.createPost(payload);
    },
  },
);
```

### Behavior
- **Online**: The mutation runs immediately.
- **Offline**: The mutation is added to the valid queue. The UI receives an "Idle" state (or you can show a "Pending" badge).
- **Reconnection**: When the network returns, the queue automatically replays in the background.

---

## 3.5. Why Use Mutations? (vs Direct API Calls)

You might wonder: "Why not just call `api.createPost()` directly?" Here's why mutations are better:

### Direct API Call (Limited)
```dart
Future<void> createPost(Post post) async {
  try {
    await api.createPost(post);
    // UI doesn't update - need to manually refetch
    postsQuery.refetch();
  } catch (e) {
    // Manual error handling
  }
}
```

**Problems:**
- ❌ No loading/error state tracking
- ❌ UI doesn't update until refetch completes (slow)
- ❌ No offline support
- ❌ No optimistic updates
- ❌ Manual cache management

### With ZenMutation (Powerful)
```dart
final createPost = ZenMutation.listPut<Post>(
  queryKey: 'posts',
  mutationFn: (post) => api.createPost(post),
);

// Use it
createPost.mutate(newPost);
```

**Benefits:**
- ✅ **Automatic loading state**: `mutation.isLoading.value`
- ✅ **Automatic error handling**: `mutation.error.value`
- ✅ **Optimistic updates**: UI updates instantly
- ✅ **Automatic rollback**: Reverts on error
- ✅ **Offline queueing**: Works offline, syncs later
- ✅ **Cache updates**: Automatically updates queries
- ✅ **Reactive UI**: Widgets rebuild automatically

**Use mutations for all CRUD operations on displayed data.** Use direct API calls only for fire-and-forget operations (analytics, logging, etc.).

---

## 3.6. Optimistic Updates (Instant Feedback)

To provide the best offline experience, update your UI immediately before the server responds.

### Easy Way: Use Helpers (Recommended)

Zenify provides helpers for common optimistic update patterns:

**Add to list:**
```dart
final createPost = ZenMutation.listPut<Post>(
  queryKey: 'posts',
  mutationKey: 'create_post',
  mutationFn: (post) => api.createPost(post),
);
```

**Update in list:**
```dart
final updatePost = ZenMutation.listSet<Post>(
  queryKey: 'posts',
  mutationKey: 'update_post',
  mutationFn: (post) => api.updatePost(post),
  where: (item, updated) => item.id == updated.id,
);
```

**Remove from list:**
```dart
final deletePost = ZenMutation.listRemove<Post>(
  queryKey: 'posts',
  mutationKey: 'delete_post',
  mutationFn: (post) => api.deletePost(post.id),
  where: (item, toRemove) => item.id == toRemove.id,
);
```

**Single value operations:**
```dart
// Create/Update
final updateUser = ZenMutation.set<User>(
  queryKey: 'current_user',
  mutationKey: 'update_user',
  mutationFn: (user) => api.updateUser(user),
);

// Delete
final logout = ZenMutation.remove(
  queryKey: 'current_user',
  mutationKey: 'logout',
  mutationFn: () => api.logout(),
);
```

**Optional callbacks:**

All helpers support optional `onSuccess` and `onError` callbacks for custom logic:

```dart
final createPost = ZenMutation.listPut<Post>(
  queryKey: 'posts',
  mutationKey: 'create_post',
  mutationFn: (post) => api.createPost(post),
  onSuccess: (data, item, context) {
    // Custom success logic
    logger.info('Post created successfully');
    analytics.logEvent('post_created');
  },
  onError: (error, item) {
    // Custom error handling (rollback is automatic)
    logger.error('Failed to create post', error);
    analytics.logError('post_creation_failed', error);
  },
);
```

**Note:** Rollback happens automatically on error, even without `onError`. The callbacks are purely for additional custom logic.

### Advanced: Manual Control

For complex scenarios (updating multiple queries, custom rollback logic):

```dart
final createPost = ZenMutation<Post, Post>(
  mutationKey: 'create_post',
  mutationFn: (post) => api.createPost(post),
  onMutate: (newPost) async {
    // Update multiple queries
    Zen.queryCache.setQueryData<List<Post>>(
      'feed',
      (oldData) => [newPost, ...(oldData ?? [])],
    );
    Zen.queryCache.setQueryData<List<Post>>(
      'trending',
      (oldData) => [newPost, ...(oldData ?? [])],
    );
     
    return oldData; // Save for rollback
  },
  onError: (error, vars, context) {
    // Custom rollback logic
    if (context != null) {
      Zen.queryCache.setQueryData('feed', (_) => context);
    }
  }
);
```

**When to use helpers vs manual:**
- ✅ **Use helpers** for standard CRUD operations (95% of cases)
- ⚙️ **Use manual** for multi-query updates or complex rollback logic

Using optimistic updates, users see changes immediately, even offline. Mutations are queued and sync when back online.

---

## 4. Network Modes

Control precisely how your queries behave offline.

```dart
ZenQueryConfig(
  // Standard behavior. Pauses if offline.
  networkMode: NetworkMode.online, 
  
  // Best for mobile. Tries cache first, then waits for network.
  networkMode: NetworkMode.offlineFirst,
  
  // Useful for localhost development (ignores network status)
  networkMode: NetworkMode.always,
)
```

> **Tip (v1.10.3+):** Pair any `NetworkMode` with `retryWhenOnline: true` to make queries that fail mid-retry automatically pause instead of entering `error` state, then self-heal when connectivity returns:
> ```dart
> ZenQueryConfig(
>   networkMode: NetworkMode.always, // run even offline (e.g. for testing/LAN)
>   retryCount: 3,
>   retryWhenOnline: true, // pause on exhaustion if offline, auto-retry on reconnect
> )
> ```
> See [Network-Aware Retry Pausing](zen_query_guide.md#network-aware-retry-pausing-v1103) in the ZenQuery Guide for full details.

---

## 5. Structural Sharing (Performance)

**New in v1.6.0**: Zenify automatically performs deep equality checks on data. 

If your backend sends the *exact same JSON* as before, Zenify preserves the old object reference. This prevents generic `ZenQueryBuilder`s from rebuilding, saving battery and eliminating UI flicker.


**Zero configuration required.** It just works.

---

## 6. Supported Query Types

| Query Type | Offline Support | Notes |
|---|---|---|
| **ZenQuery** | ✅ Full | Automatically hydrates data and restores state. |
| **ZenInfiniteQuery** | ✅ Full | Restores all loaded pages and recalculates pagination cursors. |
| **ZenMutation** | ✅ Full | Queues mutations and replays them when online. |
| **ZenStreamQuery** | ❌ None | Streams are ephemeral/real-time and typically do not need persistence. |
