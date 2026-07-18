# Zenify V2: Code & API Cleanup Notes

> Deep-dive review findings. Covers bloat, dead API surface, and architectural misalignment.  
> Status: **Discussion / Planning** — no changes made yet.

---

## 🔴 Priority 1 — `ZenRouteObserver` (Architectural Dead Weight)

**File:** `lib/controllers/zen_route_observer.dart`  
**Exported in:** `lib/zenify.dart`

### The Problem

`ZenRouteObserver` is a `NavigatorObserver` that lets you manually map route names to controller types for auto-disposal on pop/remove. This was an appropriate pattern in V1, where a mutable `Zen.currentScope` global pointer existed.

**In V2 it directly contradicts our core identity.** V2's entire value proposition is that `ZenRoute` handles lifecycle automatically because it is a `StatefulWidget` whose `dispose()` cascades down the `InheritedWidget` scope tree. `ZenRouteObserver` reintroduces the very kind of global route-to-controller tracking that V2 was designed to eliminate.

### Evidence of Misalignment

- Only used in `example/hierarchical_scopes_flat/lib/main.dart`
- Not used in the canonical `hierarchical_scopes_nested` example
- Not used in `ecommerce`, `todo`, or `zen_query` examples
- Its own scope-cleanup heuristic (`_isRouteSpecificScope`) uses a string `.contains()` check — a code smell

### What to Do

```
Short term: Add @Deprecated annotation pointing to ZenRoute
Long term:  Remove in a future minor version
```

```dart
@Deprecated(
  'Use ZenRoute instead. ZenRouteObserver relies on manual route-to-controller '
  'mapping and contradicts V2\'s automatic InheritedWidget-based lifecycle. '
  'ZenRoute disposes its scope automatically when the widget leaves the tree.',
)
class ZenRouteObserver extends NavigatorObserver { ... }
```

> **Note:** The `V2_SCOPE_ARCHITECTURE.md` doc already explicitly calls out why `NavigatorObserver` is a trap. `ZenRouteObserver` is that trap.

---

## 🟡 Priority 2 — `ZenControllerAdvancedExtension` (Over-engineered, Zero Real Usage)

**File:** `lib/controllers/zen_controller.dart` (lines ~913–959)  
**Methods:** `autoDispose<T>()`, `limited<T>()`

### The Problem

These two methods only appear in test files. They are never used in any example application. Both are trivially composable using the existing `ever()` and `once()` primitives that developers already understand:

```dart
// What limited() does — readable inline with existing API:
int count = 0;
ever(myObs, (val) {
  if (++count >= 3) handle.dispose();
  doSomething(val);
});
```

Adding them to the public API surface of the most-used class in the package (`ZenController`) raises the cognitive overhead for every new user reading the docs without solving any real problem.

### What to Do

Option A — Remove from public API, keep as internal test helpers  
Option B — Mark `@visibleForTesting` to signal they are non-production  
Option C — Remove entirely (they are 47 lines, easy to recreate if needed)

**Recommendation: Option C.** If a user genuinely needs this pattern, the two-line inline equivalent is cleaner than a named method they have to look up.

---

## 🟡 Priority 3 — `_estimateMemoryUsage()` (Theatre, Not Science)

**File:** `lib/controllers/zen_controller.dart` (lines ~576–607)  
**Exposed via:** `getResourceStats()` map key `memory_overhead_estimate`

### The Problem

The method uses hardcoded "magic number" byte estimates:
```dart
final reactiveSize = _reactiveObjects.length * 100;  // "~100 bytes each"
final workersSize  = _workers.length * 100;          // "~100 bytes each"
final effectsSize  = _effects.length * 150;          // "~150 bytes each"
// etc.
```

These numbers are:
1. **Inaccurate** — a `ValueNotifier<String>` does not reliably cost 100 bytes across Dart VM, AOT, and different platforms
2. **Unmaintainable** — no derivation or citation for the constants
3. **Never tested** — no test asserts on `memory_overhead_estimate`
4. **Never called by users** — `getResourceStats()` itself has zero calls in any example app

This gives developers false confidence in a metric that cannot be trusted without real heap profiling. Real memory analysis belongs in the DevTools extension, not in a hardcoded arithmetic estimate inside the controller.

### What to Do

Remove `_estimateMemoryUsage()` and drop the `memory_overhead_estimate` key from `getResourceStats()`. The remaining stats in that map (`reactive_objects`, `workers`, `effects`, etc.) are accurate counts and genuinely useful for debugging.

---

## ✅ What Is Clean — Do Not Touch

The following were reviewed and are well-justified. No changes needed:

| Area | Verdict |
|---|---|
| `ZenEffect` vs `ZenMutation` | Correct semantic separation — effects are local, mutations are server-state |
| `ZenObserver` vs `ZenUpdater` vs `ZenConsumer` | Three distinct reactive ownership models, each necessary |
| `ZenQueryBuilder` vs `ZenQueryConsumer` vs `.when()` | Distinct lifecycle models — not duplication |
| Worker system (`ever`, `once`, `debounce`, `throttle`, `interval`, `condition`) | All justified; `watch()` is a convenience wrapper, not dead code |
| `ZenEnvironment` enum | Used in every example `main.dart` |
| `ZenTickerProvider` mixin | 28 lines, necessary for animation controllers |
| `ZenScopeInspector` | Correctly isolated debug utility |
| `ZenConsumer` widget | Used in ecommerce example; distinct from `ZenUpdater` |
| `ZenMetrics` | Correctly no-ops behind `ZenConfig.enablePerformanceMetrics` guard |
| `ZenDebug` / `ZenDevTools` | Correctly gated to `kDebugMode`; separate namespace |

---

## Summary Table

| Item | Risk | Effort | Action |
|---|---|---|---|
| ~~`ZenRouteObserver`~~ | ~~🔴 High — architectural contradiction~~ | ~~Low~~ | ✅ **Removed in V2** |
| ~~`ZenControllerAdvancedExtension`~~ | ~~🟡 Medium — API bloat~~ | ~~Very Low~~ | ✅ **Removed in V2** |
| ~~`_estimateMemoryUsage()`~~ | ~~🟡 Medium — false confidence~~ | ~~Very Low~~ | ✅ **Removed in V2** |
