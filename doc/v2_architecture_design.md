# Zenify V2: Architecture Design & Rationale

**Authors**: Package Owner + Architect  
**Date**: July 2026  
**Status**: ✅ SHIPPED — V2.0.0 Released  
**Context**: Architectural design session. Code references reflect the V1.11.x codebase as audited July 2026.

> This document is the original design rationale. For the current implementation details, see the source code and [migration_v2_0_0.md](migration_v2_0_0.md).

---

## Implementation Status At-a-Glance

| Component | V2 State | Status |
|---|---|---|
| `ZenScopeWidget` — InheritedWidget tree-bound DI | ✅ Done | Production-ready |
| `ZenScopeProvider` — hidden from public barrel | ✅ Done | Production-ready |
| `context.controller<T>()` — tree-bound, no global registry | ✅ Done | Production-ready |
| `ZenObserver` — reactive auto-tracking | ✅ Done | Production-ready |
| `ZenController` — lifecycle, auto-track reactive/children | ✅ Done | Production-ready |
| `ZenScope` — hierarchical, parent-child, no global state | ✅ Done | Production-ready |
| `ZenModule` — module-based scope initialization | ✅ Done | Production-ready |
| `ZenView<T>` — injected `build(context, T controller)` | ✅ Done | Production-ready |
| `_ZenViewRegistry` — deleted entirely | ✅ Done | No global registry |
| `initController` — replaces `createController` on `ZenView` | ✅ Done | Production-ready |
| `ZenConsumer<T>` — scope-bound via `didChangeDependencies` | ✅ Done | Production-ready |
| `ZenScopeWidget.create<T>` — simple convenience constructor | ✅ Done | Production-ready |
| `ZenBuilder<T>` renamed to `ZenUpdater<T>` | ✅ Done | `ZenBuilder` kept as deprecated alias |

---

## 1. The Problem We Are Solving

Zenify was originally designed as a "GetX done right" — familiar ergonomics, dangerous global state removed. That mission was largely achieved in V1. But one fundamental GetX pattern survived the migration and continues to cause bugs in the wild:

**The magic `controller` getter.**

```dart
class CartPage extends ZenView<CartController> {
  @override
  Widget build(BuildContext context) {
    return Text('${controller.totalPrice}'); // Where does `controller` come from?
  }
}
```

The answer is: a **global static registry** (`_ZenViewRegistry`). The view looks up its controller by type from a global map. This works for the common case — a single instance of `CartPage` active at a time — but it fails categorically when:

- Two `CartPage` widgets are on screen simultaneously (split-view, nested navigation)
- A test forgets `Zen.reset()` and a previous controller bleeds into the next test
- The developer extracts a helper method and the compiler cannot enforce that the correct instance is used

**The root cause:** The `controller` getter is on `ZenView<T>` (a Widget), which has no `BuildContext`. Without `BuildContext`, you cannot traverse the widget tree. Without tree traversal, you must use global memory. Global memory cannot correctly represent multiple simultaneous instances of the same type.

This is not a fixable detail — it is a fundamental architectural constraint of Dart and Flutter.

---

## 2. What We Did in V1.x (Completed)

### 2.1 Stack-Based Registry (shipped, temporary fix)

**Old:** `Map<Type, ZenController>` — last writer wins. Navigation to a second `CartPage` would overwrite the first.

**New:** `Map<Type, List<ZenController>>` — a stack. Mount pushes, dispose pops, `peek()` returns the innermost instance.

```dart
class _ZenViewRegistry {
  static final Map<Type, List<ZenController>> _stack = {};
  static void push<T extends ZenController>(T c) => _stack.putIfAbsent(T, () => []).add(c);
  static void pop<T extends ZenController>()    => _stack[T]?.removeLast();
  static T? peek<T extends ZenController>()     => _stack[T]?.lastOrNull as T?;
}
```

This fixes **sequential** multi-instance (navigate to A, navigate to B, back to A). It does NOT fix **simultaneous** multi-instance (both A and B on screen at the same time).

**Verdict:** Best V1-compatible fix. Still a workaround for the fundamental architectural constraint. **`_ZenViewRegistry` is deleted entirely in V2.**

### 2.2 ZenScopeView Removed

`ZenScopeView` was a thin wrapper over `context.controller<T>()`. It was never published and was deleted. The correct idiom is a plain `StatelessWidget` with `context.controller<T>()` directly.

### 2.3 ZenScopeProvider Hidden from Public API

`ZenScopeProvider` (the `InheritedWidget` that carries a `ZenScope`) is hidden from the public barrel using Dart's `hide` mechanism. It is accessible via direct import but invisible through `package:zenify/zenify.dart`.

### 2.4 `context.controller<T>()` — Correct and Complete

`ZenViewContextExtensions.controller<T>()` resolves purely via the widget tree:

1. Nearest `ZenScope` via `dependOnInheritedWidgetOfExactType<ZenScopeProvider>()`
2. Global `Zen.findOrNull<T>()` fallback

This is **100% tree-bound and multi-instance safe**. It is the canonical API for non-`ZenView` widgets and the foundation V2 is built on.

### 2.5 ZenScope — Hierarchical DI Container (Complete)

`ZenScope` is a fully production-ready hierarchical DI container:
- Parent-child relationships via object references (no global map)
- Type-based and tag-based registration
- Lazy factories
- Automatic lifecycle management (init/dispose)
- Child scope tracking and disposal propagation

### 2.6 ZenModule — Module-Based Scope Initialization (Complete)

`ZenModule` provides a structured way to register dependencies into a scope, including dependency modules, async `onInit`, and named registration. Used via `ZenScopeWidget(moduleBuilder: () => MyModule(), ...)`.

---

## 3. Known Bug: ZenConsumer is Broken (Must Fix in V2)

**Current implementation** (`lib/widgets/scope/zen_consumer.dart`):

```dart
void _findDependency() {
  // BUG: Uses Zen.findOrNull — global DI only. Completely bypasses widget tree scope.
  dependency = Zen.findOrNull<T>(tag: widget.tag);
}
```

**Problems:**
1. Calls `Zen.findOrNull<T>()` in `initState()` — no `BuildContext` available, so it *cannot* do scope-based lookup even if it wanted to.
2. Returns `T?` (nullable) — silently degrades to rendering nothing instead of failing with a clear error.
3. Does not rebuild when scope changes (uses `initState`, not `didChangeDependencies`).

**V2 fix:** `ZenConsumer` must become a `StatefulWidget` that resolves via `context.controller<T>()` in `didChangeDependencies()` (not `initState()`) — giving it access to `BuildContext` and proper `InheritedWidget` subscription semantics.

---

## 4. The V2 Architecture Vision

### 4.1 The Core Principle

> **Every controller access must be tree-bound via `BuildContext`.**

This is how Flutter itself works. `Theme.of(context)`, `MediaQuery.of(context)`, `Navigator.of(context)` — every Flutter primitive uses `BuildContext` to traverse the tree. State management should be no different.

### 4.2 `ZenView<T>` — Injected Build Method

The single most important V2 change: `build(BuildContext context)` becomes `build(BuildContext context, T controller)`.

```dart
// V2
abstract class ZenView<T extends ZenController> extends StatelessWidget {
  const ZenView({super.key});

  // Controller is injected — resolved from the tree by the framework,
  // not from a global registry.
  Widget build(BuildContext context, T controller);

  @override
  Widget build(BuildContext context, T controller);
}
```

**Controller Resolution & Lifecycle (The V2 approach):**

V2 `ZenView` resolves its controller in this priority order:
1. **`initController`** — if overridden, the element creates and owns the controller directly (lifecycle: `mount` → `onInit` → `onReady`; then `unmount` → `onClose`). The created controller is automatically wrapped in a `ZenScopeWidget`, making it available to all child widgets.
2. **Nearest `ZenScopeWidget`** ancestor — tree-bound, safe for multiple instances.
3. **Global `Zen` DI** fallback — for singleton services.

**What this changes for users:**

```dart
// V1
class CartPage extends ZenView<CartController> {
  @override
  Widget build(BuildContext context) {
    return Text('${controller.totalPrice}'); // magic getter
  }
}

// V2
class CartPage extends ZenView<CartController> {
  @override
  Widget build(BuildContext context, CartController controller) {
    return Text('${controller.totalPrice}'); // injected parameter
  }
}
```

The change is mechanical — find/replace on the method signature across all subclasses. The body of each build method is usually unchanged.

**What this eliminates:**

- `_ZenViewRegistry` — deleted entirely (no more global static map)
- `ZenViewExtension.controller` getter — deleted (no magic lookup needed)
- The multi-instance bug — fixed structurally, not by workaround
- Test isolation issues — each test's widget tree is independent

**What this enables:**

- Multiple `CartPage` instances on screen simultaneously — each gets its own controller from its own scope
- Extracted helper methods receive `controller` as an explicit parameter — the compiler enforces correctness
- Riverpod-style consumer pattern — familiar to modern Flutter developers
- Zero-boilerplate list items — `initController` allows a widget to cleanly own its controller without explicit `ZenScopeWidget` wrapper code.

**Implementation detail (`ComponentElement` over `StatefulWidget`):** 
In V1, `ZenView` was a `StatefulWidget` to manage the lifecycle of `createController`. In V2, `ZenView` extends `Widget` directly and uses a custom `_ZenViewElement` (extending `ComponentElement`). This provides the exact same lifecycle hooks (`mount`/`unmount`) for `initController` but with significantly less framework overhead, producing a cleaner widget tree.

### 4.3 `ZenConsumer<T>` — Fixed Inline Widget

For components that are NOT full pages but need to access a controller inline. V2 fixes the current broken implementation:

```dart
// V2 — resolves from widget tree scope, not global DI
class ZenConsumer<T extends ZenController> extends StatefulWidget {
  final Widget Function(BuildContext context, T controller) builder;
  final String? tag;

  const ZenConsumer({super.key, required this.builder, this.tag});

  @override
  State<ZenConsumer<T>> createState() => _ZenConsumerState<T>();
}

class _ZenConsumerState<T extends ZenController> extends State<ZenConsumer<T>> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies — context is available and InheritedWidget subscriptions work
  }

  @override
  Widget build(BuildContext context) {
    // Resolves via context.controller<T>() — scope → global DI fallback
    // Fails fast with clear error if not found (no silent null degradation)
    final controller = context.controller<T>(tag: widget.tag);
    return widget.builder(context, controller);
  }
}
```

**Usage:**
```dart
class OrderSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenConsumer<CartController>(
      builder: (context, controller) => Column(
        children: [
          ZenObserver(() => Text('\$${controller.totalPrice.value}')),
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

`ZenConsumer<T>` is a builder widget (composition, not inheritance). It:
- Resolves the controller via `context.controller<T>()` (scope → global DI)
- Is completely multi-instance safe
- Pairs naturally with `ZenScopeWidget` (provide / consume mental model)
- Is familiar to developers who know `Provider.of` / `Consumer` patterns
- Is purely structural — reactivity is delegated to `ZenObserver` / `ZenBuilder` inside

### 4.4 `ZenScopeWidget` — The Canonical Provider

`ZenScopeWidget` already exists and works correctly. In V2, it becomes the **only** place where UI controller creation lives.

**Current API (V1.x, both paths remain supported):**

```dart
// Path 1: Provide an existing scope instance
final myScope = ZenScope(name: 'CartScope');
myScope.put<CartController>(CartController());

ZenScopeWidget(
  scope: myScope,
  child: const CartPage(),
)

// Path 2: Module-based (for feature modules with dependency graphs)
ZenScopeWidget(
  moduleBuilder: () => CartModule(),
  scopeName: 'CartScope',
  child: const CartPage(),
)
```

**Open Question (see Section 7.1):** Should a third convenience path be added?

```dart
// Path 3 (proposed): Simple create shorthand — no module, no manual scope
ZenScopeWidget(
  create: () => CartController(),
  child: const CartPage(),
)
```

**V2 test isolation example — no global state:**

```dart
testWidgets('cart shows total price', (tester) async {
  final scope = ZenScope(name: 'TestScope');
  scope.put<CartController>(CartController()..totalPrice.value = 42.0);

  await tester.pumpWidget(
    ZenScopeWidget(
      scope: scope,
      child: const CartPage(),
    ),
  );
  expect(find.text('\$42.00'), findsOneWidget);
}); // scope disposes with the widget tree — automatic cleanup
```

### 4.5 Context Extensions — The Canonical Consumer API

The most ergonomic and idiomatic way to access a controller from any widget. Already fully implemented and working.

```dart
// Generic (package provides this — already done)
extension ZenContextExt on BuildContext {
  T controller<T extends ZenController>({String? tag}) { ... }
}

// Typed (developer writes this for their domain)
extension CartContextExt on BuildContext {
  CartController get cart => controller<CartController>();
}

// Usage — reads like domain language
class CheckoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => context.cart.checkout(),
      child: const Text('Checkout'),
    );
  }
}
```

This mirrors how Flutter itself exposes platform services:
- `Theme.of(context)` → your `context.cart`
- `MediaQuery.of(context)` → your `context.chatViewController`
- `Navigator.of(context)` → your `context.auth`

### 4.6 Global DI — Bounded to True Singletons

`Zen.put()` (global DI) is NOT abolished in V2. Its proper use is clarified:

| Use Case | Correct Location |
|---|---|
| UI controller (CartController, ChatController) | `ZenScopeWidget` — scope-bound |
| True singleton service (AuthService, NetworkService, Analytics) | `Zen.put()` — global DI |

```dart
// Correct: services registered globally before runApp
void main() {
  Zen.put(AuthService());
  Zen.put(NetworkService());
  runApp(const MyApp());
}

// Correct: UI controllers in scope
ZenScopeWidget(
  moduleBuilder: () => CartModule(), // tied to the cart screen's lifecycle
  child: const CartPage(),
)

// Wrong in V2: UI controller in global DI
Zen.put(CartController()); // ← what lifecycle does this have?
```

---

## 5. The V2 Widget Taxonomy

| Widget | Pattern | Use Case | Reactive? | Status |
|---|---|---|---|---|
| `ZenScopeWidget` | Provide | Creates and scopes a controller | No — provides | ✅ Done |
| `ZenView<T>` | Consume (extend) | Full page/screen base class | Via `ZenObserver` inside | ❌ V2 work |
| `ZenConsumer<T>` | Consume (compose) | Inline controller access in any widget | Via `ZenObserver` inside | ❌ Needs fix |
| `ZenObserver` | React | Reactive rebuild on `Rx<T>` changes | Yes — Rx values | ✅ Done |
| `ZenBuilder<T>` | React | Reactive rebuild on `update()` calls | Yes — manual update | ✅ Done (rename TBD) |

**Key principle:** DI access (`ZenView`, `ZenConsumer`) and reactivity (`ZenObserver`, `ZenBuilder`) are separate concerns. Compose them rather than conflating them.

**Note on `ZenBuilder<T>`:** Currently does double duty — it both creates/registers controllers AND listens to `update()`. In V2, controller creation moves entirely to `ZenScopeWidget`. `ZenBuilder` becomes a pure reactivity widget. See Open Question 7.2 on whether to rename it `ZenUpdater`.

---

## 6. Why We're Making This Breaking Change

### 6.1 "Easy" vs "Simple"

The V1 `controller` getter is **easy** — one word, no arguments, magically resolves. But it hides complexity that surfaces at the wrong moment: when you're in production with a multi-instance bug and you have no mental model for why it's happening.

The V2 injected parameter is **simple** — the controller is explicitly given to you by the framework. When it goes wrong, you know exactly where to look. When you extract a helper method, the compiler tells you exactly what to pass.

There is a difference between easy-to-start and simple-to-understand. Zenify V2 optimizes for the latter.

### 6.2 The GetX Lesson

GetX made the same trade-off (easy over simple) and paid for it with:
- Global state that bleeds between tests
- Multi-instance navigation bugs that are nearly impossible to debug
- A mental model that does not transfer to how Flutter actually works

Zenify V1 was "GetX but slightly better." Zenify V2 is a genuinely different, architecturally sound framework that happens to be ergonomic.

### 6.3 Riverpod's Precedent

When Riverpod launched, it broke everything from Provider. Developers complained. Then they realized Riverpod was correct, and it became the architectural standard.

**Correctness always wins in the long run.** Developers who build serious applications choose the tool that works correctly, even if the migration is painful.

### 6.4 Zenify Has Outgrown GetX Compatibility

Zenify has built:
- A genuine `ZenScope` hierarchy with inheritance, isolation, and lifecycle management
- A `ZenQuery` system that is unique in the Flutter ecosystem (TanStack Query semantics)
- A reactive primitive system (`Rx<T>`, `ZenObserver`, workers) that is correct and performant
- A `ZenModule` system for structured feature module initialization

These are features GetX cannot replicate. Zenify no longer needs GetX compatibility as a crutch for adoption. It can stand on its own architectural merit.

---

## 7. Open Questions — Decision Required Before Implementation

### 7.1 `ZenScopeWidget.create:` Convenience Constructor

**The situation:** The current `ZenScopeWidget` requires either a `scope:` (pre-built `ZenScope` instance) or a `moduleBuilder:` (a `ZenModule` factory). For simple cases — a single controller, no dependencies — both paths are verbose.

**The proposal:** Add a third `create:` constructor path:

```dart
// Proposed — simple, one controller, zero module boilerplate
ZenScopeWidget(
  create: () => CartController(),
  child: const CartPage(),
)
```

This would internally create a `ZenScope`, call `scope.put<T>(create())`, and behave identically to the `scope:` path otherwise.

**Trade-off:** A third code path to maintain, but significantly reduces boilerplate for the common case. The `create:` path would NOT support async `onInit` or dependency modules — that remains `moduleBuilder:`.

**Decision needed:** Add `create:` convenience ctor, or require `scope:` / `moduleBuilder:` for all cases?

---

### 7.2 `ZenBuilder<T>` → `ZenUpdater<T>` Rename

**The situation:** In V1, `ZenBuilder<T>` does two things:
1. Finds or creates a controller (DI concern)
2. Rebuilds when `controller.update()` is called (reactivity concern)

In V2, controller creation belongs to `ZenScopeWidget`. `ZenBuilder<T>` should become a purely reactive widget — it finds a controller (DI lookup only, no creation) and rebuilds on `update()` calls. Its *purpose* is reactivity, not DI.

The name `ZenBuilder` conflicts with Flutter's own `Builder` widget conceptually, and more importantly, it doesn't communicate *why* it rebuilds.

**The proposal:** Rename to `ZenUpdater<T>`:
- `ZenUpdater` communicates that this widget rebuilds on `controller.update()` calls
- Distinguishes it clearly from `ZenObserver` (which rebuilds on `Rx<T>` changes)
- Is a breaking rename — requires deprecation period

**Migration path if we rename:**
```dart
// V1 — ZenBuilder rebuilds on update()
ZenBuilder<CartController>(
  builder: (context, controller) => Text('${controller.count}'),
)

// V2 — ZenUpdater, same behavior, clearer name
ZenUpdater<CartController>(
  builder: (context, controller) => Text('${controller.count}'),
)
```

**Decision needed:** Rename to `ZenUpdater`, or keep `ZenBuilder` with updated semantics?

---

### 7.3 `ZenView` Auto-Scope Creation

**The situation:** In V2, `ZenView.build(context, controller)` resolves the controller via `context.controller<T>()`. This works correctly when the parent route wraps in `ZenScopeWidget`. But if a developer uses `ZenView` without a parent `ZenScopeWidget` and no global registration, it throws.

**The proposal:** `ZenView` could automatically create an internal `ZenScope` for its controller, making it self-contained:

```dart
// This would work even without an explicit ZenScopeWidget parent:
class CartPage extends ZenView<CartController> {
  @override
  CartController Function()? get createController => () => CartController();

  @override
  Widget build(BuildContext context, CartController controller) { ... }
}
```

**Trade-off:** Every `ZenView` instance allocates a `ZenScope` object even when one already exists above it. Adds complexity. Keeps `createController` alive which V2 wants to remove.

**Recommendation:** Do NOT auto-create scope. Require explicit `ZenScopeWidget`. The error message when controller is not found should be extremely clear: *"CartController not found. Wrap this widget with ZenScopeWidget(create: ...) or register CartController before navigation."*

**Decision needed:** Confirm no auto-scope, or allow it as a convenience?

---

### 7.4 `ZenRootScope` vs `Zen.put()` (V3 consideration, not V2)

Global DI (`Zen.put()`) is valid for true singletons. A future `ZenRootScope` widget wrapping `runApp` would eliminate all global static state, making the entire framework pure widget-tree-bound. This would make test isolation perfect with zero `Zen.reset()` calls anywhere.

**Decision:** Defer to V3. `Zen.put()` is valid for V2.

---

## 8. Migration Strategy

### 8.1 The Mechanical Change

The V2 migration is almost entirely mechanical. A script or IDE refactoring can handle 95% of it:

```
Find:    Widget build(BuildContext context) {
Replace: Widget build(BuildContext context, <ControllerType> controller) {
```

Where `<ControllerType>` is read from the `ZenView<T>` generic parameter.

Helper methods on `ZenView` subclasses that reference `controller` need to gain a `controller` parameter:

```dart
// V1
void _showDeleteDialog() {
  controller.delete(); // magic getter
}

// V2
void _showDeleteDialog(CartController controller) {
  controller.delete(); // explicit parameter — compiler-enforced
}
```

### 8.2 Phased Rollout

1. **V1.x (complete):** Stack-based registry fix. `context.controller<T>()` established as canonical. `ZenScopeView` removed. `ZenScope`, `ZenScopeWidget`, `ZenModule` production-ready.
2. **V2.0-alpha:**
   - `ZenView` becomes `StatelessWidget` with injected `build(context, T controller)`
   - `_ZenViewRegistry` deleted
   - `createController` removed from `ZenView`
   - `ZenConsumer<T>` fixed (scope-bound, non-nullable, `didChangeDependencies`)
   - `ZenBuilder` create/register behavior stripped (DI-only lookup + reactivity)
   - Old `ZenView` signature deprecated with `@Deprecated` + IDE warning
3. **V2.0:**
   - Old `ZenView` signature removed
   - `ZenBuilder` rename to `ZenUpdater` (if that decision is made)
   - `create:` convenience on `ZenScopeWidget` (if that decision is made)

### 8.3 Version and Documentation

- Bump to `2.0.0` — this is a SEMVER major version
- Publish a migration guide (extending the existing `doc/migration_guide.md`)
- Provide a migration script via the `tool/` directory
- Update all examples

---

## 9. Summary

The V2 architecture has one core principle: **every controller access is tree-bound via `BuildContext`**. This is achieved through:

1. `ZenView<T>` injects the controller into `build(context, T controller)` — no global registry *(to be implemented)*
2. `ZenConsumer<T>` provides inline composition without inheritance — scope-bound, multi-instance safe *(to be fixed)*
3. `ZenScopeWidget` is the canonical provider — separates creation from consumption *(already done)*
4. `context.controller<T>()` is the canonical API — tree-bound, testable, idiomatic Flutter *(already done)*
5. Global DI (`Zen.put()`) is bounded to true singleton services

**What is already done is the hard part.** `ZenScope`, `ZenScopeWidget`, `ZenScopeProvider`, and `context.controller<T>()` form the correct architectural foundation. The remaining V2 work is executing the final 60%: migrating `ZenView`, fixing `ZenConsumer`, and stripping misplaced DI behavior from `ZenBuilder`.

The result is a framework that is architecturally equivalent to Riverpod in correctness, familiar in naming, and unique in its reactive primitives (`ZenObserver`, `ZenQuery`).

This is Zenify for 2026 and beyond.

---

## 10. Future Discussion: Naming

> **Status:** Deferred — decide before V3 or a marketing push.  
> Code must ship first. These are branding decisions, not architectural ones.

---

### 10.1 `ZenView` — Is the Name Right?

**The problem:** `ZenView` implies a full screen or page. But the class is also used
for list items, cards, and per-instance widgets (via `initController`). The name is
accurate for 70% of use cases and confusing for the other 30%.

**The Riverpod parallel (industry standard naming):**

| Riverpod | Zenify Equivalent | Notes |
|---|---|---|
| `ConsumerWidget` | `ZenView<T>` | Base class you extend |
| `Consumer` | `ZenConsumer<T>` | Inline builder widget |

Following Riverpod would mean renaming `ZenView` → `ZenConsumerWidget`.
But that's longer and uglier. GetX uses `GetView<T>` for the same pattern
and it's accepted in that community.

**Candidate names:**

| Name | Rationale | Verdict |
|---|---|---|
| `ZenView<T>` | Current. GetX precedent. Familiar. | Keep if not renaming package |
| `ZenConsumerWidget<T>` | Riverpod parallel. Semantically correct. | Too verbose |
| `ZenScreen<T>` | Clear for pages. Wrong for list items. | Too narrow |
| `ZenWidget<T>` | Generic. Clear at least. | Too generic |
| `ZenPage<T>` | Same issue as ZenScreen. | Too narrow |

**Recommendation:** If the package is renamed (see 10.2), rename `ZenView` at the
same time to match the new brand. If staying with Zenify, `ZenView` is acceptable.
The cost of renaming mid-version is high — this is a V3 decision if at all.

---

### 10.2 Package Name: "Zenify" — Is It Right?

**The problem with "Zenify":**
- Sounds like a wellness/meditation app, not a state management framework
- "ify" suffix implies a transformation tool (minify, uglify, bundlify) — wrong connotation
- Low discoverability: searching "zenify flutter" is not intuitive
- Zero signal about what the package does

**What makes a good Flutter package name:**
- Short (ideally ≤ 2 syllables)
- Memorable and Googleable
- Communicates purpose or personality
- Unique on pub.dev
- Compatible with the existing `Zen*` API prefix

**Candidate package names:**

| Name | Rationale | API Compat | Verdict |
|---|---|---|---|
| `zenify` | Current. Has some brand recognition (200 users). | ✅ | Keep if no rename |
| `zenith` | Real word: "highest point/peak." Premium feel. Contains "zen." Short. | ✅ | ⭐ **Top pick** |
| `zenkit` | Toolkit implication. Clear. | ✅ | Good but "kit" suffix crowded |
| `zenscope` | Communicates the scope-first architecture. | ✅ | Good, technical |
| `zenreact` | Reactive-first framing. Echoes React Query (ZenQuery). | ✅ | Risk: "React" confused with React.js |
| `zen_state` | Descriptive. Underscore looks dated. | ✅ | Boring |
| `zapp` | Short, fast-feeling. | ❌ Breaks Zen* prefix | Too big a break |

**Analysis of top candidates:**

**`zenith`**
- A real, premium English word meaning "the highest point"
- Contains "zen" naturally — all internal `Zen*` API names stay untouched
- 6 characters, memorable, Googleable
- Brand story: *"The peak of Flutter state management"*
- No competing pub.dev package (verify before committing)
- Sounds like a product name, not a utility

**`zenscope`**
- Communicates the core architecture: scope-based DI
- Two syllables, clear
- Slightly technical but that's the audience

**`zenreact`**
- Emphasizes the reactive + async query angle (the killer feature)
- Risk: "React" has strong association with Facebook's React framework
- Could be confusing to beginners

---

### 10.3 Decision Matrix

Before any rename, answer:

1. **Is now the right time?** V2 unreleased + 200 downloads = yes, lowest cost window ever.
2. **Will the internal `Zen*` API names change?** Ideally no — keep ZenView, ZenController, ZenObserver etc.
3. **Is this a pub.dev rename or a new package?** pub.dev supports "discontinued" + redirect. New package gets a clean slate but loses pub points history.
4. **What's the marketing angle?** If leading with ZenQuery (React Query for Flutter), `zenreact` or `zenith` fits better than `zenscope`.

---

### 10.4 Recommendation

**Don't rename for V2.** Ship V2 with the code fixes, correct documentation, and
the clear three-step mental model (Register → Consume → React). Get traction.

**Revisit naming before V3 or a marketing push.** At that point, if the library
has 1000+ downloads, a rename with a pub.dev redirect is worth the effort.

**If renaming: `zenith` is the strongest candidate.** Short, premium, compatible
with all internal naming, and the brand story is clear.
