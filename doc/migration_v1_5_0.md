# ZenQuery v1.5.0

## Breaking Changes

### RefetchBehavior Enum

**What Changed:**
Replaced `bool` refetch flags with `RefetchBehavior` enum for explicit control.

**Before (v1.4.x):**
```dart
ZenQueryConfig(
  refetchOnMount: true,      // Ambiguous: always or if stale?
  refetchOnFocus: false,
  refetchOnReconnect: true,
)
```

**After (v1.5.0):**
```dart
ZenQueryConfig(
  refetchOnMount: RefetchBehavior.ifStale,    // Explicit!
  refetchOnFocus: RefetchBehavior.never,
  refetchOnReconnect: RefetchBehavior.ifStale,
)
```

### RefetchBehavior Modes

```dart
enum RefetchBehavior {
  /// Never refetch (disabled)
  never,
  
  /// Refetch only if data is stale (default for most cases)
  ifStale,
  
  /// Always refetch, regardless of staleness
  /// NEW! Use for critical data (e.g., financial dashboards)
  always,
}
```

### Migration Guide

**Step 1: Update Config Declarations**

Find and replace in your codebase:
- `refetchOnMount: true` → `refetchOnMount: RefetchBehavior.ifStale`
- `refetchOnMount: false` → `refetchOnMount: RefetchBehavior.never`
- `refetchOnFocus: true` → `refetchOnFocus: RefetchBehavior.ifStale`
- `refetchOnFocus: false` → `refetchOnFocus: RefetchBehavior.never`
- `refetchOnReconnect: true` → `refetchOnReconnect: RefetchBehavior.ifStale`
- `refetchOnReconnect: false` → `refetchOnReconnect: RefetchBehavior.never`

**Step 2: Use New "Always" Mode (Optional)**

For critical data that must always be fresh:
```dart
ZenQuery<StockPrice>(
  queryKey: 'stock-price',
  fetcher: (_) => api.getStockPrice(),
  config: ZenQueryConfig(
    refetchOnMount: RefetchBehavior.always,  // Force refetch every time
    refetchOnFocus: RefetchBehavior.always,  // Even if data is fresh
  ),
);
```

### Why This Change?

1. **Semantic Clarity**: `true` was ambiguous - does it mean "always" or "if stale"?
2. **TanStack Query Parity**: Matches React Query v5's `refetchOnMount: "always" | boolean`
3. **New Capability**: `RefetchBehavior.always` enables force-refetch for critical data

### Default Behavior

The defaults remain the same functionally:
- `refetchOnMount`: `RefetchBehavior.ifStale` (was `true`)
- `refetchOnFocus`: `RefetchBehavior.never` (was `false`)
- `refetchOnReconnect`: `RefetchBehavior.ifStale` (was `true`)

---

## New Features

### RefetchBehavior.always

Force refetch regardless of staleness:

```dart
// Financial dashboard - always fetch latest
final portfolioQuery = ZenQuery<Portfolio>(
  queryKey: 'portfolio',
  fetcher: (_) => api.getPortfolio(),
  config: ZenQueryConfig(
    refetchOnMount: RefetchBehavior.always,
    refetchOnFocus: RefetchBehavior.always,
    staleTime: Duration(seconds: 30),  // Still caches for 30s
  ),
);
```

**Use Cases:**
- Real-time financial data
- Critical security information
- Live sports scores
- Auction/bidding systems

---

## Implementation Details

### Helper Extension

```dart
extension RefetchBehaviorX on RefetchBehavior {
  bool shouldRefetch(bool isStale) {
    switch (this) {
      case RefetchBehavior.never:
        return false;
      case RefetchBehavior.ifStale:
        return isStale;
      case RefetchBehavior.always:
        return true;
    }
  }
}
```

### Internal Changes

- Updated `ZenQueryCache._refetchOnFocus()` to use `shouldRefetch()`
- Updated `ZenQueryCache._refetchOnReconnect()` to use `shouldRefetch()`
- Updated `ZenQuery.onInit()` mount logic to use `shouldRefetch()`

---

## Testing

All 786 tests passing with new enum system.


### ZenQueryStatus & ZenMutationStatus Location

**What Changed:**
Moved `ZenQueryStatus` and `ZenMutationStatus` to `zen_query_enums.dart`.

**Impact:**
- If you import `package:zenify/zenify.dart` or `package:zenify/query/query.dart`, **no changes needed** (they are re-exported).
- If you were manually importing `zen_query_config.dart` to access `ZenQueryStatus`, you should switch to importing `zen_query_enums.dart` or the main barrel file.

---

## New Features

### 1. RefetchBehavior.always

Force refetch regardless of staleness:

```dart
// Financial dashboard - always fetch latest
final portfolioQuery = ZenQuery<Portfolio>(
  queryKey: 'portfolio',
  fetcher: (_) => api.getPortfolio(),
  config: ZenQueryConfig(
    refetchOnMount: RefetchBehavior.always,
    refetchOnFocus: RefetchBehavior.always,
    staleTime: Duration(seconds: 30),  // Still caches for 30s
  ),
);
```

### 2. Dynamic Retry Delays (retryDelayFn)

Custom logic for retries based on error types (e.g., handling Rate Limits):

```dart
ZenQueryConfig(
  retryDelayFn: (attempt, error) {
    if (error is RateLimitException) {
      return Duration(seconds: 60); // Wait 1 minute for rate limits
    }
    // Default linear backoff for other errors
    return Duration(milliseconds: 200 * (attempt + 1)); 
  },
)
```


