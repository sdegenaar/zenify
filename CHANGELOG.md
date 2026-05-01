## [1.10.2]

### Added

- `ZenInfiniteQuery.maxPages` — memory safety limit for infinite scrolling. Automatically evicts older pages from RAM when users scroll deeply, while preserving the exact cursors needed for seamless bi-directional refetching.
- `ZenMutation.anyMutating` & `ZenMutation.activeMutations` — global tracking hooks. Perfect for showing universal loading indicators or disabling navigation while mutations are actively in-flight anywhere in the app.

---

## [1.10.1]

### Added

- **`scope.require<T>({String? tag})`** — idiomatic throwing dependency lookup on `ZenScope`.
  This is the one genuinely new addition. `scope.find<T>()` is nullable (returns `T?`), which
  means `scope.find<T>()!` is a silent footgun. `scope.require<T>()` is the non-nullable,
  throwing form that surfaces a `ZenDependencyNotFoundException` with the missing type name,
  scope name, tag, and a copy-paste registration suggestion.

  ```dart
  // ❌ Before — NPE crash, no diagnostic context
  final svc = scope.find<AuthService>()!;

  // ✅ After — ZenDependencyNotFoundException with actionable message
  final svc = scope.require<AuthService>();
  ```

  > **Note**: `Zen.find<T>()` (global API) already throws when missing — it behaves like
  > `Get.find<T>()`. The new `require<T>()` is only on `ZenScope` where `find` is nullable.

- **`ZenQueryConsumer<T>`** — self-contained widget that creates, fetches, and renders a
  `ZenQuery` with no controller or module boilerplate. The `useQuery` equivalent for Zenify.

  ```dart
  // No controller. No module. One widget.
  ZenQueryConsumer<User>(
    queryKey: 'user:123',
    fetcher: (_) => api.getUser(123),
    data: (user) => UserProfile(user),
    loading: () => const CircularProgressIndicator(),
    error: (err, retry) => ErrorView(err, onRetry: retry),
  )
  ```

  Supports all `ZenQueryBuilder` features: `initialData`, `config`, `showStaleData`,
  `autoFetch`, and dynamic `queryKey` changes (disposes the old query, creates a new one).

### Docs Updated

- `doc/hierarchical_scopes_guide.md` — `ZenModule.register` examples updated to `scope.require<T>()`.
- `doc/real_world_patterns.md` — `NetworkModule` and `AuthModule` examples updated to `scope.require<T>()`.
- `doc/migration_guide.md` — DI section clarifies that `Zen.find<T>()` already throws like `Get.find<T>()`, and introduces `findOrNull<T>()` as the explicit nullable escape hatch.

### Tests

- `test/di/zen_require_test.dart` — 21 tests: `scope.require<T>()` happy path (untagged, tagged, hierarchical, lazy), error path (exception type, type name, scope name, tag, suggestion), parity with `findRequired<T>()`, disposed scope, and `Zen.find<T>()` throwing behaviour.
- `test/widgets/zen_query_consumer_test.dart` — 14 widget tests: happy path, `initialData`, loading state (custom + default), error state (custom + default + retry), idle state, `queryKey` change, disposal, config passthrough, typed generics, and barrel export smoke test.

---

## [1.10.0]

### Added
- `ZenInfiniteQuery.when()` — declarative builder for infinite-scroll UI. Handles all states (loading, error, data, loadingMore, empty) with optional `footer` slot for a "load more" trigger.
- `ZenMutation.when()` — reactive mutation state builder using `AnimatedBuilder` + `Listenable.merge`. Covers idle, loading, success, and error states with full type parameters.
- `doc/gorouter_guide.md` — comprehensive guide for integrating `ZenRoute` with GoRouter, covering nested routes, auth guards, and scope lifecycle.
- Codecov badge in README.

### Bug Fixes
These bugs were uncovered through the new test suite ("coverage-driven debugging"). All are fixed in this release.

- **`RxTransformations.skip()` never updated after creation** — the closure returned `null` without accessing `value`, so the source `Rx` was never registered as a dependency. The computed was permanently dead and would never re-evaluate when the source changed. Fixed by always accessing `value` before branching.
- **`RxTransformations.take()` lost its dependency after exhaustion** — same root cause. Fixed for consistency.
- **`RxTimingExtensions.take/skip` caused API-wide ambiguity** — `RxTimingExtensions` defined callback-style `take(int, callback)` and `skip(int, callback)` on `Rx<T>`, conflicting with `RxTransformations.take(int)` and `.skip(int)`. Dart could not resolve either name. **Renamed** to `takeFirst` / `skipFirst` — consistent with Flutter's `firstWhere`/`firstOrNull` pattern.
- **`RxTimingExtensions.map/where` caused API-wide ambiguity** — `RxTimingExtensions` defined callback-style `map(transformer, callback)` and `where(condition, callback)` on `Rx<T>`, conflicting with `RxComputedExtensions.map` / `.where` which both return computed values. **Renamed** to `listenMapped(transformer, callback)` and `listenWhere(condition, callback)` — the `listen*` prefix makes the side-effect callback intent explicit and unambiguous.
- **`RxMapExtensions.update()` was unreachable dead code** — `Rx<T>` has a class-level `update(T Function(T) updater)` that always shadows the extension method `update(K key, V Function(V), ...)`. Users could never call the map-keyed version. **Removed**; use `tryUpdate(key, fn)` directly.
- **`RxTransformations.whereNotNull()` caused ambiguity for nullable types** — conflicted with `RxNullableTransformations.whereNotNull()`. **Removed** from `RxTransformations<T>`; `RxNullableTransformations<T>.whereNotNull()` is the correct location.
- **`ZenTestMode.mockAll()` silently registers under `dynamic` (breaking change documented)** — calling `Zen.put(instance)` where `instance` is typed as `dynamic` loses the generic type parameter `T` to type erasure. All mocks were registered under `dynamic` instead of the intended interface type, making `Zen.find<T>()` always return `null` regardless of what was mocked. **Deprecated** with a clear runtime warning explaining the bug. Use chained `.mock<T>()` calls instead.
- **`ZenModuleRegistry` dead code removed** — the missing-dependency guard in `registerModules` was unreachable because `_collectAllDependencies()` already recursively resolves all transitive dependencies before the check was reached. Removed to prevent misleading error messages.
- **`ZenController.autoDispose<T>()` did not dispose handle on error** — if the callback threw an exception, the handle was orphaned. It now calls `handle.dispose()` in the catch block, consistent with the no-leak guarantee.
- **`ZenController.limited<T>()` did not dispose handle on error** — same issue. Now disposes on callback exception.

### Tests
- **Comprehensive Test Coverage**: Over **2,120+ unit and widget tests** validating core logic, widget interactions, garbage collection, and strict state invariants. Line test coverage has reached **>95.0%** overall!

### Big Fixes & Minor Tweaks

*   **Fixed Lifecycle Hook Warnings**: Resolved `mustCallSuper` lint warnings within ZenController's `onInit` and `onReady` hooks, ensuring developers properly chain initialization methods.
*   **Widget Testing Stability**: Fixed pending timer exceptions during test disposal by ensuring immediate flush of garbage collection timers within Widget tests affecting `ZenQueryBuilder`, `ZenInfiniteQuery.when()`, and cache operations.

### Dead Code Audit
As part of the final push for test coverage, we removed/ignored non-reachable safety pathways:
*   **Scope clearAll fallback**: `// coverage:ignore-line` added to the error catch inside `clearAll` since `dispose` completely swallows exceptions within ZenScope's controller array cleanup phase.  
*   **ControllerScope key update**: Standard Flutter validation (`Widget.canUpdate` verifies identical keys) effectively prevents instances with different keys from executing `didUpdateWidget`. Thus, key differences trigger complete teardowns via widget replacement rather than widget updates. This redundant internal key check inside `ZenControllerScope.didUpdateWidget` has been marked with `// coverage:ignore`.

---

## [1.9.1]

### Added
- `ZenQuery.when()` — declarative shorthand for `ZenQueryBuilder`. Supports `data`, `loading`, `error`, and `idle` builders.
- `tool/migrate_from_getx.dart` — migration script that auto-converts GetX code to Zenify (imports, controllers, `.obs` → `.obs()`, DI calls, widgets, `permanent:` → `isPermanent:`). Flags navigation, workers, and other patterns for manual review.
- GitHub Actions CI workflow (`flutter test`, `dart analyze`, format check)
- GetX migration guide (`doc/migration_guide.md`) complete rewrite with verified API examples
- README callout for GetX developers linking to the migration guide

---

## [1.9.0]

### Added
- `tags` parameter on `ZenQuery` for group-based cache management
- `ZenQueryCache.invalidateQueriesByTag(tag)` and `refetchQueriesByTag(tag)`
- `ZenQueryCache.invalidateQueriesByPattern(pattern)` and `refetchQueriesByPattern(pattern)` — supports glob-style `*` wildcards
- `ZenQueryCache.getQueriesByTag(tag)` and `getKeysByTag(tag)` for tag inspection
- `InMemoryStorage` — a built-in zero-dependency `ZenStorage` adapter for testing and ephemeral storage
- Warning log when a wildcard pattern matches all queries (e.g. `'*'`)

---

## [1.8.0]

### Breaking Changes
- Removed `ZenInspectorOverlay` widget. Remove the wrapper from your app — `Zen.init(registerDevTools: true)` continues to work as before.

```dart
// Before
runApp(ZenInspectorOverlay(child: MyApp()));

// After
runApp(MyApp()); // DevTools integration unchanged
```

### Changed
- DevTools UI moved to a separate optional package: `zenify_devtools_extension`
- Core package is ~25MB smaller as a result

---

## [1.7.0]

### Added
- Flutter DevTools extension with 3-tab inspector: Scope Inspector, Query Cache Viewer, Metrics Dashboard
- `ZenServiceExtensions` class for VM Service Protocol integration
- Automatic service extension registration via `Zen.init(registerDevTools: true)` in debug builds
- Zero performance impact in release builds

---

## [1.6.6]

### Added
- `ZenException` base class with compact (default) and verbose (`ZenConfig.verboseErrors = true`) error formatting
- Specific exception types: `ZenDependencyNotFoundException`, `ZenCircularDependencyException`, `ZenDisposedScopeException`, `ZenScopeNotFoundException`, `ZenControllerNotFoundException`, `ZenControllerDisposedException`, `ZenOfflineException`, `ZenQueryException`, `ZenMutationException`, `ZenModuleException`, `ZenLifecycleException`, `ZenRouteException`
- `ZenLogger.logException(e)` for formatted exception output
- `ZenConfig.verboseErrors` toggle

---

## [1.6.5]

### Added
- "Pending Mutations" card in DevTools Stats View
- `ZenMutationQueue.pendingCount` and `pendingJobs` for debugging
- Visual offline queue status indicator in DevTools

---

## [1.6.4]

### Added
- `ZenObserver` — alias for `Obx` widget
- `scope.get<T>()` — alias for `scope.find<T>()`
- `scope.remove<T>()` — alias for `scope.delete<T>()`
- `scope.has<T>()` — alias for `scope.exists<T>()`

---

## [1.6.3]

### Added
- `Zen.get<T>()` — alias for `Zen.find<T>()`
- `Zen.remove<T>()` — alias for `Zen.delete<T>()`
- `Zen.has<T>()` — alias for `Zen.exists<T>()`
- `Zen.queryCache` — shorthand for `ZenQueryCache.instance`

---

## [1.6.2]

### Breaking Changes
- `OptimisticMutation` renamed to `ZenMutation` (helpers are now static methods)
- `listAdd` → `listPut`, `listUpdate` → `listSet`, `add` → `put`, `update` → `set`

```dart
// Before
OptimisticMutation.listAdd<Post>(queryKey: 'posts', mutationKey: 'create', mutationFn: ...)

// After
ZenMutation.listPut<Post>(queryKey: 'posts', mutationFn: ...) // mutationKey auto-generated
```

### Changed
- `mutationKey` is now optional; auto-generated from `queryKey` if omitted

---

## [1.6.1]

### Added
- `ZenMutation.listPut<T>`, `listSet<T>`, `listRemove<T>` — optimistic list helpers with automatic rollback
- `ZenMutation.put<T>`, `set<T>`, `remove()` — optimistic single-value helpers

---

## [1.6.0]

### Added
- `ZenStorage` interface for pluggable persistence backends (SharedPreferences, Hive, SQLite, etc.)
- Auto-hydration: queries load cached data from storage on startup
- Offline mutation queue: mutations triggered while offline are queued and replayed on reconnect
- `ZenQueryCache.setQueryData()` for function-based optimistic cache updates
- `NetworkMode` enum: `online`, `offlineFirst`, `always`
- `example/zen_offline` — full offline-first example app

---

## [1.5.0]

### Breaking Changes
- `refetchOnMount`, `refetchOnFocus`, `refetchOnReconnect` changed from `bool` to `RefetchBehavior` enum

```dart
// Before
ZenQueryConfig(refetchOnMount: true)

// After
ZenQueryConfig(refetchOnMount: RefetchBehavior.ifStale)
// New option: RefetchBehavior.always — force refetch regardless of staleness
```

### Added
- `RefetchBehavior.always` for real-time/critical data use cases
- `ZenQueryConfig.retryDelayFn` — custom function for error-aware retry delays

---

## [1.4.4]

### Fixed
- `ZenInspectorOverlay` crashes when used without a `Scaffold` — replaced `ScaffoldMessenger` with internal toast system
- Layout overflows and data preview scrolling in inspector

---

## [1.4.3]

### Fixed
- `invalidate()` now automatically refetches active queries (previously only marked stale)

---

## [1.4.2]

### Changed
- Removed unnecessary type parameter from `ZenQueryClient.getQueryDefaults()`

---

## [1.4.1]

### Added
- `ZenQueryClient` and `ZenQueryClientOptions` for managing global query defaults
- `ZenQueryConfig.copyWith()` for partial config overrides

---

## [1.4.0]

### Added
- `pause()` and `resume()` methods on `ZenQuery` and `ZenStreamQuery`
- `ZenQueryConfig.autoPauseOnBackground` and `refetchOnResume`
- `ZenQueryCache.getAllQueries()` for lifecycle management
- Exponential backoff: `maxRetryDelay`, `retryBackoffMultiplier`, `retryWithJitter`

### Breaking Changes
- `ZenStreamQuery` now defaults to `autoPauseOnBackground: false` (was `true` in 1.3.x)

```dart
// To restore previous behavior
ZenStreamQuery(config: ZenQueryConfig(autoPauseOnBackground: true))
```

---

## [1.3.6]

### Fixed
- `Zen.reset()` no longer requires `testWidgets()` — works in plain `test()` blocks
- `ZenLifecycleManager` handles missing `WidgetsBinding` in test environments gracefully

---

## [1.3.5]

### Changed
- Restructured README and documentation for clarity
- Added `doc/real_world_patterns.md`

---

## [1.3.4]

### Changed
- Fixed `createController` syntax in all documentation
- Rewrote `state_management_patterns.md` with clearer examples

---

## [1.3.3]

### Fixed
- 1-pixel `RenderFlex` overflow in `ZenInspectorOverlay` on iOS/Android with no dependencies
- Improved overlay positioning with explicit `Positioned.fill`

---

## [1.3.2]

### Added
- `ZenInspectorOverlay` — in-app debug overlay with real-time scope hierarchy, query cache, and performance stats

---

## [1.3.1]

### Added
- Automatic query tracking: queries created in `onInit()` are automatically disposed when the controller closes — no `onClose()` boilerplate required

---

## [1.3.0]

### Changed
- Internal architecture refactoring: replaced `ZenScopeManager` (541 lines) and `ZenScopeStackTracker` with a single `Zen.currentScope` navigation bridge (~80% reduction in scope management code)
- `ZenRoute` reduced from 526 to 336 lines

### Added
- `parentScope` parameter on `ZenRoute` for explicit scope control

### Breaking Changes
- None. All public APIs unchanged.

---

## [1.2.3]

### Fixed
- `ZenStreamQuery` now pauses on `inactive` and `hidden` app states (web tab switching)
- Lifecycle events (`onPause`, `onResume`) now fire correctly when query is not registered in DI

---

## [1.2.2]

### Changed
- Expanded `zen_query` example app with additional features

---

## [1.2.1]

### Added
- `ZenInfiniteQuery.getPreviousPageParam()` and `fetchPreviousPage()` for bidirectional pagination
- `hasPreviousPage` and `isFetchingPreviousPage` reactive properties
- Call-time callbacks on `mutate()`: `onSuccess`, `onError`, `onSettled`
- `placeholderData` in `ZenQueryConfig` — temporary initial data that doesn't persist to cache
- `keepPreviousData` on `ZenQueryBuilder` and `ZenStreamQueryBuilder` to prevent flash-of-loading on key changes

---

## [1.2.0]

### Added
- `ZenStreamQuery` — reactive wrapper for `Stream<T>` with lifecycle management and optimistic updates
- `ZenStreamQueryBuilder` widget

### Changed
- Folder restructure: builders moved to `lib/widgets/builders/`, query internals to `lib/query/core|logic|extensions/`
- `import 'package:zenify/zenify.dart'` is unaffected

---

## [1.1.9]

### Added
- `ZenStorage` interface (foundation for 1.6.0 offline engine)
- `persist`, `fromJson`, `toJson`, `storage` options on `ZenQueryConfig`
- Auto-hydration from storage on query initialization

---

## [1.1.8]

### Breaking Changes
- Fetcher signature now requires a `ZenCancelToken` parameter

```dart
// Before
fetcher: () => api.getData()

// After
fetcher: (_) => api.getData()
```

### Added
- `ZenCancelToken` for platform-agnostic request cancellation
- Automatic cancel on dispose and on re-trigger (prevents stale data race conditions)

---

## [1.1.7]

### Added
- Smart refetching: stale queries auto-refetch on app resume and network reconnect
- `ZenQueryConfig.refetchOnFocus` and `refetchOnReconnect`
- `Zen.setNetworkStream()` for connectivity integration

### Changed
- App lifecycle observation centralized to `ZenLifecycleManager` (single observer)

---

## [1.1.6]

### Added
- `enabled` parameter and `RxBool enabled` property on `ZenQuery` for dependent queries
- `ZenQueryCache.instance.prefetch()` for pre-loading data without creating listeners

---

## [1.1.5]

### Added
- `ZenQuery.select()` — derived queries that only update when specific data changes

---

## [1.1.4]

### Added
- `ZenInfiniteQuery` for paginated lists and infinite scrolling
- `queryKey` now accepts `Object` (including `List`) in addition to `String`

---

## [1.1.3]

### Added
- `ZenMutation` for reactive write operations (create, update, delete)
- Lifecycle hooks: `onMutate`, `onSuccess`, `onError`, `onSettled`
- `ZenQueryCache.invalidateQuery()` integration pattern

---

## [1.1.2]

### Added
- `ZenScopeQueryExtension`: `scope.putQuery<T>()` and `scope.putCachedQuery<T>()`

---

## [1.1.1]

### Added
- `scope` parameter on `ZenQuery` for automatic disposal with scope lifecycle
- `ZenQueryCache.invalidateScope()`, `refetchScope()`, `clearScope()`, `getScopeQueries()`, `getScopeStats()`

---

## [1.1.0]

### Added
- `ZenQuery` — async state management with caching, deduplication, retries, and background refetch
- `ZenQueryBuilder` — reactive widget with loading/error/success states and SWR pattern
- `ZenQueryCache` — global cache manager with invalidation and memory management

---

## [1.0.1]

### Added
- `doc/testing_guide.md`

### Changed
- Removed `Zen.putFactory()` — use `Zen.putLazy(..., alwaysNew: true)` instead
- Route and controller lifecycle events now use `logInfo()` level

### Fixed
- `ZenScope.put()` default parameter handling
- Factory cleanup logic in scope disposal

---

## [1.0.0]

### Breaking Changes
- `EagerRef`, `LazyRef`, `ControllerRef`, `ZenRef` replaced by a single `Ref<T>`
- `.put()`, `.asRef()`, `.register()` extension methods removed — use `Zen.put()`
- `Zen.putFactory()` removed — use `Zen.putLazy(..., isPermanent: false)`
- Debug methods moved to `ZenDebug` class: `ZenDebug.dumpScopes()` etc.

### Added
- `Ref<T>` universal reference with `call()` shorthand
- Improved `ZenBuilder` with proper DI cleanup and ownership tracking

---

## [0.6.3]

### Added
- `ZenEnvironment.productionVerbose` environment preset
- `ZenConfig.shouldLogRoutes` and `shouldLogNavigation` helpers

---

## [0.6.2]

### Fixed
- Inverted logic in `shouldLog()` causing logs to appear when suppressed
- Rx tracking logs now respect `ZenConfig.enableRxTracking`

---

## [0.6.1]

### Breaking Changes
- `enableDebugLogs` replaced by `ZenLogLevel` enum: `none`, `error`, `warning`, `info`, `debug`, `trace`

### Added
- `ZenEnvironment` enum for type-safe environment configuration: `production`, `staging`, `development`, `debug`, `trace`, `test`

---

## [0.6.0]

### Breaking Changes
- `ZenController.onDispose()` → `onClose()`
- `ZenService.onDelete()` → `onClose()`
- `ZenScope.put()` parameter `permanent` → `isPermanent`

### Added
- Automatic `ZenService` disposal when its scope disposes

---

## [0.5.5]

### Added
- `ZenService` base class with `onInit` and `onClose` lifecycle hooks

---

## [0.5.4]

### Changed
- Updated pub.dev example application

---

## [0.5.3]

### Fixed
- Linting, formatting, and analysis issues for pub.dev score compliance

---

## [0.5.2]

### Changed
- Updated package topics for better pub.dev discoverability

---

## [0.5.1]

### Fixed
- Deprecated `RadioListTile` API usage — migrated to `RadioGroup` widget

---

## [0.5.0]

Initial pub.dev release.

---

## [0.4.1]

### Changed
- README and package metadata improvements for pub.dev

### Fixed
- `const` keyword consistency across codebase
- Documentation path corrections (`docs/` → `doc/`)

---

## [0.4.0]

### Breaking Changes
- `ZenModulePage` renamed to `ZenRoute`

### Added
- `ZenModule` base class and comprehensive module system
- `ZenRoute` widget for module-based dependency injection
- `ZenConsumer` widget for dependency access without rebuild
- Stack-based scope tracking and automatic lifecycle management

---

## [0.3.0]

### Added
- `RxResult<T>` for success/failure error handling patterns
- `RxComputed` for automatic dependency tracking
- `RxFuture` for reactive async operations
- Circuit breaker pattern for resilient reactive operations
- Batch operations and bulk updates for collections

---

## [0.2.0]

### Added
- `ZenConsumer` widget with automatic caching

---

## [0.1.9]

### Added
- Memory leak detection test suite
- Dependency resolution benchmark suite

---

## [0.1.8]

### Added
- `ZenView` base class for automatic controller management in pages

---

## [0.1.7]

### Changed
- `lookup` renamed to `find`

### Added
- `findOrNull()` for non-throwing dependency lookup
- `EagerRef` and `LazyRef` reference types

---

## [0.1.6]

### Added
- `ZenLogger` system with `debug`, `warning`, `error` levels
- Comprehensive DI test suite

---

## [0.1.5]

### Added
- Hierarchical scope system
- Circular dependency detection
- Module/binding system for organized registration
- Lazy initialization support

---

## [0.1.4]

### Added
- Generic type constraints on `RxList<E>`, `RxMap<K,V>`, `RxSet<E>`
- `ControllerRef<T>` typed provider references

---

## [0.1.3]

### Added
- `ZenEffect` for async operations with loading states
- Worker compatibility improvements

---

## [0.1.2]

### Fixed
- Minimum Dart SDK updated to 2.19.0
- Deprecated `IndexError` usage
- Collection type safety in `RxList`, `RxMap`, `RxSet`

---

## [0.1.1]

Initial release — reactive state, controller lifecycle management, route-based disposal.