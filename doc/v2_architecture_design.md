# Zenify V2: Architecture Design & Rationale

**Authors**: Package Owner + Architect  
**Date**: July 2026  
**Status**: ✅ SHIPPED — V2.0.0  

> This document captures both the design rationale and the final shipped state.  
> For migration steps, see [migration_v2_0_0.md](migration_v2_0_0.md).

---

## Implementation Status At-a-Glance

| Component | V2 State | Notes |
|---|---|---|
| `ZenProvider` — InheritedWidget tree-bound DI | ✅ Shipped | Renamed from `ZenScopeWidget` |
| `ZenProvider.create<T>` — single-controller convenience | ✅ Shipped | Replaces `ZenControllerScope` |
| `ZenScopeProvider` — hidden from public barrel | ✅ Shipped | InheritedWidget internals |
| `context.controller<T>()` — strict tree-bound, no global fallback | ✅ Shipped | Throws if not found |
| `ZenView<T>` — `build(context, T controller)` | ✅ Shipped | No magic getter, no global registry |
| `_ZenViewRegistry` — deleted entirely | ✅ Shipped | Gone |
| `initController` on `ZenView` — per-instance self-owned controller | ❌ Removed | Use `ZenProvider.create` at callsite |
| `ZenControllerScope<T>` | ❌ Removed | Use `ZenProvider.create<T>` |
| `ZenConsumer<T>` — scope-bound, `didChangeDependencies` | ✅ Shipped | Fails fast, fully tree-bound |
| `ZenObserver` — reactive auto-tracking (`Obx` removed in V2) | ✅ Shipped | |
| `ZenController` — lifecycle, auto-track reactive/children | ✅ Shipped | |
| `ZenScope` — hierarchical, parent-child, no global state | ✅ Shipped | |
| `ZenModule` — module-based scope initialization | ✅ Shipped | |
| `ZenUpdater<T>` — rebuilds on `update()` | ✅ Shipped | `ZenBuilder` kept as deprecated alias |
| `ZenBuilder<T>` | ⚠️ Deprecated | Alias for `ZenUpdater` — remove in V3 |
| Global `Zen.put()` for UI controllers | ❌ Anti-pattern | Valid only for true singleton services |

---

## 1. The Problem We Solved

Zenify began as "GetX done right" — familiar ergonomics, dangerous global state removed. But one fundamental GetX pattern survived into V1:

**The magic `controller` getter.**

```dart
// V1 — where does `controller` come from?
class CartPage extends ZenView<CartController> {
  @override
  Widget build(BuildContext context) {
    return Text('${controller.totalPrice}');
  }
}
```

The answer was a **global static registry** (`_ZenViewRegistry`). The view looked up its controller by type from a global map. This worked for the common case but failed when:

- Two `CartPage` widgets were on screen simultaneously
- A test forgot `Zen.reset()` and a stale controller bled into the next test
- The developer extracted a helper method and the compiler could not enforce the correct instance

**The root cause:** The `controller` getter lived on `ZenView<T>` (a `Widget`), which has no `BuildContext`. Without `BuildContext` there is no tree traversal. Without tree traversal, you must use global memory. Global memory cannot correctly represent multiple simultaneous instances of the same type.

This is not a fixable detail — it is a fundamental architectural constraint of Dart and Flutter.

---

## 2. What We Built in V2

### 2.1 The Core Principle

> **Every controller access is tree-bound via `BuildContext`.**

This is how Flutter itself works. `Theme.of(context)`, `MediaQuery.of(context)`, `Navigator.of(context)` — every Flutter primitive uses `BuildContext` to traverse the tree. State management should be no different.

### 2.2 `ZenProvider` — The Canonical Controller Provider

`ZenProvider` (formerly `ZenScopeWidget`) is the **only** place where UI controller creation lives in V2. It wraps a `ZenScope` in an `InheritedWidget`, making the scope available to all descendants via the widget tree.

```dart
// Path 1: Single controller — the common case
ZenProvider.create<CartController>(
  create: () => CartController(),
  child: const CartPage(),
)

// Path 2: Feature module with dependency graph
ZenProvider(
  moduleBuilder: () => CartModule(),
  scopeName: 'CartScope',
  child: const CartPage(),
)

// Path 3: Provide an already-constructed scope
ZenProvider(
  scope: myExistingScope,
  child: const CartPage(),
)
```

The controller is scoped to that subtree. When the `ZenProvider` leaves the tree (route pop, conditional removal), its `ZenScope` is disposed and all registered controllers call `onClose()`.

### 2.3 `ZenView<T>` — Injected Build Method

The single most important V2 change. The magic `controller` getter is gone. The controller is now **injected into the build method as a parameter** — resolved from the nearest `ZenProvider` ancestor by the framework.

```dart
// ❌ V1 — magic getter, global registry required
class CartPage extends ZenView<CartController> {
  @override
  Widget build(BuildContext context) {
    return Text('${controller.totalPrice}');
  }
}

// ✅ V2 — explicit injection, compiler-enforced
class CartPage extends ZenView<CartController> {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, CartController controller) {
    return Text('${controller.totalPrice}');
  }
}
```

**What this eliminates:**
- `_ZenViewRegistry` — no global static map anywhere
- The multi-instance bug — multiple `CartPage` instances each get their own controller from their own scope
- Test isolation issues — each test's widget tree is fully independent

**What this enables:**
- `CartPage` on two tabs simultaneously — works correctly, no collision
- Helper methods receive `controller` as an explicit parameter — compiler catches mistakes
- Tests inject a mock controller with one `ZenProvider.create` line, zero global state

**Implementation:** `ZenView` extends `Widget` directly and uses `_ZenViewElement` (a `ComponentElement`) to call `build()`. There is no `StatefulWidget` overhead. Controller resolution happens inside `_ZenViewElement.build()` by calling `zenScope.find<T>()`.

### 2.4 `ZenConsumer<T>` — Inline Composition

For components that are not full pages but need to access a controller inline.

```dart
class OrderSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenConsumer<CartController>(
      builder: (context, controller) => Column(
        children: [
          ZenObserver(() => Text('\${controller.totalPrice.value}')),
          ElevatedButton(
            onPressed: controller.checkout,
            child: const Text('Checkout'),
          ),
        ],
      ),
    );
  }
}
```

`ZenConsumer<T>`:
- Resolves via `context.controller<T>()` in `didChangeDependencies()` — correct `InheritedWidget` subscription semantics
- Fails fast with a clear error if not found (no silent null degradation)
- Is purely structural — reactivity is delegated to `ZenObserver`/`ZenUpdater` inside

### 2.5 `context.controller<T>()` — The Canonical API

The most ergonomic way to access a controller from any widget. Resolves strictly from the nearest `ZenProvider` ancestor. **No global fallback** — if no scope provides the controller, throws `ZenControllerNotFoundException` with a clear message.

```dart
// Generic form
final ctrl = context.controller<CartController>();

// Define typed extensions for domain ergonomics
extension CartContextExt on BuildContext {
  CartController get cart => controller<CartController>();
}

// Usage reads like domain language
ElevatedButton(
  onPressed: () => context.cart.checkout(),
  child: const Text('Checkout'),
)
```

This mirrors Flutter's own platform services: `Theme.of(context)`, `MediaQuery.of(context)`, `Navigator.of(context)`.

### 2.6 Strictly Scoped Resolution — No Global Fallback

In V1, controller resolution had a global fallback (`Zen.findOrNull<T>()`). This was the final thread connecting V2 to GetX's global-state model.

**In V2, it is removed.** If a controller is not found in the scope tree, the framework throws immediately with:

```
🎮 ZenControllerNotFoundException: No CartController found in the widget tree.
💡 Did you forget to wrap your widget in a ZenProvider(create: () => CartController())?
```

This is the correct behavior. Silent fallbacks to global state hide architectural mistakes. A loud error at build time is always better than a subtle bug at runtime.

### 2.7 Removal of `ZenControllerScope`

`ZenControllerScope` was a V1 widget that created and managed a controller's lifecycle — a GetX-inspired pattern where **the widget itself owns the controller factory**.

This conflates two concerns that must be separate:
- **DI lifecycle** (controller creation, registration, disposal) → belongs to `ZenScope`
- **Widget lifecycle** (build, mount, unmount) → belongs to Flutter's element tree

`ZenControllerScope` was **removed entirely in V2**. The replacement is `ZenProvider.create<T>`, which correctly places the DI concern in the scope layer.

---

## 3. The V2 Widget Taxonomy

| Widget | Role | When to Use |
|---|---|---|
| `ZenProvider` | **Provide** — creates and scopes controllers | Route builder, feature root, app root |
| `ZenProvider.create<T>` | **Provide** — single controller shorthand | Most common route-level case |
| `ZenView<T>` | **Consume (extend)** — page/screen base class | Pages, screens, complex widgets |
| `ZenConsumer<T>` | **Consume (compose)** — inline controller access | Inline builders, partial rebuilds |
| `ZenObserver` | **React** — rebuilds on `Rx<T>` changes | Any reactive value display |
| `ZenUpdater<T>` | **React** — rebuilds on `update()` calls | Manual/batched updates |

**Key principle:** DI access (`ZenView`, `ZenConsumer`) and reactivity (`ZenObserver`, `ZenUpdater`) are separate concerns. Compose them rather than conflating them.

---

## 4. Global DI — Bounded to True Singletons

`Zen.put()` is NOT abolished in V2. Its proper use is clarified:

| Dependency | Where it lives |
|---|---|
| UI controller (`CartController`, `ChatController`) | `ZenProvider` — scope-bound |
| True singleton service (`AuthService`, `NetworkService`) | `Zen.put()` at app startup |

```dart
// ✅ Correct: services registered globally before runApp
void main() {
  Zen.put(AuthService());
  Zen.put(NetworkService());
  runApp(const MyApp());
}

// ✅ Correct: UI controller scoped at route level
GoRoute(
  path: '/cart',
  builder: (context, state) => ZenProvider.create<CartController>(
    create: () => CartController(),
    child: const CartPage(),
  ),
)

// ❌ Wrong in V2: UI controller in global DI
Zen.put(CartController()); // what lifecycle does this have?
```

---

## 5. Why This Is Architecturally Correct

### 5.1 Easy vs. Simple

The V1 `controller` getter was **easy** — one word, magically resolves. But it hid complexity that surfaced at the worst moment: a multi-instance bug in production, test pollution from forgotten `Zen.reset()` calls, or a helper method that silently used the wrong controller instance.

The V2 injected parameter is **simple** — the controller is explicitly given to you by the framework. When something goes wrong, you know exactly where to look. When you extract a helper method, the compiler tells you what to pass.

Easy to start ≠ simple to understand. Zenify V2 optimizes for the latter.

### 5.2 The GetX Lesson

GetX made the same trade-off and paid for it with:
- Global state that bleeds between tests
- Multi-instance navigation bugs that are nearly impossible to debug
- A mental model that does not transfer to how Flutter actually works

Zenify V1 was "GetX but slightly better." Zenify V2 is genuinely different: architecturally sound, Flutter-idiomatic, and fully multi-instance safe by construction.

### 5.3 Test Isolation — Zero Global State for UI

Every widget test in V2 is self-contained:

```dart
testWidgets('cart shows total price', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ZenProvider.create<CartController>(
        create: () => CartController()..totalPrice.value = 42.0,
        child: const CartPage(),
      ),
    ),
  );
  expect(find.text('\$42.00'), findsOneWidget);
}); // ZenProvider disposes automatically — zero teardown needed
```

No `Zen.reset()`. No leaked controllers. No state bleeding between tests.

---

## 6. Decisions Made

### ✅ `ZenProvider.create<T>` convenience constructor — Added
The single-controller shorthand is so common it warranted its own API surface.

### ✅ `ZenUpdater<T>` rename — Done
`ZenBuilder` is now `ZenUpdater`. The old name stays as a deprecated alias (`ZenBuilder`) to smooth migration. It will be removed in V3.

### ✅ `ZenControllerScope` — Removed (not deprecated)
Hard removal in V2. No deprecation period. Migration: replace with `ZenProvider.create<T>`.

### ✅ `initController` on `ZenView` — Removed
Per-instance self-owned controller was an anti-pattern that encouraged tight coupling of widget and DI concerns. Use `ZenProvider.create` at the callsite instead.

### ✅ Global fallback in `context.controller<T>()` — Removed
Strict tree-bound resolution only. Fails loudly if no scope provides the type. This is the correct behavior.

### 🔜 `ZenRootScope` replacing global `Zen.put()` — Deferred to V3
A future `ZenRootScope` widget wrapping `runApp` would eliminate all global static state, making test isolation perfect with zero global setup. `Zen.put()` is valid for V2.

### 🔜 Package rename (`zenith`?) — Deferred to V3
The `zenify` name has connotations of a wellness app rather than a state management framework. `zenith` (real word: "highest point," contains "zen," 6 chars) is the strongest candidate. Revisit before V3 or a marketing push.

---

## 7. The Three-Step Mental Model

This is the developer-facing summary of the entire V2 architecture:

```
REGISTER  →  Zen.registerModules([AppModule()])      app services — live for app lifetime
              ZenRoute(moduleBuilder: () => M())      route-level — standard for real apps
              ↳ scope.put<T>(T())  inside ZenModule   where controllers are actually created
              ZenProvider.create<T>(create: ...)      simple routes without a module

CONSUME   →  ZenView<T>                 extend — controller injected into build()
              ZenConsumer<T>            compose — inline builder, no inheritance
              context.controller<T>()  imperative — from any widget or callback
              Zen.find<T>()             inside controllers and services (non-widget code)

REACT     →  ZenObserver               Rx<T> — auto-rebuild on value change
              ZenUpdater<T>             update() — manual, ID-targeted rebuilds
              ZenQuery<T>               async — caching, loading, error, refetch
```

> **Key rule:** `ZenView` resolves from the nearest `ZenProvider` scope automatically. Whether the controller was registered via `ZenRoute` or an explicit `ZenProvider` — consumption is always the same zero-boilerplate pattern. Global services (`Zen.put`) are accessed explicitly via `Zen.find()`.

Every controller access flows through `BuildContext` and the widget tree. There is no global registry for UI state. This is how Flutter works, and Zenify works the same way.

---

## 9. Session Notes: July 15, 2026 — Pre-Release Audit & Fixes

This section documents all decisions, clarifications, and changes made immediately before the V2 public release. Read this at the start of any new session to avoid re-litigating resolved decisions.

---

### 9.1 Scope Resolution: Verified Behaviour (Important)

The following was empirically verified against source code — do not guess at this:

**`scope.find<T>()` walks the parent chain.** ([`zen_scope.dart:220`](zen_scope.dart))
```dart
return parent?.find<T>(tag: tag); // recursive upward walk
```

**`ZenProvider` does NOT connect to `Zen.rootScope` as parent.** ([`zen_provider.dart:145`](zen_provider.dart))
```dart
parentScope = ZenProvider.maybeOf(context); // finds other ZenProviders only
// If no ZenProvider ancestor found, parentScope = null → _rootScope is NOT in the chain
```

**`ZenRoute` DOES connect to `Zen.rootScope` as fallback.** ([`zen_route.dart:118`](zen_route.dart))
```dart
final parentScope = widget.parentScope ?? parentFromTree ?? Zen.rootScope;
// Zen.rootScope is a stable, immutable anchor — not a mutable global pointer
```

**Practical consequences:**
- `Zen.find<MyService>()` → always works, goes directly to `Zen.rootScope`
- `scope.find<MyService>()` inside a `ZenModule` used with `ZenRoute` → works (root is in chain)
- `scope.find<MyService>()` inside a `ZenModule` used with bare `ZenProvider` at tree top → **may NOT work** (root not in chain)
- `Zen.put<CartController>()` + `ZenView<CartController>` → **always throws** `ZenControllerNotFoundException` — `ZenView` is tree-bound only

---

### 9.2 `ZenService` — Verified Behaviour

`ZenService` is an `abstract class` (not an interface). It provides:
- `onInit()` / `onClose()` lifecycle hooks
- `ensureInitialized()` re-entrant-safe init guard
- `isInitialized`, `isDisposed` flags
- Global tracking via `ZenService._activeServices` Set (used by DevTools)

**`Zen.put()` auto-detects `ZenService`:**
```dart
// zen_di.dart:135
final permanent = isPermanent ?? (instance is ZenService);
```
**A `ZenService` is automatically `isPermanent: true`.** You do not need to specify it.

**A `ZenController` (extending `ZenController`, not `ZenService`) is NOT auto-permanent.** If you register a `ZenController` globally via `Zen.put()`, you MUST pass `isPermanent: true` explicitly if you want it to survive for the app lifetime.

**Plain Dart classes work with `Zen.put()` too.** `T` is `Object` — no type constraint. Use plain classes for simple stateless helpers that have no lifecycle needs.

---

### 9.3 Global Reactive State Pattern — Resolved Decision

**Decision: Global controllers (i.e., `Zen.put<T>()` for a `ZenController`) are NOT accessible via `ZenView`.** This is intentional and must not be changed.

**The correct pattern for app-wide reactive state (ThemeController, AuthController):**

```dart
class ThemeController extends ZenController {
  static ThemeController get to => Zen.find<ThemeController>()!;
  final isDark = false.obs();
  void toggleDark() => isDark.value = !isDark.value;
}

// Register at startup with isPermanent: true (not auto-detected — ZenController, not ZenService)
Zen.put<ThemeController>(ThemeController(), isPermanent: true);

// Consume reactively anywhere — ZenObserver is NOT scope-bound
ZenObserver(() => Icon(
  ThemeController.to.isDark.value ? Icons.dark_mode : Icons.light_mode,
))
```

**Key insight:** `ZenObserver` tracks `ValueNotifier` reads — it doesn't care where the object lives. It works with both tree-bound and globally-registered controllers. `ZenView` is the scoped pattern; `ZenObserver` is the reactive pattern — they are orthogonal.

**The rule of thumb (now documented in README):**
- Page/route controller → `ZenProvider.create` + `ZenView`
- App-wide reactive state → `Zen.put` + `.to` + `ZenObserver`

**Decided against:** allowing `ZenView` to fall back to `Zen.rootScope`. This would re-introduce the V1 multi-instance bug (two `CartPage`s sharing one controller) and break auto-disposal guarantees.

---

### 9.4 `ZenControllerNotFoundException` — Improved Message

The exception message was made actionable. It now covers both common failure modes:

```
🎮 ZenControllerNotFoundException: CartController not found in the widget tree (Type=CartController)
   💡 Two common causes:
      1. Forgot ZenProvider? Wrap your route:
         ZenProvider.create<CartController>(create: () => CartController(), child: const YourPage())
      2. Used Zen.put<CartController>() for a controller? That registers it globally but
         ZenView only resolves from the widget tree — not the global scope.
         • For page controllers: use ZenProvider.create<CartController>() at your route.
         • For global reactive state: use Zen.put + .to + ZenObserver instead of ZenView.
   📚 https://github.com/sdegenaar/zenify/blob/main/doc/hierarchical_scopes_guide.md
```

---

### 9.5 README V2 — Final Structure

The README was substantially rewritten for the V2 launch. Key structural decisions:

1. **Hero tagline:** `TanStack Query Patterns • Hierarchical Scoped DI • Offline-First Architecture • Zero Code Generation`

2. **Two emotional "before/after" hooks** — not one:
   - Hook 1 (async state): `bool _isLoading = false` boilerplate → `ZenQueryConsumer` one-liner
   - Hook 2 (scoping): `Get.put()` + `Get.delete()` memory leak → `ZenRoute` auto-disposal

3. **Four Pillars** (was Three):
   - ZenQuery (TanStack Query patterns)
   - Hierarchical Scoped DI with auto-disposal ← **added, was missing entirely**
   - Offline-First by Design
   - Zero Code Generation

4. **No competitor naming** — Riverpod and BLoC are never named. The "before" code speaks for itself. This avoids flame wars and community friction.

5. **Global Reactive State section added** to Common Patterns — shows the `ThemeController.to` + `ZenObserver` pattern explicitly with the rule-of-thumb callout.

---

### 9.6 V3 Backlog (Do Not Touch for V2)

| Item | Rationale |
|---|---|
| `Zen.find<T>()` returning `T?` nullable | Should throw `ZenDependencyNotFoundException` instead of returning null. Breaking API change — V3 only. |
| `ZenObserver` from `StatefulWidget` → `ComponentElement` | Would save one `State` allocation per observer. Defer until profiling proves it matters. |
| `ZenRootScope` widget wrapping `runApp` | Eliminates all global static state for perfect test isolation. V3. |
| `ZenObserver` alias name | `Watch`/`Observe` considered — keep `ZenObserver` for V2 for naming consistency. Revisit with package rename. |
| Package rename (`zenith`?) | Do not rename for V2. Ship and gain traction. Revisit before V3. |

---

### 9.7 Test Status at V2 Release

All tests passing: **2170 tests, 0 failures** as of July 15, 2026.
