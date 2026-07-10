# Zenify V2: Architecture Design & Rationale

**Authors**: Package Owner + Architect  
**Date**: July 2026  
**Status**: Design — Approved for V2 Development  
**Context**: Architectural design session. No code changes in this document.

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

## 2. What We Did in V1.x (The Current Session)

Before designing V2, we shipped several correctness fixes in V1.x to be production-stable:

### 2.1 Stack-Based Registry (shipped in this session)

**Old:** `Map<Type, ZenController>` — last writer wins. Navigation to a second `CartPage` would overwrite the first. Returning to the first page would get a disposed controller or the wrong one.

**New:** `Map<Type, List<ZenController>>` — a stack. Mount pushes, dispose pops, `peek()` returns the innermost (most recently mounted) instance.

```dart
class _ZenViewRegistry {
  static final Map<Type, List<ZenController>> _stack = {};
  static void push<T extends ZenController>(T c) => _stack.putIfAbsent(T, () => []).add(c);
  static void pop<T extends ZenController>()    => _stack[T]?.removeLast();
  static T? peek<T extends ZenController>()     => _stack[T]?.lastOrNull as T?;
}
```

This fixes **sequential** multi-instance (navigate to A, navigate to B, back to A). It does NOT fix **simultaneous** multi-instance (both A and B on screen at the same time), because `peek()` always returns the innermost, making A's `controller` getter return B's instance when A rebuilds while B is also mounted.

**Verdict:** The stack is the best V1-compatible fix. It improves correctness without breaking any user API. But it is still a workaround for the fundamental architectural constraint.

### 2.2 ZenScopeView Removed

`ZenScopeView` was a class that wrapped `context.controller<T>()` in a base class — one line of logic wrapped in an abstraction. It was never published and was deleted. The correct idiom for its use case is:

```dart
// A plain StatelessWidget consuming a controller from scope:
class CartSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.controller<CartController>();
    return Text('${controller.totalPrice}');
  }
}
```

### 2.3 ZenScopeProvider Hidden from Public API

`ZenScopeProvider` is an implementation detail (the `InheritedWidget` that carries a `ZenScope`). It was hidden from the public barrel exports using Dart's `hide` mechanism. Developers who need it can import it directly but won't see it via the main package import.

### 2.4 `context.controller<T>()` Cleaned Up

The `ZenViewContextExtensions.controller<T>()` method previously had a step that looked up the global `_ZenViewRegistry`. This was removed. The extension now resolves purely via the widget tree:

1. Nearest `ZenScope` in the widget tree
2. Global `Zen.findOrNull<T>()` fallback

This means `context.controller<T>()` is 100% tree-bound and multi-instance safe by definition. It is the canonical API for non-`ZenView` widgets.

---

## 3. The V2 Architecture Vision

### 3.1 The Core Principle

> **Every controller access must be tree-bound via `BuildContext`.**

This is how Flutter itself works. `Theme.of(context)`, `MediaQuery.of(context)`, `Navigator.of(context)` — every Flutter primitive uses `BuildContext` to traverse the tree. State management should be no different.

### 3.2 `ZenView<T>` — Injected Build Method

The single most important V2 change: `build(BuildContext context)` becomes `build(BuildContext context, T controller)`.

```dart
// V2
abstract class ZenView<T extends ZenController> extends StatelessWidget {
  const ZenView({super.key});

  // Controller is injected — resolved from the tree by the framework,
  // not from a global registry.
  Widget build(BuildContext context, T controller);

  @override
  Widget build(BuildContext context) {
    return build(context, context.controller<T>());
  }
}
```

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

### 3.3 `ZenConsumer<T>` — New Inline Widget

For components that are NOT full pages but need to access a controller inline:

```dart
// V2 — no base class needed, pure composition
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

**Naming rationale:** "Consumer" is industry-standard vocabulary for this pattern (see Provider, Riverpod). It immediately communicates "I consume state that was provided above me."

### 3.4 `ZenScopeWidget` — The Canonical Provider

Controller creation moves from the widget to the scope or route level. The view no longer creates the controller — it consumes it.

```dart
// V2 — separation of provide and consume
// At the route level (e.g., GoRouter):
GoRoute(
  path: '/cart',
  builder: (context, state) => ZenScopeWidget(
    create: () => CartController(),  // creation lives here
    child: const CartPage(),         // consumption lives here
  ),
)

// Or inline in the widget tree:
ZenScopeWidget(
  create: () => CartController(),
  child: CartPage(),
)
```

**Why this matters:**

1. `CartPage` no longer carries the knowledge of how to create its controller. Dependency creation is a DI concern, not a UI concern.
2. The controller's lifecycle is tied to the `ZenScopeWidget` — when the scope unmounts, the controller is disposed. This is deterministic and correct.
3. Tests become trivially isolated:

```dart
// V2 test — no setUp/tearDown, no Zen.reset(), no bleed between tests
testWidgets('cart shows total price', (tester) async {
  await tester.pumpWidget(
    ZenScopeWidget(
      create: () => CartController()..totalPrice.value = 42.0,
      child: const CartPage(),
    ),
  );
  expect(find.text('\$42.00'), findsOneWidget);
}); // scope disposes with the widget tree — automatic cleanup
```

### 3.5 Context Extensions — The Canonical Consumer API

The most ergonomic and idiomatic way to access a controller from any widget is the context extension. This is already the V1.x canonical API for non-`ZenView` widgets.

In V2, this becomes the **primary** API surface — not `ZenView.controller`:

```dart
// Generic (package provides this)
extension ZenContextExt on BuildContext {
  T controller<T extends ZenController>({String? tag}) { ... }
}

// Typed (developer writes this for their domain)
extension CartContextExt on BuildContext {
  CartController get cart => controller<CartController>();
}

// Usage — reads like domain language, not framework plumbing
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

### 3.6 Global DI — Bounded to True Singletons

`Zen.put()` (global DI) is NOT abolished in V2. But its proper use is clarified:

| Use Case | Correct Location |
|---|---|
| UI controller (CartController, ChatController) | `ZenScopeWidget` — scope-bound |
| True singleton service (AuthService, NetworkService, Analytics) | `Zen.put()` — global DI |

The distinction is lifecycle. A `CartController` dies when you leave the cart screen. An `AuthService` lives for the entire app session. Global DI is correct for the latter. Scope is correct for the former.

```dart
// Correct: services registered globally before runApp
void main() {
  Zen.put(AuthService());
  Zen.put(NetworkService());
  runApp(const MyApp());
}

// Correct: UI controllers in scope
ZenScopeWidget(
  create: () => CartController(), // tied to the cart screen's lifecycle
  child: const CartPage(),
)

// Wrong in V2: UI controller in global DI
Zen.put(CartController()); // ← what lifecycle does this have?
```

---

## 4. The V2 Widget Taxonomy

| Widget | Pattern | Use Case | Reactive? |
|---|---|---|---|
| `ZenScopeWidget` | Provide | Creates and scopes a controller | No — provides |
| `ZenView<T>` | Consume (extend) | Full page/screen base class | Via `ZenObserver` inside |
| `ZenConsumer<T>` | Consume (compose) | Inline controller access in any widget | Via `ZenObserver` inside |
| `ZenObserver` | React | Reactive rebuild on `Rx<T>` changes | Yes — Rx values |
| `ZenBuilder<T>` | React | Reactive rebuild on `update()` calls | Yes — manual update |

**Key principle:** DI access (`ZenView`, `ZenConsumer`) and reactivity (`ZenObserver`, `ZenBuilder`) are separate concerns. Compose them rather than conflating them.

---

## 5. Why We're Making This Breaking Change

### 5.1 "Easy" vs "Simple"

The V1 `controller` getter is **easy** — one word, no arguments, magically resolves. But it hides complexity that surfaces at the wrong moment: when you're in production with a multi-instance bug and you have no mental model for why it's happening.

The V2 injected parameter is **simple** — the controller is explicitly given to you by the framework. When it goes wrong, you know exactly where to look. When you extract a helper method, the compiler tells you exactly what to pass.

There is a difference between easy-to-start and simple-to-understand. Zenify V2 optimizes for the latter.

### 5.2 The GetX Lesson

GetX made the same trade-off (easy over simple) and paid for it with:
- Global state that bleeds between tests
- Multi-instance navigation bugs that are nearly impossible to debug
- A mental model that does not transfer to how Flutter actually works

Zenify V1 was "GetX but slightly better." Zenify V2 is a genuinely different, architecturally sound framework that happens to be ergonomic.

### 5.3 Riverpod's Precedent

When Riverpod launched, it broke everything from Provider. Developers complained. Then they realized Riverpod was correct, and it became the architectural standard. 

**Correctness always wins in the long run.** Developers who build serious applications choose the tool that works correctly, even if the migration is painful.

### 5.4 Zenify Has Outgrown GetX Compatibility

Zenify has built:
- A genuine `ZenScope` hierarchy with inheritance, isolation, and lifecycle management
- A `ZenQuery` system that is unique in the Flutter ecosystem (TanStack Query semantics)
- A reactive primitive system (`Rx<T>`, `ZenObserver`, workers) that is correct and performant

These are features GetX cannot replicate. Zenify no longer needs GetX compatibility as a crutch for adoption. It can stand on its own architectural merit.

---

## 6. Migration Strategy

### 6.1 The Mechanical Change

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

### 6.2 Phased Rollout

1. **V1.x (current):** Stack-based registry fix. `context.controller<T>()` established as canonical for non-`ZenView` widgets. `ZenScopeView` removed.
2. **V2.0-alpha:** `ZenView` gains injected `build(context, controller)`. `ZenConsumer<T>` added. Old signature deprecated with clear IDE warnings.
3. **V2.0:** Old signature removed. `_ZenViewRegistry` deleted. `createController` factory deprecated (moved to `ZenScopeWidget`).

### 6.3 Version and Documentation

- Bump to `2.0.0` — this is a SEMVER major version
- Publish a migration guide (extending the existing `doc/migration_guide.md`)
- Provide a migration script via the `tool/` directory
- Update all examples

---

## 7. Open Questions for V2 Design

1. **Should `createController` factory be kept on `ZenView` as a convenience?** It conflates DI with UI but reduces boilerplate for simple cases. Could be kept but deprecated.

2. **Should `ZenView` automatically create its own `ZenScope`?** This would make `context.controller<T>()` work naturally inside `build(context, controller)` for child widgets, even if the parent route didn't wrap in `ZenScopeWidget`. Trade-off: every `ZenView` instance creates a scope object.

3. **`ZenConsumer<T>` — should it rebuild reactively on `update()` calls?** Or is it purely structural (just DI access), with reactivity delegated to `ZenObserver` inside? Recommendation: structural only, to maintain the clean separation of DI and reactivity.

4. **`ZenBuilder<T>` naming conflict?** In V1, `ZenBuilder<T>` does reactive rebuilds on `update()` calls. In V2, with `ZenConsumer<T>` as the pure DI widget, `ZenBuilder<T>` could be renamed `ZenUpdater<T>` to distinguish its reactive purpose. Breaking change, but clearer semantics.

5. **`ZenRootScope` vs `Zen.put()`?** Global DI (`Zen.put()`) is valid for true singletons. But a `ZenRootScope` widget wrapping `runApp` would make tests cleaner (no global state at all). Worth considering for V3.

---

## 8. Summary

The V2 architecture has one core principle: **every controller access is tree-bound via `BuildContext`**. This is achieved through:

1. `ZenView<T>` injects the controller into `build(context, T controller)` — no global registry
2. `ZenConsumer<T>` provides inline composition without inheritance — scope-bound, multi-instance safe
3. `ZenScopeWidget` is the canonical provider — separates creation from consumption
4. `context.controller<T>()` is the canonical API — tree-bound, testable, idiomatic Flutter
5. Global DI (`Zen.put()`) is bounded to true singleton services

The result is a framework that is architecturally equivalent to Riverpod in correctness, familiar in naming, and unique in its reactive primitives (`ZenObserver`, `ZenQuery`).

This is Zenify for 2026 and beyond.
