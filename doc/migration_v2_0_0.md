# Migrating from Zenify V1 to V2

> **TL;DR** — Two mechanical changes: (1) add a `controller` parameter to every `ZenView.build()` override, and (2) wrap your views in `ZenProvider`. Everything else follows naturally.

---

## What Changed

| V1 | V2 | Impact |
|---|---|---|
| `build(BuildContext context)` + magic `controller` getter | `build(BuildContext context, T controller)` | **Breaking** — compiler enforces it |
| `get createController => () => MyController()` | Removed — use `ZenProvider.create` | **Breaking** — must migrate |
| `ZenControllerScope<T>()` | **Removed** — use `ZenProvider.create<T>()` | **Breaking** — no fallback |
| `ZenScopeWidget` | Renamed to `ZenProvider` | **Breaking** — rename import |
| `ZenBuilder<T>` | `ZenUpdater<T>` (`ZenBuilder` is a deprecated alias) | Non-breaking — compiles with warning |
| Global `Zen.put` for UI controllers | Scoped via `ZenProvider` in widget tree | Architectural shift |
| Global `_ZenViewRegistry` | Gone — no global registry | Structural isolation |

---

## Step 1 — Update the `build()` signature (required)

Add the controller type as a second explicit parameter to `build()` in every `ZenView` subclass.

```dart
// ❌ V1
class CartPage extends ZenView<CartController> {
  @override
  Widget build(BuildContext context) {
    return Text('${controller.totalItems}');   // magic getter — removed
  }
}

// ✅ V2
class CartPage extends ZenView<CartController> {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, CartController controller) {
    return Text('${controller.totalItems}');   // explicit, compiler-enforced
  }
}
```

**`dart analyze` will surface every instance** — look for `invalid_override` errors.

---

## Step 2 — Provide controllers via `ZenProvider` (required)

In V2, controllers are **not** created inside `ZenView`. They must be provided by a `ZenProvider` somewhere above the view in the widget tree. The most common place is the route builder.

```dart
// ✅ GoRouter example
GoRoute(
  path: '/cart',
  builder: (context, state) => ZenProvider.create<CartController>(
    create: () => CartController(),
    child: const CartPage(),
  ),
)

// ✅ Navigator.push example
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ZenProvider.create<CartController>(
      create: () => CartController(),
      child: const CartPage(),
    ),
  ),
);
```

The controller is scoped to that subtree — it is automatically disposed when the route is popped.

---

## Step 3 — Replace `ZenControllerScope` (required if used)

`ZenControllerScope` has been **removed entirely** in V2. Replace every usage with `ZenProvider.create`:

```dart
// ❌ V1 — ZenControllerScope (removed)
ZenControllerScope<MyController>(
  create: () => MyController(),
  child: const MyView(),
)

// ✅ V2 — ZenProvider.create
ZenProvider.create<MyController>(
  create: () => MyController(),
  child: const MyView(),
)
```

The APIs are intentionally identical — this is a mechanical find-and-replace.

---

## Step 4 — Replace `ZenScopeWidget` (required if used)

`ZenScopeWidget` has been renamed to `ZenProvider`. Update any direct references:

```dart
// ❌ V1
ZenScopeWidget.create<T>(create: ..., child: ...)
ZenScopeWidget(scope: myScope, child: ...)

// ✅ V2
ZenProvider.create<T>(create: ..., child: ...)
ZenProvider(scope: myScope, child: ...)
```

---

## Step 5 — Replace `ZenBuilder` with `ZenUpdater` (optional)

`ZenBuilder<T>` is a deprecated alias for `ZenUpdater<T>`. It still compiles but will produce deprecation warnings. The API is identical except the builder signature now includes `BuildContext`:

```dart
// ⚠️ V1 (deprecated alias — still works, shows warning)
ZenBuilder<CounterController>(
  builder: (controller) => Text('${controller.count}'),
)

// ✅ V2 (preferred)
ZenUpdater<CounterController>(
  builder: (context, controller) => Text('${controller.count}'),
)
```

---

## Understanding the Architecture Shift

V2 makes one core philosophical change: **controller lifecycle belongs to the DI scope, not the widget.**

```
V1 mental model:  Widget → creates → Controller
V2 mental model:  ZenProvider → owns → Controller → Widget reads from scope
```

This means:
- Controllers are never created inside `build()` or widget constructors
- A controller lives exactly as long as its `ZenProvider` is in the tree
- Multiple widgets under the same `ZenProvider` share the same controller instance
- Popping a route automatically disposes all controllers scoped to it

For **module-level** dependencies (auth, database, analytics), use `ZenModule` with a root-level `ZenProvider` in your app widget:

```dart
// main.dart
runApp(
  ZenProvider(
    moduleBuilder: () => AppModule(),
    child: const MyApp(),
  ),
);
```

---

## Migration Checklist

- [ ] `dart analyze` — look for `invalid_override` on `ZenView.build`
- [ ] Add `, T controller` to every `ZenView.build()` override
- [ ] Remove any use of the old `controller` getter (now the parameter)
- [ ] Find all `ZenControllerScope` usages → replace with `ZenProvider.create`
- [ ] Find all `ZenScopeWidget` usages → rename to `ZenProvider`
- [ ] Remove `createController` / `initController` overrides → move to `ZenProvider.create` at the route level
- [ ] Replace `ZenBuilder` → `ZenUpdater` (or leave — still compiles with deprecation warning)
- [ ] `dart analyze` — confirm 0 errors
- [ ] `flutter test` — confirm all tests pass

---

## Need Help?

- [README](../README.md)
- [GitHub Issues](https://github.com/sdegenaar/zenify/issues)
- [GitHub Discussions](https://github.com/sdegenaar/zenify/discussions)
