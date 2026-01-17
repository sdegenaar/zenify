# ZenQuery Global Configuration - TanStack Query Pattern

## Overview

Zenify now implements global query configuration using the **TanStack Query QueryClient pattern**. This provides a clean, explicit, and testable way to set default options for all queries in your application.

## Key Benefits

✅ **No Mutable Global State** - Configuration is immutable after creation  
✅ **Explicit** - You see exactly where defaults come from  
✅ **Testable** - Easy to provide different clients in tests  
✅ **Scoped** - Different parts of your app can have different clients  
✅ **Industry Standard** - Matches TanStack Query's proven pattern  

## Usage

### 1. Create and Register QueryClient

```dart
import 'package:zenify/zenify.dart';

void main() {
  // Initialize Zen
  Zen.init();
  
  // Create QueryClient with your app's default options
  final queryClient = ZenQueryClient(
    defaultOptions: ZenQueryClientOptions(
      queries: ZenQueryConfig(
        staleTime: Duration.zero,        // Always refetch
        retryCount: 1,                   // Retry once
        refetchOnMount: true,
        enableBackgroundRefetch: true,
      ),
    ),
  );
  
  // Register with Zen DI
  Zen.put(queryClient);
  
  runApp(MyApp());
}
```

### 2. Queries Automatically Use Defaults

```dart
// This query will use the QueryClient defaults
final usersQuery = ZenQuery<List<User>>(
  queryKey: 'users',
  fetcher: (token) => api.getUsers(),
);

// staleTime: Duration.zero (from QueryClient)
// retryCount: 1 (from QueryClient)
```

### 3. Override Defaults for Specific Queries

Use the `copyWith` pattern to override specific fields:

```dart
// Get the client defaults
final queryClient = Zen.find<ZenQueryClient>();
final defaults = queryClient.getQueryDefaults();

// Override specific fields
final postsQuery = ZenQuery<List<Post>>(
  queryKey: 'posts',
  fetcher: (token) => api.getPosts(),
  config: defaults.copyWith(
    retryCount: 5,              // Override retryCount
    staleTime: Duration(minutes: 5), // Override staleTime
    // All other fields inherited from defaults
  ),
);
```

### 4. Alternative: Direct Config Override

You can also pass a complete config (though this won't inherit from QueryClient):

```dart
final query = ZenQuery<Data>(
  queryKey: 'data',
  fetcher: (token) => api.getData(),
  config: ZenQueryConfig(
    staleTime: Duration(hours: 1),
    retryCount: 10,
    // Uses library defaults for other fields
  ),
);
```

## Common Patterns

### Development vs Production

```dart
// Development: aggressive refetching
final devClient = ZenQueryClient(
  defaultOptions: ZenQueryClientOptions(
    queries: ZenQueryConfig(
      staleTime: Duration.zero,
      refetchOnMount: true,
      refetchOnFocus: true,
    ),
  ),
);

// Production: conservative caching
final prodClient = ZenQueryClient(
  defaultOptions: ZenQueryClientOptions(
    queries: ZenQueryConfig(
      staleTime: Duration(minutes: 5),
      cacheTime: Duration(hours: 1),
      refetchOnMount: false,
    ),
  ),
);

Zen.put(kDebugMode ? devClient : prodClient);
```

### Offline-First Apps

```dart
final offlineClient = ZenQueryClient(
  defaultOptions: ZenQueryClientOptions(
    queries: ZenQueryConfig(
      staleTime: Duration(days: 1),
      cacheTime: Duration(days: 7),
      persist: true,
      retryCount: 10,
    ),
  ),
);
```

### Real-Time Apps

```dart
final realtimeClient = ZenQueryClient(
  defaultOptions: ZenQueryClientOptions(
    queries: ZenQueryConfig(
      staleTime: Duration.zero,
      refetchOnFocus: true,
      refetchOnReconnect: true,
      enableBackgroundRefetch: true,
      refetchInterval: Duration(seconds: 30),
    ),
  ),
);
```

## Testing

In tests, you can easily provide different configurations:

```dart
testWidgets('my widget test', (tester) async {
  // Setup test-specific client
  final testClient = ZenQueryClient(
    defaultOptions: ZenQueryClientOptions(
      queries: ZenQueryConfig(
        staleTime: Duration.zero,
        retryCount: 0, // No retries in tests
      ),
    ),
  );
  
  Zen.reset();
  Zen.put(testClient);
  
  await tester.pumpWidget(MyWidget());
  // ... test assertions
});
```

## Migration from Old Pattern

If you were using the old `globalDefaults` pattern:

**Before:**
```dart
// ❌ Old pattern (mutable global state)
ZenQueryConfig.globalDefaults = ZenQueryConfig(
  staleTime: Duration.zero,
);
```

**After:**
```dart
// ✅ New pattern (immutable QueryClient)
final queryClient = ZenQueryClient(
  defaultOptions: ZenQueryClientOptions(
    queries: ZenQueryConfig(
      staleTime: Duration.zero,
    ),
  ),
);
Zen.put(queryClient);
```

## Architecture Notes

- **QueryClient** is immutable after creation
- **Defaults are resolved at query creation time**, not at runtime
- **No performance overhead** - resolution happens once during construction
- **Type-safe** - Full compile-time checking
- **Follows SOLID principles** - Dependency injection over global state

## Comparison with TanStack Query

This implementation closely mirrors TanStack Query's approach:

**TanStack Query (React):**
```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: Infinity,
    },
  },
});
```

**Zenify (Flutter):**
```dart
final queryClient = ZenQueryClient(
  defaultOptions: ZenQueryClientOptions(
    queries: ZenQueryConfig(
      staleTime: Duration(days: 365),
    ),
  ),
);
```

The patterns are nearly identical, making it easy for developers familiar with TanStack Query to adopt Zenify.
