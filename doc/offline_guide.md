# 📶 Offline-First Guide (v1.6.0)

Zenify v1.6.0 transforms from a simple data fetcher into a robust **Offline Synchronization Engine**.

> **🚀 Live Demo**: Check out the complete [Offline Example App](../example/zen_offline) to see these features in action, including optimistic updates and background syncing.

This guide explains how to make your app work flawlessly without an internet connection.

---

## 1. Enabling Offline Support (`ZenStorage`)

The synchronization engine requires a place to store data. Implement the `ZenStorage` interface using your preferred storage solution (Hive, SQLite, SharedPreferences, etc.).

### Example Implementation (SharedPreferences)

```dart
import 'package:zenify/zenify.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MyStorage implements ZenStorage {
  @override
  Future<void> write(String key, Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(json));
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    return jsonString != null ? jsonDecode(jsonString) : null;
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
```

### Initialization

Pass your storage instance to `Zen.init()`. This single line enables both **Cache Persistence** and the **Mutation Queue**.

```dart
void main() async {
  // Initialize Zenify with Storage
  await Zen.init(
    storage: MyStorage(), 
    
    // Optional: Register Mutation Handlers (see Section 3)
    mutationHandlers: {
      'create_post': (payload) => api.createPost(payload),
    },
  );
  
  // 2. Setup Network Monitoring (Crucial!)
  // Zenify needs to know when you are online. 
  // You can use 'connectivity_plus' or any other package.
  Zen.setNetworkStream(
    Connectivity().onConnectivityChanged.map(
      (results) => !results.contains(ConnectivityResult.none)
    )
  );
  
  runApp(MyApp());
}
```

**Note:** You must provide a `Stream<bool>` via `Zen.setNetworkStream`.
- `true` = Online
- `false` = Offline

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

## 3.5. Optimistic Updates (Instant Feedback)

To provide the best offline experience, update your UI immediately before the server responds.

```dart
final createPost = ZenMutation<Post, Post>(
  mutationKey: 'create_post',
  mutationFn: (post) => api.createPost(post),
  onMutate: (newPost) async {
    // Standard Way: Update the cache instantly!
    ZenQueryCache.instance.setQueryData<List<Post>>(
      'feed',
      (oldData) => [newPost, ...(oldData ?? [])],
    );
     
    return null; // context
  },
  onError: (error, vars, context) {
    // Optional: Rollback if needed
  }
);
```

Using `setQueryData`, the user sees their new post immediately, even if they are offline. The mutation is queued in the background.

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
