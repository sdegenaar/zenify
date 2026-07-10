# Migrating from Zenify V1 to V2

> **TL;DR** — The only mechanical code change is adding a `controller` parameter to every `ZenView.build()` override. Everything else is optional cleanup.

---

## What Changed

| V1 | V2 | Notes |
|---|---|---|
| `build(BuildContext context)` + magic `controller` getter | `build(BuildContext context, T controller)` | **Breaking** — compiler enforces it |
| `get createController => () => MyController()` | `get initController => () => MyController()` | Renamed for clarity |
| `ZenBuilder<T>` | `ZenUpdater<T>` | `ZenBuilder` is a deprecated alias — still compiles |
| `ZenControllerScope<T>()` | `ZenScopeWidget.create<T>()` | Deprecated alias still compiles |
| `ZenView` is a `StatefulWidget` | `ZenView` extends `Widget` directly | Implementation detail — no user-facing impact |
| Global `_ZenViewRegistry` | Gone — no global registry | Structural isolation |

---

## Step 1 — Update the `build()` signature (required)

This is the only **required** change. In every `ZenView` subclass, add the controller type as a second parameter to `build()`.

```dart
// V1
class CartPage extends ZenView<CartController> {
  @override
  Widget build(BuildContext context) {
    return Text('${controller.totalItems}');   // magic getter — gone
  }
}

// V2
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

## Step 2 — Replace `createController` with `initController` (optional)

If you use the self-owned controller pattern, rename the override:

```dart
// V1
@override
MyController Function()? get createController => () => MyController();

// V2
@override
MyController Function()? get initController => () => MyController();
```

`createController` no longer exists — you'll get a compile error if you don't rename it.

---

## Step 3 — Replace `ZenControllerScope` with `ZenScopeWidget.create` (optional)

```dart
// V1 (deprecated, still compiles)
ZenControllerScope<MyController>(
  create: () => MyController(),
  child: const MyView(),
)

// V2 (recommended)
ZenScopeWidget.create<MyController>(
  create: () => MyController(),
  child: const MyView(),
)
```

---

## Step 4 — Replace `ZenBuilder` with `ZenUpdater` (optional)

`ZenBuilder<T>` is a deprecated `typedef` alias for `ZenUpdater<T>`. It compiles and works, but you'll get deprecation warnings. The API is identical:

```dart
// V1 (deprecated alias — still works)
ZenBuilder<CounterController>(
  builder: (controller) => Text('${controller.count}'),
)

// V2 (preferred)
ZenUpdater<CounterController>(
  builder: (context, controller) => Text('${controller.count}'),
)
```

> **Note:** The builder signature changed — V2 adds `BuildContext context` as the first parameter.

---

## Providing Controllers — Recommended V2 Pattern

In V1, pages often used `createController` to create their own controller. In V2, the recommended pattern is to provide the controller via `ZenScopeWidget` in the route, keeping the page itself clean:

```dart
// Router (GoRouter example)
GoRoute(
  path: '/cart',
  builder: (context, state) => ZenScopeWidget.create<CartController>(
    create: () => CartController(),
    child: const CartPage(),
  ),
)

// Page — purely declarative
class CartPage extends ZenView<CartController> {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, CartController controller) {
    return Scaffold(
      body: ZenObserver(() => Text('${controller.totalItems} items')),
    );
  }
}
```

For **per-instance widgets** (list items, cards) that need a controller with parameters from the widget itself, use `initController`:

```dart
class ChatBubble extends ZenView<ChatBubbleController> {
  final String messageId;
  const ChatBubble({required this.messageId, super.key});

  @override
  ChatBubbleController Function() get initController =>
      () => ChatBubbleController(messageId: messageId);

  @override
  Widget build(BuildContext context, ChatBubbleController controller) {
    return ZenObserver(() => Text(controller.formattedText.value));
  }
}
```

---

## Migration Checklist

- [ ] `dart analyze` — look for `invalid_override` on `ZenView.build`
- [ ] Add `, T controller` to every `ZenView.build()` override
- [ ] Remove any use of the old `controller` getter (now the parameter)
- [ ] Rename `createController` → `initController`
- [ ] Replace `ZenControllerScope` → `ZenScopeWidget.create` (or leave — still compiles)
- [ ] Replace `ZenBuilder` → `ZenUpdater` (or leave — still compiles with deprecation warning)
- [ ] `dart analyze` — confirm 0 errors
- [ ] `flutter test` — confirm all tests pass

---

## Need Help?

- [README](../README.md)
- [GitHub Issues](https://github.com/sdegenaar/zenify/issues)
- [GitHub Discussions](https://github.com/sdegenaar/zenify/discussions)
