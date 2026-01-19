# ZenQuery Complete Example

A comprehensive demonstration of **Zenify's ZenQuery** system - a powerful async state management solution for Flutter inspired by React Query.

## Overview

This example showcases all ZenQuery features through an interactive, multi-tab application. Each tab demonstrates a different aspect of the query system with real-world use cases.

## Features Demonstrated

### 1. Query Basics Tab 📊
Demonstrates core ZenQuery functionality:

- **Basic Queries**: Simple data fetching with automatic caching
- **Loading States**: Built-in loading, error, and success state management
- **Stale Time**: Configure how long data stays fresh
- **Cache Time**: Control how long data persists in cache
- **Refetching**: Manual and automatic data refetching
- **Invalidation**: Mark queries as stale to trigger refetch
- **Retry Logic**: Automatic retry with exponential backoff
- **Placeholder Data**: Show temporary data while loading
- **Query Status**: Real-time query state tracking

**Key Code:**
```dart
final userQuery = ZenQuery<User>(
  queryKey: 'user:1',
  fetcher: (token) => ApiService.getUser(1, cancelToken: token),
  config: const ZenQueryConfig(
    staleTime: Duration(seconds: 30),
    cacheTime: Duration(minutes: 5),
    retryCount: 3,
    exponentialBackoff: true,
  ),
);
```

### 2. Mutations Tab ✏️
Demonstrates data modification operations:

- **Create Operations**: Add new data with `ZenMutation`
- **Update Operations**: Modify existing data
- **Delete Operations**: Remove data with cleanup
- **Optimistic Updates**: Instant UI updates before server confirmation
- **Lifecycle Callbacks**: `onMutate`, `onSuccess`, `onError`, `onSettled`
- **Error Rollback**: Revert optimistic updates on failure
- **Query Invalidation**: Auto-refresh related queries after mutations

**Key Code:**
```dart
final updateMutation = ZenMutation<Post, UpdatePostRequest>(
  mutationFn: (request) => ApiService.updatePost(request),
  onMutate: (request) {
    // Store old data and update UI optimistically
    final oldPost = query.data.value;
    query.setData(oldPost.copyWith(title: request.title));
    return oldPost; // Context for rollback
  },
  onSuccess: (updatedPost, _, __) {
    query.setData(updatedPost); // Update with real data
  },
  onError: (error, _, context) {
    query.setData(context as Post); // Rollback on error
  },
);
```

### 3. Infinite Query Tab 📜
Demonstrates pagination and infinite scrolling:

- **ZenInfiniteQuery**: Specialized query for paginated data
- **Automatic Scroll Detection**: Load more on scroll
- **Page Management**: Track loaded pages and merge results
- **hasNextPage/hasPreviousPage**: Navigation state tracking
- **Pull to Refresh**: Refresh all pages
- **Loading States**: Separate loading for next page
- **Pagination Stats**: Real-time page count and totals

**Key Code:**
```dart
final infiniteQuery = ZenInfiniteQuery<PaginatedResponse<Post>>(
  queryKey: 'posts:infinite',
  infiniteFetcher: (pageParam, cancelToken) async {
    final page = pageParam as int? ?? 1;
    return await ApiService.getPosts(page: page, pageSize: 10);
  },
  getNextPageParam: (lastPage, allPages) {
    return lastPage.hasMore ? lastPage.page + 1 : null;
  },
  initialPageParam: 1,
);
```

### 4. Stream Query Tab 🌊
Demonstrates real-time data updates:

- **ZenStreamQuery**: Reactive stream wrapper
- **Auto Subscription**: Automatic stream lifecycle management
- **Multiple Streams**: Handle concurrent real-time data sources
- **Live Updates**: Real-time UI updates as data streams in
- **Subscribe/Unsubscribe**: Manual stream control
- **Error Handling**: Graceful stream error recovery

**Key Code:**
```dart
final notificationStream = ZenStreamQuery<String>(
  queryKey: 'notifications:live',
  streamFn: () => ApiService.getNotificationStream(),
);

// Automatically subscribes and updates UI on new data
ZenQueryBuilder<String>(
  query: notificationStream,
  builder: (context, notification) => Text(notification),
);
```

### 5. Advanced Features Tab 🚀
Demonstrates advanced patterns:

- **Query Selection**: Derive queries from existing queries
  ```dart
  final emailQuery = userQuery.select((user) => user.email);
  ```

- **Dependent Queries**: Chain queries that depend on each other
  ```dart
  final postsQuery = ZenQuery(
    queryKey: 'posts:user',
    fetcher: (token) => ApiService.getPosts(userId: userQuery.data.value!.id),
    enabled: false, // Enable after user loads
  );
  ```

- **Conditional Queries**: Enable/disable queries dynamically
  ```dart
  final searchQuery = ZenQuery(
    queryKey: 'users:search',
    fetcher: (token) => ApiService.getUsers(search: searchTerm.value),
    enabled: false, // Only enable when user wants to search
  );
  ```

- **Cancellation**: Cancel in-flight requests
  ```dart
  fetcher: (token) async {
    await Future.delayed(Duration(seconds: 3));
    if (token.isCancelled) {
      throw ZenCancellationException('Cancelled');
    }
    return data;
  }
  ```

- **Deduplication**: Multiple simultaneous requests share one fetch
  ```dart
  // All 5 fetches will share a single network request
  for (var i = 0; i < 5; i++) {
    query.fetch();
  }
  ```

## Running the Example

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)

### Steps

1. **Navigate to the example directory:**
   ```bash
   cd example/zen_query
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   # For web
   flutter run -d chrome

   # For mobile
   flutter run

   # For desktop
   flutter run -d macos   # or windows, linux
   ```

## Project Structure

```
lib/
├── main.dart                          # App entry point with tabbed navigation
├── models/
│   └── models.dart                   # Data models (User, Post, Comment, etc.)
├── services/
│   └── api_service.dart              # Mock API service with realistic delays
└── pages/
    ├── query_basics_page.dart        # Basic ZenQuery features
    ├── mutation_page.dart            # Mutation operations
    ├── infinite_query_page.dart      # Pagination and infinite scroll
    ├── stream_query_page.dart        # Real-time stream handling
    └── advanced_features_page.dart   # Advanced patterns
```

## Key Concepts

### Query Keys
Query keys uniquely identify queries for caching and deduplication:
```dart
queryKey: 'user:1'              // Simple string
queryKey: ['posts', userId]     // Typed list (serialized internally)
```

### Query States
Queries have four states:
- **idle**: Not yet fetched
- **loading**: Currently fetching
- **success**: Data available
- **error**: Fetch failed

### Cache Management
```dart
// Get cache statistics
final stats = Zen.queryCache.getStats();

// Invalidate a query (mark as stale)
query.invalidate();

// Clear entire cache
Zen.queryCache.clear();
```

### Configuration
Global and per-query configuration:
```dart
// Global defaults
ZenQueryConfig.defaults = ZenQueryConfig(
  staleTime: Duration(minutes: 5),
  cacheTime: Duration(minutes: 30),
);

// Per-query config
ZenQuery(
  config: ZenQueryConfig(
    staleTime: Duration(seconds: 30),
    retryCount: 3,
    refetchOnMount: true,
    refetchOnFocus: true,
  ),
);
```

## Mock API

The example includes a realistic mock API (`ApiService`) that simulates:
- Network delays (500-1500ms)
- Random failures (5-10% error rate)
- Pagination support
- Stream endpoints
- CRUD operations

This allows you to see how ZenQuery handles real-world scenarios like:
- Slow networks
- Request failures
- Race conditions
- Concurrent requests

## Best Practices

1. **Use Descriptive Keys**: Include parameters in query keys
   ```dart
   queryKey: ['posts', userId, filter, page]
   ```

2. **Configure Stale Time**: Balance freshness with performance
   ```dart
   staleTime: Duration(minutes: 5)  // Data fresh for 5 minutes
   ```

3. **Handle Cancellation**: Always check cancellation tokens
   ```dart
   if (token.isCancelled) throw ZenCancellationException('Cancelled');
   ```

4. **Optimize Updates**: Use optimistic updates for better UX
   ```dart
   onMutate: (vars) {
     query.setData(optimisticData);
     return oldData; // For rollback
   }
   ```

5. **Invalidate After Mutations**: Keep queries in sync
   ```dart
   onSuccess: (data, _, __) {
     relatedQuery.invalidate();
   }
   ```

## Learn More

- **Main Documentation**: See `/doc` folder in the root project
- **API Reference**: Check the Zenify package documentation
- **Source Code**: Explore the `/lib/query` directory
- **Tests**: Review `/test/query` for usage examples

## Troubleshooting

### Query not fetching?
- Check if `enabled` is set to `true`
- Verify `refetchOnMount` configuration
- Ensure the fetcher doesn't throw immediately

### Data not updating?
- Check if data is stale (`isStale` property)
- Call `refetch()` or `invalidate()` to force update
- Verify mutation callbacks are triggering

### Memory leaks?
- Always dispose queries in `onClose()`
- Use `autoDispose: true` for scoped queries
- Check for circular dependencies

## Contributing

Found a bug or want to improve the example? Contributions are welcome!

## License

This example is part of the Zenify package and follows the same license.
