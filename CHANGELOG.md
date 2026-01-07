## [1.3.4]

### Documentation

- Fixed `createController` syntax throughout all docs (correct getter returning lambda)
- Clarified that services can have reactive state for business logic
- Added controller communication patterns (shared services, static `.to` accessor, hybrid)
- Added comparison tables for common use cases (Obx vs ZenBuilder, ZenView vs ZenConsumer, etc)
- Complete rewrite of `state_management_patterns.md` with clearer examples and less repetition
- Added `ARCHITECTURE_PATTERNS.md` guide in ecommerce example

## [1.3.3]

### Bug Fixes

- **ZenInspectorOverlay**: Fixed 1-pixel RenderFlex overflow in `DependencyListView` on IOS/Android when no dependencies are present
- **ZenInspectorOverlay**: Improved overlay positioning by using explicit `Positioned.fill` for main app content instead of implicit Stack alignment, ensuring proper full-screen coverage and preventing layout ambiguity

## [1.3.2]

### Developer Tools

- **ZenInspectorOverlay**: New in-app debugging overlay with real-time scope hierarchy, query cache inspection, dependency tracking, and performance stats. Wrap your app with `ZenInspectorOverlay` to enable.

## [1.3.1]

### Automatic Query Tracking - Zero Boilerplate Memory Management

**Queries created in `onInit()` are automatically tracked and disposed - no manual cleanup needed!**

#### What Changed

- **Before**: Developers had to manually dispose each query in `onClose()`:
  ```dart
  @override
  void onClose() {
    userQuery.dispose();
    postsQuery.dispose();
    searchQuery.dispose();
    super.onClose();
  }
  ```

- **After**: Queries automatically register with their parent controller:
  ```dart
  @override
  void onClose() {
    // Queries automatically disposed! ✨
    super.onClose();
  }
  ```

#### How It Works

- When `onInit()` runs, the controller sets itself as the "current parent"
- Any `ZenQuery`, `ZenStreamQuery`, or `ZenMutation` created during `onInit()` automatically registers with the parent
- All tracked queries are automatically disposed when the controller disposes
- Works for queries created in `onInit()` or directly in the constructor

#### Benefits

- **Zero Boilerplate**: No more wrapping with `trackController()` or manual disposal
- **Prevents Memory Leaks**: Impossible to forget to dispose a query
- **Developer Friendly**: Just create queries naturally - automatic cleanup happens
- **Safe by Default**: All query types (`ZenQuery`, `ZenStreamQuery`, `ZenMutation`) auto-register

## [1.3.0]

### ♻️ Major Architecture Refactoring: Hybrid Scope Discovery

**Simplified scope management by 80% using a hybrid discovery pattern with navigation bridge.**

#### Breaking Changes

**None** - This is a pure internal refactoring. All public APIs remain unchanged.

#### Architecture Improvements

- **Hybrid Discovery Strategy**: `ZenRoute` now uses a 3-level fallback system for automatic parent resolution:
    1. **Explicit**: `parentScope` parameter for full control (e.g., clean routes)
    2. **Widget Tree**: `InheritedWidget` discovery for nested widgets in same route
    3. **Navigation Bridge**: `Zen.currentScope` pointer bridges Flutter's Navigator gap
    - Works automatically across navigation while supporting explicit control when needed

- **The Navigation Bridge**:
    - **Problem Solved**: Flutter's `Navigator.push()` creates sibling routes, breaking InheritedWidget hierarchy
    - **Solution**: Single `Zen.currentScope` pointer acts as a bridge across navigation boundaries
    - When a route creates a scope, it becomes "current"
    - Next pushed route automatically discovers it via the bridge
    - Parent scope restored as "current" on pop - automatic cleanup
    - Simple, explicit, and solves the widget tree gap with minimal code

- **Removed Global State Management (~666 lines)**:
    - **Deleted** `ZenScopeManager` (541 lines) - Complex global scope registry
    - **Deleted** `ZenScopeStackTracker` (125 lines) - Navigation-aware stack tracking
    - Eliminated 6 global tracking maps and complex lifecycle coordination
    - Replaced with single `Zen.currentScope` pointer - minimal global state

- **Simplified Core Components**:
    - `ZenRoute` reduced from 526 to 336 lines (-36%)
    - Added `parentScope` parameter for explicit control (optional)
    - `ZenScope.createChild()` no longer calls global manager
    - `ZenDebug` now uses recursive tree traversal instead of global registry
    - Lazy root scope creation in `Zen.rootScope` (lib/di/zen_di.dart)

#### Key Benefits

- ✅ **Minimal Global State**: Just one pointer bridge vs complex registry system
- ✅ **Solves Navigator Gap**: Automatically handles Flutter's route sibling architecture
- ✅ **Automatic & Explicit**: Works automatically with optional explicit control
- ✅ **Simpler Codebase**: 80% reduction in scope management complexity
- ✅ **Better Maintainability**: Clear fallback chain, easy to understand and debug
- ✅ **100% Test Coverage**: All existing tests pass, hierarchical_scopes example verified

#### Technical Details

- `_ZenScopeProvider` InheritedWidget provides scope to descendants (lib/widgets/components/zen_route.dart:304-334)
- Hybrid discovery: explicit → widget tree → navigation bridge (lib/widgets/components/zen_route.dart:116-118)
- `Zen.currentScope` set on scope creation, restored on disposal (lib/widgets/components/zen_route.dart:136, 203-206)
- Optional `parentScope` parameter for explicit control (lib/widgets/components/zen_route.dart:52)
- Updated `ZenDebug.allScopes` to use recursive tree collection (lib/debug/zen_debug.dart)

#### Documentation

- Complete rewrite of `doc/hierarchical_scopes_guide.md` explaining hybrid architecture
- Added explanation of the navigation bridge pattern
- Added examples for explicit `parentScope` usage (clean routes)
- Updated all internal documentation references

## [1.2.3]

### 🐛 Bug Fixes & Improvements

**Fixed Stream Query lifecycle behavior on Web and improved debugging visibility.**

#### Improvements

- **Web Lifecycle Fix**: `ZenStreamQuery` now correctly pauses subscriptions when the app becomes `inactive` (e.g., switching tabs on Web) or `hidden`, not just `paused`.
- **Lifecycle Propagation**: `ZenStreamQuery` now correctly triggers `onPause`, `onResume`, and other lifecycle methods even if the query instance isn't directly registered in the DI system (e.g., when used as a class member).
- **Better Logging**: Added explicit info-level logs for `inactive` and `hidden` states to make debugging stream lifecycles easier.

## [1.2.2]

### 📱 Example App Improvements

**Expanded the zen_query app with all features.**

## [1.2.1]

### 🔄 Bidirectional Pagination & Mutation Context

**Enhanced Infinite Query, smarter Mutations, and better UX controls.**

#### New Features

- **Bidirectional Infinite Query**: Added support for fetching *previous* pages.
    - `ZenInfiniteQuery` now supports `getPreviousPageParam` and `fetchPreviousPage()`.
    - Perfect for chat applications (scroll up to load history) or bidirectional lists.
    - Added `hasPreviousPage` and `isFetchingPreviousPage` reactive properties.

    ```dart
    ZenInfiniteQuery(
      queryKey: 'chat',
      infiniteFetcher: (pageParam, token) => api.getMessages(pageParam),
      getNextPageParam: (lastPage, _) => lastPage.nextCursor,
      getPreviousPageParam: (firstPage, _) => firstPage.prevCursor, // New!
    );
    ```

- **Mutation Context & Callbacks**:
    - `onMutate` can now return a context object that is passed to `onError` and `onSettled` (useful for rolling back optimistic updates).
    - **Call-Time Callbacks**: `mutate()` now accepts `onSuccess`, `onError`, and `onSettled` for one-off logic (e.g. navigation or snackbars) alongside the global definition.

- **Placeholder Data**:
    - Added `placeholderData` to `ZenQueryConfig` to show initial data while the real fetch is happening.
    - Unlike `initialData`, this does not persist to cache and is treated as temporary.

- **Builder Improvements**:
    - **`keepPreviousData`**: `ZenQueryBuilder` and `ZenStreamQueryBuilder` can now keep showing data from a previous query instance while the new one loads. This prevents "flash of loading" when changing query keys (e.g. pagination or filters).

## [1.2.0]

### 🌊 ZenStreamQuery & Project Restructuring

**Added first-class support for Streams and reorganized the project structure for better scalability.**

#### New Features

- **ZenStreamQuery**: A reactive wrapper for Streams with the same powerful API as `ZenQuery`.
    - **Real-time Data**: tailored for WebSockets, Firebase, or any `Stream<T>`.
    - **Lifecycle Management**: Automatically pauses subscriptions when the app is paused (if configured).
    - **Optimistic Updates**: Support for `setData` to manually update the stream state while waiting for events.
    - **Safe**: Handles errors and subscription cleanup automatically.

    ```dart
    final chatQuery = ZenStreamQuery(
      queryKey: 'chat-messages',
      streamFn: () => chatService.messagesStream,
    );
    ```

- **ZenStreamQueryBuilder**: A dedicated widget for handling stream states.
    - Handles `loading` (initial connection), `data` (stream events), and `error` states.
    - Smartly keeps showing data while reconnecting if available.

    ```dart
    ZenStreamQueryBuilder<List<Message>>(
      query: chatQuery,
      builder: (context, messages) => ChatList(messages),
      loading: () => const Spinner(),
      error: (err) => ErrorBanner(err),
    );
    ```

#### ♻️ Refactoring & Improvements

- **Folder Restructuring**:
    - Separated UI components from core logic for better maintainability.
    - Moved builders to `lib/widgets/builders/` (`ZenQueryBuilder`, `ZenStreamQueryBuilder`, etc.).
    - Reorganized `lib/query/` into `core/`, `logic/`, and `extensions/`.
    - **Note**: If you import specific files instead of the main package file, you may need to update your imports. Using `import 'package:zenify/zenify.dart';` remains the recommended way and requires no changes.

## [1.1.9]

### 💾 Offline Persistence Architecture

**Added foundation for persisting query state across app restarts.**

#### New Features

- **ZenStorage Interface**: Define your own storage backend (SharedPreferences, Hive, etc.) for persisting query data.
    - Implement `ZenStorage` and inject via `ZenQueryCache.instance.setStorage()`.
- **Persistence Configuration**:
    - Added `persist`, `fromJson`, `toJson`, and `storage` options to `ZenQueryConfig`.
    - `ZenQuery` now automatically hydrates from storage on initialization if configured.
    - Data is automatically persisted to storage on successful fetches.

    ```dart
    // Enable persistence
    ZenQueryConfig(
      persist: true,
      fromJson: User.fromJson,
      toJson: (user) => user.toJson(),
    )
    ```

## [1.1.8]

### 🛑 Smart Cancellation & Network Efficiency

**Introduced `ZenCancelToken` to prevent network waste and handle query cancellation gracefully.**

#### ⚠️ Breaking Changes

- **Fetcher Signature Update**:
    - `ZenQuery.fetcher` now requires a `ZenCancelToken` parameter: `(token) => ...`.
    - `ZenInfiniteQuery.infiniteFetcher` now requires a `ZenCancelToken` parameter: `(pageParam, token) => ...`.
    - **Migration**: Update your fetcher functions to accept the token argument (you can use `_` if unused).
      ```dart
      // Before
      fetcher: () => api.getData()
      
      // After
      fetcher: (_) => api.getData()
      
      ```

#### New Features

- **ZenCancelToken**: A platform-agnostic token for cancelling async operations.
    - **Universal Compatibility**: Works with `http`, `dio`, or any async library.
    - **Automatic Cleanup**: Queries automatically cancel pending requests when disposed or re-triggered.
    - **Race Condition Handling**: Prevents "old" data from overwriting "new" data if multiple fetches occur rapidly.

    ```dart
    ZenQuery(
      queryKey: 'search',
      fetcher: (token) async {
        final client = http.Client();
        // Auto-close connection if user types fast or leaves page
        token.onCancel(() => client.close()); 
        
        return api.search(term);
      },
    );
    ```

#### Improvements

- **ZenInfiniteQuery**: Enhanced cancellation support for pagination.
    - `fetchNextPage()` now correctly cancels any in-flight "next page" requests if called again.
    - Full refreshes cancel any pending pagination requests.
## [1.1.7]

### 🧠 Smart Refetching Engine

**Added lifecycle and network awareness to ZenQuery for a more robust experience.**

#### New Features

- **Smart Refetching**: Automatically keeps data fresh based on app state.
    - **Window Focus**: Refetches stale queries when the app resumes (foreground).
    - **Network Reconnect**: Refetches stale/failed queries when the device goes online.
    - **Configuration**: Controlled via `ZenQueryConfig.refetchOnFocus` and `refetchOnReconnect`.

    ```dart
    // Setup connectivity (e.g. in main.dart)
    Zen.setNetworkStream(
      Connectivity().onConnectivityChanged.map((res) => 
        !res.contains(ConnectivityResult.none))
    );
    ```

### ♻️ Architecture Improvements

- **Centralized Lifecycle Management**: Moved app lifecycle observation (pause/resume) from individual controllers to `ZenLifecycleManager`.
    - improved performance by having a single observer.
    - **Note for testing**: Controllers must now be registered via `Zen.put()` or within a `ZenScope` to receive lifecycle events (onPause, onResume, etc.). Standalone controllers in unit tests will not receive these events unless registered.
  
## [1.1.6]

### 🚀 Dependent Queries & Prefetching

**Added powerful tools for complex data flows and performance optimization.**

#### New Features

- **Dependent Queries (`enabled`)**: Control when a query should start fetching.
  - Added `enabled` parameter to `ZenQuery` constructor.
  - Added reactive `RxBool enabled` property to dynamically toggle fetching.
  - Automatically triggers fetch when `enabled` becomes `true` (if data is stale).
  - Prevents fetching when `enabled` is `false`.

    ```dart
    // Only fetch posts when user is loaded
    final postsQuery = ZenQuery(
      queryKey: ['posts', userId],
      fetcher: () => api.getPosts(userId),
      enabled: false, // Start disabled
    );
    
    // Enable later (e.g. in onInit)
    postsQuery.enabled.value = true;
    ```

- **Data Prefetching**: Pre-load data without creating listeners.
    - `ZenQueryCache.instance.prefetch()`: Fetches and caches data if stale.
    - Useful for `onHover` actions, route guards, or background sync.

  
## [1.1.5]

### 🎯 Granular Reactivity for ZenQuery

**Introduced fine-grained state management for ZenQuery to optimize performance and prevent unnecessary rebuilds.**

#### New Features

- **`ZenQuery.select()`**: Create derived queries that only update when specific data changes.
- **Performance**: Prevents widget rebuilds when unrelated fields in a large object update.
- **Composition**: Derived queries share the parent's lifecycle and state automatically.
- **Integration**: Works seamlessly with `ZenQueryBuilder` and `ZenWorkers`.

  ```dart
  // Only rebuilds when isOnline changes
  ZenQueryBuilder<bool>(
    query: userQuery.select((user) => user.isOnline),
    builder: (context, isOnline) => OnlineBadge(isOnline),
  );
  ```
  
## [1.1.4]

### ♾️ ZenInfiniteQuery & Type-Safe Keys

**Major enhancements to the ZenQuery system including first-class pagination support and type-safe keys.**

#### New Features

- **ZenInfiniteQuery**: Specialized query for handling paginated lists and infinite scrolling.
    - **Automatic Pagination**: Handles page concatenation, cursor management, and loading states.
    - **Smart Fetching**: `getNextPageParam` determines when and how to fetch the next page.
    - **Helpers**: `fetchNextPage()`, `hasNextPage`, `isFetchingNextPage` built-in.
    - **UI Ready**: Returns `List<T>` containing all loaded pages, ready for rendering.

- **Typed Query Keys**: Enhanced safety for cache keys.
    - `queryKey` now accepts `Object` instead of just `String`.
    - Support for **List Keys**: `['posts', 'user', 123]` is automatically normalized to a stable key.
    - Eliminates string interpolation bugs (e.g., `user:123` vs `user-123`).
    - Backward compatible with existing string keys.

#### Improvements

- **ZenQueryCache**: Updated internal storage to support normalized object keys.
- **ZenScopeQueryExtension**: Updated `putQuery` and `putCachedQuery` to accept `Object` keys.

## [1.1.3]

### ⚡ Complete Data Lifecycle with ZenMutation

**Added support for reactive write operations to complement ZenQuery**

#### New Features

- **ZenMutation**: A new reactive primitive for handling side effects (create, update, delete operations)
    - Separates Command (Write) from Query (Read) responsibilities
    - **Lifecycle Hooks**: `onMutate` (for optimistic updates), `onSuccess`, `onError`, and `onSettled`
    - **Reactive State**: Built-in `isLoading`, `isSuccess`, `isError`, and `data` state
    - **Cache Integration**: Designed to easily trigger `ZenQueryCache.invalidateQuery` for data consistency

#### Documentation

- Added complete **Mutations** section to `zen_query_guide.md`
- Added quick-start example for ZenMutation in `README.md`
- Documented optimistic update patterns and cache invalidation strategies

## [1.1.2]

### 🎯 API Enhancement: Scoped Query Creation

**Simplified pattern for creating scoped queries in modules**

#### New Features

- **ZenScopeQueryExtension**: Added convenient extension methods for scoped query creation
    - `scope.putQuery<T>()` - Create and register scoped query in one call
    - `scope.putCachedQuery<T>()` - Create scoped query with common caching defaults
    - Automatic scope binding and registration
    - Consistent with existing `scope.put()` / `scope.putLazy()` API pattern

#### Improvements

- Reduced boilerplate when creating scoped queries in modules
- Eliminated common mistakes (forgetting to set scope, forgetting to register)
- Enhanced documentation with recommended patterns for scoped queries
- Updated ZenQuery Guide with `putQuery` examples

#### Documentation

- Comprehensive documentation in `zen_query_guide.md` for both global and scoped patterns

## [1.1.1]

### 🚀 Scope-Aware ZenQuery
**ZenQuery now supports optional scope integration for automatic lifecycle management**

#### New Features

- **Scope Integration**: Tie queries to scopes for automatic disposal
    - Pass `scope` parameter to bind query to a specific scope
    - `autoDispose` flag controls automatic cleanup behavior
    - Queries auto-dispose when their scope disposes (prevents memory leaks)

- **Scope Operations**: Bulk operations on scoped queries
    - `ZenQueryCache.invalidateScope(scopeId)` - Invalidate all queries in scope
    - `ZenQueryCache.refetchScope(scopeId)` - Refetch all queries in scope
    - `ZenQueryCache.clearScope(scopeId)` - Clear all queries from scope
    - `ZenQueryCache.getScopeQueries(scopeId)` - Get all queries in scope
    - `ZenQueryCache.getScopeStats(scopeId)` - Get scope query statistics

- **Enhanced Cache Statistics**: Differentiate global vs scoped queries
    - `global_queries` count
    - `scoped_queries` count
    - `active_scopes` count

#### Key Advantages

- ✅ **Automatic cleanup** - Queries dispose with their scope (no memory leaks)
- ✅ **Cache isolation** - Feature modules have isolated query caches
- ✅ **Flexible** - Choose global or scoped based on use case
- ✅ **Backward compatible** - Existing queries work without changes (default to global)


## [1.1.0]

### 🚀 Major Feature: ZenQuery System

**Async state management inspired by React Query and TanStack Query**

#### New Features
- **ZenQuery**: Smart query management with automatic caching, deduplication, and background refetching
    - Automatic request deduplication (same query key = single request)
    - Configurable stale time and cache time
    - Automatic retries with exponential backoff
    - Background refetching on configurable intervals
    - Optimistic updates support
    - Query invalidation and cache management

- **ZenQueryBuilder**: Reactive widget for query-driven UI
    - Auto-fetch on mount
    - Show stale data while refetching (SWR pattern)
    - Built-in loading, error, and success states
    - Automatic retry functionality
    - Custom state builders

- **ZenQueryCache**: Global cache manager
    - Query registration and lifecycle management
    - Cache invalidation by key or prefix
    - Bulk query refetching
    - Memory management with automatic cleanup
    - Cache statistics and debugging

#### Key Advantages Over Alternatives
- ✅ **10x simpler** for async data
- ✅ **Automatic caching** with smart defaults
- ✅ **Built-in retry logic** with exponential backoff
- ✅ **Zero boilerplate** for common patterns
- ✅ **Production-ready** with comprehensive error handling

## [1.0.1]

### Added
- Added comprehensive testing guide (`doc/testing_guide.md`) with examples for unit, widget, and integration testing

### Changed
- Simplified factory pattern API - removed `Zen.putFactory()`, use `Zen.putLazy(..., alwaysNew: true)` instead
- Enhanced `putLazy()` with `alwaysNew` parameter for factory pattern support
- Improved logging - route and controller lifecycle events now use `logInfo()` for better visibility

### Fixed
- Fixed `ZenScope.put()` default parameter handling
- Fixed factory cleanup logic in scope disposal

---

## [1.0.0] 

### 🎉 Major Release - API Simplification

Simplified API by 40% while maintaining 100% of the power. **One obvious way to do it.**

### ⚠️ Breaking Changes

#### Unified References
- **Removed**: `EagerRef`, `LazyRef`, `ControllerRef`, `ZenRef` class
- **Added**: Single `Ref<T>` for all use cases
```dart 
// Before 
final ref = ZenRef.eager();
// Now 
final ref = Ref();
```

#### Removed Extension Methods
- **Removed**: `.put()`, `.asRef()`, `.register()` extensions
- **Use**: `Zen.put()` for all registrations
```
// Before 
myService.put(tag: 'main');
// Now 
Zen.put(myService, tag: 'main');
``` 

#### Simplified API
- **Removed**: `Zen.putFactory()` - use `Zen.putLazy(..., isPermanent: false)`
- **Moved**: Debug methods to `ZenDebug` class

```
// Before
Zen.dumpScopes();

// Now
ZenDebug.dumpScopes();
```

### ✨ New Features

- **`Ref<T>`**: Universal reference with `call()` shorthand: `ref()` = `ref.find()`
- **ZenBuilder**: Proper DI cleanup, ownership tracking, smart disposal defaults
- **Module System**: Fail-fast with clearer error messages
- **Barrel Exports**: Clean package structure with logical grouping

### 🔧 Improvements

- Better error messages with scope context
- `ZenBuilder` removes controllers from DI on disposal
- Organized exports - internal details hidden

### 🐛 Bug Fixes

- Fixed `ZenBuilder` not removing controllers from DI
- Fixed module rollback leaving inconsistent state
- Fixed reactive exports including internals
- Fixed circular import issues

### 📚 Quick Migration

1. Replace `EagerRef/LazyRef/ControllerRef` → `Ref`
2. Replace `.put()/.asRef()` → `Zen.put()`
3. Replace `Zen.putFactory()` → `Zen.putLazy(..., isPermanent: false)`
4. Replace `Zen.debug*()` → `ZenDebug.*()`

### ✅ What Stays the Same

All core features preserved: hierarchical scopes, lazy loading, tagged dependencies, modules, reactive system, workers, effects, testing, debugging.

---


## 0.6.3

### 🎯 Logging Improvements

#### New Features
- **New Environment**: `ZenEnvironment.productionVerbose` - warnings + errors with performance metrics
- **Smart Log Helpers**: `ZenConfig.shouldLogRoutes` and `ZenConfig.shouldLogNavigation`
- **Better Log Levels**: Controller lifecycle events now use appropriate levels (info vs debug)

#### Improvements
- Route/navigation logging now properly controlled by environment settings
- Log levels respect both flags AND global log level configuration
- Enhanced `toMap()` includes all computed properties for debugging
- Test environment uses longer disposal timeout (10s) for stability

## [0.6.2] 

### Fixed
- **Log Level Filtering**: Fixed inverted logic in `shouldLog()` method that caused logs to appear even when log level was set to suppress them
- **Rx Tracking Logs**: Rx widget tracking logs now properly respect `ZenConfig.enableRxTracking` flag instead of always showing in debug mode
    - Changed Obx widget debug logs to use `logRxTracking()` for proper control
    - Debug mode now shows general debug logs but hides Rx tracking logs as documented
    - Trace mode shows all logs including Rx tracking logs as documented

### Improved
- Log level configuration now works correctly across all environments (production, staging, development, debug, trace, test)
- Better separation between general debug logging and verbose Rx tracking logging


## 0.6.1

### 🎯 Comprehensive Logging System Enhancement

#### Breaking Changes
- **Replaced simple `enableDebugLogs` with granular `ZenLogLevel` enum**
    - `ZenLogLevel.none` - No logging (silent)
    - `ZenLogLevel.error` - Only errors (recommended for production)
    - `ZenLogLevel.warning` - Errors and warnings (recommended for production)
    - `ZenLogLevel.info` - General information (recommended for development)
    - `ZenLogLevel.debug` - Detailed debug info (for development)
    - `ZenLogLevel.trace` - Very verbose including internals (debugging only)

#### New Features

**Type-Safe Environment Configuration**
- Added `ZenEnvironment` enum for type-safe environment configuration
- Prevents typos and provides IDE autocomplete
- Supports aliases: 'prod' → production, 'dev' → development, 'stage' → staging
- Backward compatible with string-based configuration

**Available Environments:**
- `ZenEnvironment.production` - Minimal logging, no debug features
- `ZenEnvironment.staging` - Moderate logging, performance metrics
- `ZenEnvironment.development` - Detailed logging, all debug features
- `ZenEnvironment.debug` - Very detailed logging with strict mode
- `ZenEnvironment.trace` - Extreme verbosity including Rx tracking
- `ZenEnvironment.test` - Optimized for testing (no auto-dispose)

#### Code Cleanup
- Removed all deprecated `ZenConfig.enableDebugLogs` checks throughout codebase
- Integrated `RxLogger` with `ZenLogger` to respect `ZenConfig.logLevel`
- Simplified logging calls by removing redundant conditional checks
- Improved consistency between core and reactive logging systems
- All logging now properly respects the unified `ZenLogLevel` system

## 0.6.0

### 🚨 BREAKING CHANGES
- **Lifecycle Standardization**: Renamed lifecycle methods for consistency
    - `ZenController.onDispose()` → `ZenController.onClose()`
    - `ZenService.onDelete()` → `ZenService.onClose()`
- **API Consistency**: `ZenScope.put()` parameter `permanent` → `isPermanent`

### ✨ New Features
- **Automatic ZenService Disposal**: Services are automatically disposed when their scope is disposed (promotes proper scope design)
- **Enhanced ZenService Integration**: `ZenScope` now matches `Zen` API behavior for services
- **Smart Defaults**: ZenService instances default to permanent across all registration methods

### 🔧 Improvements
- Consistent lifecycle pattern: `onInit()` → `onClose()` → `dispose()`
- ZenService instances properly initialize from lazy factories
- Complete disposal coverage in all scope cleanup operations

### 🔄 Migration Guide
```
// Lifecycle methods
@override void onDispose() → @override void onClose()
@override void onDelete() → @override void onClose()

// Scope registration
scope.put(service, permanent: true) → scope.put(service, isPermanent: true)
```

### 📝 Internal Changes
- **Restructured ZenService disposal**: Added internal `dispose()` method that calls user's `onClose()`
- **Improved separation of concerns**: Clear distinction between user cleanup (`onClose()`) and framework disposal (`dispose()`)
- Updated all examples and documentation to use new lifecycle methods
- Enhanced error messages to reference correct method names

## 0.5.5
* **🆕 ZenService (long‑lived services)**
    * Adds `ZenService` base with `onInit` and `onClose` lifecycle hooks
    * Safe init: `isInitialized` set only after successful `onInit`
    * Guaranteed cleanup via `onDelete` → `onClose`

- **🧩 DI behavior and consistency**
    * `Zen.put(instance)`: `ZenService` defaults to `isPermanent = true` and initializes via lifecycle manager
    * `Zen.putLazy(factory)`: explicit permanence (default `false`); instance created on first `find()`
    * `Zen.putFactory(factory)`: unchanged; always creates new instances
    * `Zen.find()`: auto‑initializes `ZenService` on first access (covers lazy/scoped resolutions)

- **✅ Compatibility**
    * No changes to behavior `ZenController`
    * Works across scopes and modules with consistent lifecycle handling

- **🧪 Tests**
    * Added unit/integration tests for service init/disposal, lazy resolution, and error handling

- **📝 Docs**
    * Updated guidance on services vs controllers, permanence defaults, and initialization semantics

## 0.5.4

* **📱 Pub.dev Example Improvements**
    * Updated example application displayed on pub.dev package page
    * Cleaner code structure and improved readability for new users
    * Better demonstration of ZenView and reactive state patterns

## 0.5.3

* **🏆 Perfect pub.dev Package Score Achievement (160/160)**
    * Achieved maximum possible pub.dev score: 160/160 points
    * **Static Analysis (50/50)**: Fixed all linting issues and code formatting problems
    * **Documentation (10/10)**: Comprehensive README and API documentation maintained
    * **Example (30/30)**: Added complete example application demonstrating all features
    * **Maintenance (70/70)**: Up-to-date dependencies and Flutter compatibility
    * Fixed code formatting issues across the entire codebase using `dart format`
    * Added missing curly braces around single-line if statements for better code style
    * Improved documentation comments formatting to prevent HTML interpretation warnings
    * Enhanced code consistency by enforcing `curly_braces_in_flow_control_structures` rule
    * Updated analysis configuration to match pub.dev standards for optimal package quality
    * Ensured example application meets pub.dev requirements for discoverability and usability

## 0.5.2

* **📦 Package Metadata Improvements**
    * Updated topics to use `hierarchical-dependency-injection` for better discoverability
    * Improved SEO for dependency injection searches while highlighting hierarchical approach
    * Enhanced pub.dev searchability and positioning

## 0.5.1

* **🐛 Bug Fixes and Compatibility Improvements**
    * Fixed deprecated `RadioListTile` `groupValue` and `onChanged` parameters
    * Migrated to `RadioGroup` widget for radio button group management (Flutter 3.32.0+ compatibility)
    * Enhanced radio button implementation following Flutter's latest best practices

## 0.5.0

* **🚀 Official pub.dev Release**
    * Published Zenify to pub.dev as a stable pre-release package
    * Updated installation instructions to use `zenify: ^0.5.0` from pub.dev
    * Enhanced package description for better discoverability
    * Added comprehensive pub.dev metadata (topics, platforms, documentation links)
    * Prepared package for wider Flutter community adoption


## 0.4.1

* Documentation and Publishing Preparation
    * Polish README.md with improved formatting and comprehensive content
    * Enhance installation instructions and quick start guide
    * Add comprehensive feature highlights and comparison guidance
    * Refine documentation structure with "Coming Soon" sections for planned content
    * Update community links and support channels
    * Prepare package metadata for pub.dev publishing
* Code Quality and Performance Improvements
    * Add `const` keyword for durations and widgets across files for consistency
    * Apply `const` to widget declarations where applicable to reduce rebuilds
    * Fix minor typos in documentation paths from `docs/` to `doc/`
    * Improve code clarity and conformance with modern Dart guidelines
* Package Configuration Updates
    * Refine `pubspec.yaml` description for better pub.dev presentation
    * Update Flutter SDK constraint for compatibility
    * Adjust dependencies for optimal package setup


## 0.4.0

* Major Enhancement: Complete Module System and Route Management
    * **BREAKING**: Rename ZenModulePage to ZenRoute for clarity and better naming
    * Implement comprehensive hierarchical module system with ZenModule base class
    * Add ZenRoute widget for seamless module-based dependency injection
    * Implement stack-based scope tracking for reliable parent resolution
    * Add automatic scope cleanup and lifecycle management
    * Implement smart auto-dispose defaults based on scope hierarchy
    * Add comprehensive error handling with layout-aware loading/error states
    * Implement ZenScopeStackTracker for hierarchical scope inheritance
    * Add ZenScopeManager for centralized scope lifecycle management
    * Implement proper Zen.currentScope synchronization throughout navigation
    * Add comprehensive logging and debug support for scope operations
    * Implement robust parent scope resolution with multiple fallback strategies
    * Add comprehensive example applications (ecommerce, todo, showcase)
    * Restructure documentation with complete guides and improved examples
    * Add ZenConsumer widget for efficient dependency access with automatic caching
    * Implement production-ready module registration and cleanup patterns

## 0.3.0

* Major Enhancement: Production-Ready Reactive System
    * Complete reactive state management system with comprehensive error handling
    * Add RxResult<T> for robust error handling with success/failure patterns
    * Implement RxException with timestamp tracking and error context
    * Add RxComputed for automatic dependency tracking and computed values
    * Implement RxFuture for reactive async operations with state management
    * Add comprehensive error handling extensions for all reactive types
    * Implement circuit breaker pattern for resilient reactive operations
    * Add RxLogger with configurable error handling and context tracking
    * Implement extensive list extensions with safe operations and error handling
    * Add batch operations and bulk update support for collections
    * Implement retry logic with configurable delays and attempt limits
    * Add performance monitoring utilities and resource leak detection
    * Implement comprehensive test coverage for all reactive components
    * Add production-ready error configuration and logging systems
    * Implement automatic dependency cleanup and memory management
    * Add type-safe reactive operations with compile-time guarantees

## 0.2.0

* Major Enhancement: Widget System Expansion and Performance Optimization
    * Add ZenConsumer widget for efficient dependency access with automatic caching
    * Add comprehensive test suite for ZenConsumer widget functionality
    * Enhance widget system documentation with complete comparison table
    * Add examples demonstrating ZenConsumer for optional services and dependencies
    * Improve README with detailed widget selection guidelines and best practices
    * Add performance-optimized patterns for different UI scenarios
    * Update migration guide with widget system improvements

## 0.1.9

* Enhanced Testing and Logging Infrastructure
    * Add comprehensive memory leak detection test suite with tracking utilities
    * Implement resource lifecycle monitoring for controllers, scopes, and services
    * Add stress tests for rapid creation/disposal scenarios
    * Implement dependency resolution benchmark suite for performance monitoring
    * Add widget lifecycle tests with safe ZenView implementation patterns
    * Enhance error handling in test teardown processes
    * Add performance monitoring utilities with operations-per-second metrics
    * Improve test coverage for module registration and cleanup
    * Add hierarchical scope disposal verification tests
    * Implement batch operations benchmarking for large-scale dependency management

## 0.1.8

* Major Enhancement: ZenView Integration and Widget System
    * Add ZenView base class for automatic controller management in pages
    * Implement direct controller access pattern (controller.property)
    * Add ZenViewRegistry for controller lifecycle management
    * Introduce context extensions for nested widget controller access
    * Replace manual Zen.find() pattern with automatic binding
    * Add comprehensive ZenView examples and patterns
    * Improve error handling with clear controller availability messages
    * Update documentation with ZenView best practices
    * Add support for tagged controllers in ZenView
    * Enhance type safety with automatic controller resolution

## 0.1.7

* Complete Phase 4: API Consistency and Reference System Improvements
    * Rename `lookup` to `find` for more intuitive API
    * Add `findOrNull` method for non-throwing dependency lookup
    * Enhance reference system with `EagerRef` and `LazyRef` implementations
    * Improve error handling in ZenView for better debugging
    * Refine scope management in widget integration
    * Update examples to use new API methods
    * Fix dependency resolution in hierarchical scopes

## 0.1.6

* Complete Phase 3: Logging and Testing Improvements
    * Replace print statements with structured ZenLogger system
    * Add proper log levels (debug, warning, error) for better debugging
    * Add comprehensive tests for dependency injection functionality
    * Implement test helpers for isolated scope testing
    * Add integration tests for scoped dependencies
    * Improve error handling with descriptive messages

## 0.1.5

* Complete Phase 2: Dependency Management Improvements
    * Implement hierarchical scope system for nested controller access
    * Add circular dependency detection to prevent deadlocks
    * Create module/binding system for organized dependency registration
    * Enhance controller discovery with improved scoping
    * Add lazy initialization support for dependencies
    * Improve error reporting for dependency resolution issues

## 0.1.4

* Complete Phase 1: Enhanced Type Safety
    * Add generic type constraints to all collections (RxList<E>, RxMap<K,V>, RxSet<E>)
    * Implement typed provider references with ControllerRef<T>
    * Add compile-time type checking for controller dependencies
    * Ensure type safety throughout reactive system and DI container

## 0.1.3

* Add ZenEffect for handling async operations with loading states
* Improve worker compatibility with proper RxNotifier types
* Fix type compatibility issues between RxInt and RxNotifier
* Add examples demonstrating async effects and reactive data flows
* Enhance documentation for state bridging patterns

## 0.1.2

* Update minimum Dart SDK to 2.19.0
* Fix deprecated IndexError usage with IndexError.withLength
* Improve logging system with developer.log instead of print statements
* Fix collection implementations for better type safety
* Add missing implementations in RxList, RxMap, and RxSet classes

## 0.1.1

* Initial release
* Core state management features
* Reactive state with Rx objects
* Controller lifecycle management
* Route-based controller disposal