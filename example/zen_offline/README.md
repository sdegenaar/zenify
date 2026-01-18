# 📶 Zenify Offline Example

A complete demonstration of Zenify's **Offline-First Engine** (v1.6.0), showcasing persistence, mutation queuing, and optimistic updates.

## 🎯 What This Example Demonstrates

This app is a **fully functional offline-capable feed** that works seamlessly with or without internet:

- ✅ **Auto-Persistence**: Posts are saved to disk and restored instantly on app restart
- ✅ **Offline Mutations**: Create, like, and delete posts while offline—they sync when you reconnect
- ✅ **Optimistic Updates**: UI updates instantly before the server responds
- ✅ **Network Simulator**: Toggle offline mode with a switch to test behavior
- ✅ **Mutation Queue**: See pending actions replay automatically when back online

## 🚀 Quick Start

```bash
cd example/zen_offline
flutter pub get
flutter run
```

## 🧪 Try These Features

### 1. **Test Offline Persistence**
1. Run the app
2. Add a few posts
3. **Close the app completely**
4. Reopen → Posts are still there! (Auto-hydrated from storage)

### 2. **Test Offline Mutations**
1. Toggle the **"Simulating Offline"** switch (top right)
2. Add a post → It appears instantly (optimistic update)
3. Like/delete posts → UI updates immediately
4. Toggle back online → Watch mutations replay automatically

### 3. **Test Network Simulator**
- The switch in the app bar simulates offline mode
- The "On/Off" chip shows the actual network status Zenify sees
- This lets you test offline behavior without disabling WiFi

## 🏗️ Architecture Highlights

### Storage Implementation
Uses `SharedPreferences` via the `ZenStorage` interface:
```dart
class PreferenceStorage implements ZenStorage {
  // Persist query data to SharedPreferences
  // See: lib/storage.dart
}
```

### Offline-Ready Query
```dart
ZenQuery<List<Post>>(
  queryKey: 'feed',
  fetcher: (_) => MockApi.getPosts(),
  config: ZenQueryConfig(
    persist: true,                        // Enable persistence
    networkMode: NetworkMode.offlineFirst, // Use cache when offline
  ),
);
```

### Offline-Ready Mutations
```dart
ZenMutation<Post, Post>(
  mutationKey: 'create_post',  // Required for offline queue
  mutationFn: (post) => api.createPost(post),
  onMutate: (post) {
    // Optimistic update: Add to UI immediately
    ZenQueryCache.instance.setQueryData<List<Post>>(
      'feed',
      (old) => [post, ...(old ?? [])],
    );
  },
);
```

### Mutation Handlers
Registered in `main.dart` to replay queued mutations:
```dart
Zen.init(
  storage: PreferenceStorage(),
  mutationHandlers: {
    'create_post': (payload) => api.createPost(Post.fromJson(payload)),
    'like_post': (payload) => api.likePost(payload['id'], payload['isLiked']),
    'delete_post': (payload) => api.deletePost(payload['id']),
  },
);
```

## 📂 Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App setup, mutation handlers, network simulator |
| `lib/feed_controller.dart` | Query and mutation definitions with optimistic updates |
| `lib/storage.dart` | `ZenStorage` implementation using SharedPreferences |
| `lib/api.dart` | Mock API with simulated network delays |

## 🎓 Learn More

- [Offline-First Guide](../../doc/offline_guide.md) - Complete documentation
- [ZenQuery Guide](../../doc/zen_query_guide.md) - Async state management
- [Main Package](../../README.md) - Full Zenify documentation

## 💡 Key Takeaways

1. **Persistence is opt-in**: Just add `persist: true` to your query config
2. **Mutations need keys**: Set `mutationKey` to enable offline queueing
3. **Optimistic updates are easy**: Use `setQueryData` in `onMutate`
4. **Network awareness is automatic**: Zenify handles online/offline transitions
5. **Storage is flexible**: Implement `ZenStorage` with any backend (Hive, SQLite, etc.)

---

**Built with Zenify v1.6.0** - [View on pub.dev](https://pub.dev/packages/zenify)
