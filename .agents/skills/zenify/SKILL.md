---
name: zenify-mastery
description: Comprehensive guide for Zenify state management framework (V2+). Trigger this when working on Flutter apps using Zenify for dependency injection, reactive state (.obs), ZenQuery (caching/offline), controllers, or route-bound modules.
---

# Zenify (V2+) Mastery Skill

Zenify is a tree-scoped Flutter state management framework combining hierarchical DI, fine-grained reactivity, and server-state management (`ZenQuery`). Zero global singletons. Zero code generation. All lifecycle disposal is automatic.

> **2,117 tests · 0 failures · >95% coverage** as of V2.0 release.
>
> For deep dives, see the **[Reference Docs](#deep-dive-references)** at the bottom.

---

## 1. Core Mental Model: 3-Tier Hierarchical Scoping

Every dependency is tree-bound via `BuildContext` — just like `Theme.of(context)`.

```
┌──────────────────────────────────────────────────────────────┐
│  RootScope (App Lifetime)                                    │
│  • True singletons: AuthService, ApiService, etc.            │
│  • Register: Zen.put(AuthService())  — ZenService auto-perm  │
│  • Access:  AuthService.to  /  Zen.find<AuthService>()       │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│  ModuleScope (Feature / Route Lifetime)                      │
│  • Shared controllers across a multi-page flow               │
│  • Register: ZenRoute(moduleBuilder: () => MyModule(), ...)  │
│  • Access:  ZenView<T>  /  ZenConsumer<T>                    │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│  PageScope (Page / Local Lifetime)                           │
│  • Single-page UI controllers                                │
│  • Register: ZenProvider.create<T>(create: () => T(), ...)   │
│  • Access:  ZenView<T>  /  ZenConsumer<T>                    │
└──────────────────────────────────────────────────────────────┘
```

| Needed where?    | Use                                                   |
| :--------------- | :---------------------------------------------------- |
| Entire app       | `ZenService` + `Zen.put()` + `.to` static getter      |
| Across a feature | `ZenModule` + `ZenRoute(moduleBuilder: ...)`          |
| One page only    | `ZenProvider.create<T>(create: () => T())` + `ZenView<T>` |

---

## 2. Registration (V2 API — Exact Params)

```dart
// Module — V2 API: register(ZenScope scope) + scope.put<T>()
class CheckoutModule extends ZenModule {
  @override
  String get name => 'CheckoutModule';

  @override
  void register(ZenScope scope) {
    scope.put<CheckoutController>(
      CheckoutController(
        cart: Zen.find<CartService>()!,        // root service — global lookup
        payment: scope.find<PaymentService>()!, // ancestor scope — tree walk
      ),
    );
    scope.put<AddressController>(AddressController());
  }
}

// ZenRoute — V2 API: moduleBuilder: and page: (NOT module: or child:)
GoRoute(
  path: '/checkout',
  builder: (context, state) => ZenRoute(
    moduleBuilder: () => CheckoutModule(),
    page: const CheckoutPage(),
    scopeName: 'CheckoutScope', // optional — aids debug logs
  ),
);

// Single-controller shortcut — no module needed
ZenProvider.create<LoginController>(
  create: () => LoginController(auth: Zen.find<AuthService>()!),
  child: const LoginPage(),
)
```

**Scope inheritance rules:**
- `ZenRoute` connects to `Zen.rootScope` as parent → `scope.find<T>()` resolves root services ✅
- `ZenProvider` (bare) does NOT → use `Zen.find<T>()` inside controllers instead ✅

---

## 3. Consuming Controllers

```dart
// ZenView<T> — primary pattern; controller injected into build() — compiler-enforced
class CheckoutPage extends ZenView<CheckoutController> {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context, CheckoutController controller) {
    return Scaffold(
      body: ZenObserver(() => Text('\$${controller.total.value}')),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.placeOrder,
        child: const Icon(Icons.check),
      ),
    );
  }
}

// ZenConsumer<T> — for sub-widgets that can't extend ZenView
ZenConsumer<CheckoutController>(
  builder: (context, controller) => Text('\$${controller.total.value}'),
);

// context.controller<T>() — imperative, throws ZenControllerNotFoundException if missing
final ctrl = context.controller<CheckoutController>();

// Global services — .to pattern (works anywhere, including widgets)
ZenObserver(() => Text('${CartService.to.items.length} items'))
```

> ❌ **V1 pattern removed:** `Widget build(BuildContext context)` with a magic `controller` getter no longer exists.

---

## 4. Reactivity

```dart
// Declare
final count = 0.obs();           // RxInt
final name = ''.obs();           // Rx<String>
final isLoading = false.obs();   // RxBool — .toggle(), .isTrue, .isFalse
final user = Rx<User?>(null);    // Nullable
final items = <String>[].obs();  // RxList — mutating methods auto-notify
final map = <String, dynamic>{}.obs(); // RxMap
final tags = <String>{}.obs();   // RxSet

// Computed — auto-tracks deps, lazy
late final greeting = computed(() => 'Hello, ${name.value}!');

// Observe in UI — wrap MINIMAL subtree
ZenObserver(() => Text('Count: ${controller.count.value}'))

// ZenUpdater<T> — for non-reactive state; rebuilds on controller.update()
ZenUpdater<ManualController>(
  id: 'counter',
  builder: (context, ctrl) => Text('${ctrl.count}'),
)
```

---

## 5. Controllers & Services

```dart
class ProfileController extends ZenController {
  final UserService _svc;
  ProfileController(this._svc);

  final name = ''.obs();

  @override void onInit() { super.onInit(); _load(); }
  Future<void> _load() async => name.value = (await _svc.getProfile()).name;

  // Lifecycle: onInit → onReady → onPause / onResume → onClose
}

class AuthService extends ZenService {
  // ZenService extends ZenController — auto-permanent, no isPermanent: true needed
  static AuthService get to => Zen.find<AuthService>()!;
  final isAuthenticated = false.obs();
}

// main.dart
void main() async {
  await Zen.init();
  Zen.put(AuthService());               // ZenService — auto-permanent ✅
  Zen.put<ThemeController>(            // plain ZenController — explicit flag required ✅
    ThemeController(), isPermanent: true,
  );
  runApp(const MyApp());
}
```

---

## 6. Workers

```dart
// All 4 workers are shorthand methods on ZenController (call inside onInit)
debounce(query, (val) => search(val), time: const Duration(milliseconds: 300));
ever(query, (val) => log(val));
once(query, (val) => analytics.track(val));
interval(query, (val) => suggest(val), time: const Duration(seconds: 1));

// ZenWorkers.* static factory returns a ZenWorker with .pause()/.resume()/.dispose()
```

---

## 7. ZenQuery (Async Server State)

```dart
// Define — in a controller
late final userQuery = ZenQuery<User>(
  queryKey: ['user', 'current'],
  fetcher: (token) async {
    final ct = CancelToken();           // e.g. Dio's CancelToken
    token.onCancel(() => ct.cancel()); // wire cancel token
    return api.fetchCurrentUser(cancelToken: ct);
  },
  config: const ZenQueryConfig(
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(hours: 1),
    retryCount: 3,
    persist: true,                     // requires ZenStorage registered
    enableBackgroundRefetch: true,
  ),
  tags: ['user', 'profile'],
);

// Consume — .when() shorthand (cleanest)
controller.userQuery.when(
  data: (user) => Text(user.name),
  loading: () => const CircularProgressIndicator(),
  error: (e, retry) => ErrorView(e, onRetry: retry),
);

// Invalidate
ZenQueryCache.instance.invalidateQuery('user:current');
ZenQueryCache.instance.invalidateQueries(ZenQueryFilter(tags: ['user']));
```

> **ZenQuery vs ZenEffect:** Use `ZenQuery` for server data that benefits from caching/offline. Use `ZenEffect` for one-shot operations (save, submit, upload) with no caching.

---

## 8. GoRouter — Key Patterns

```dart
// Basic: moduleBuilder + page params
GoRoute(
  path: '/profile/:id',
  builder: (context, state) => ZenRoute(
    moduleBuilder: () => ProfileModule(state.pathParameters['id']!),
    page: const ProfilePage(),
  ),
);

// ShellRoute — canonical V2 hierarchical DI (child scopes inherit automatically)
ShellRoute(
  builder: (context, state, child) => ZenRoute(
    moduleBuilder: () => AppShellModule(),
    page: AppShell(child: child),
  ),
  routes: [
    GoRoute(
      path: '/feed',
      builder: (context, state) => ZenRoute(   // inherits AppShell scope — zero config
        moduleBuilder: () => FeedModule(),
        page: const FeedPage(),
      ),
    ),
  ],
)
```

---

## 9. Widget Taxonomy

| Widget | Role | When to Use |
| :--- | :--- | :--- |
| `ZenProvider` | Provide — scope from a module | Multi-controller feature roots |
| `ZenProvider.create<T>` | Provide — single controller | Simple single-controller pages |
| `ZenRoute` | Provide — scope + route lifecycle | GoRouter / Navigator routes |
| `ZenView<T>` | Consume (extend) — page base class | Pages, screens |
| `ZenConsumer<T>` | Consume (compose) — inline builder | Sub-widgets |
| `ZenObserver` | React — rebuilds on `Rx<T>` changes | Reactive value display |
| `ZenUpdater<T>` | React — rebuilds on `update()` | Manual / batched rebuilds |
| `ZenQueryBuilder<T>` | Async — observes `ZenQuery` | Controller-owned queries |
| `ZenQueryConsumer<T>` | Async — self-contained query | Standalone queries |
| `ZenEffectBuilder<T>` | Async — observes `ZenEffect` | One-shot async operations |

**Key principle:** DI access and reactivity are separate concerns — compose `ZenView` + `ZenObserver`, never conflate them.

---

## 10. Critical Anti-Patterns

| ❌ ANTI-PATTERN | ✅ IDIOMATIC V2 |
| :--- | :--- |
| V1 `void dependencies() { register(() => ...) }` | `void register(ZenScope scope) { scope.put<T>(...) }` |
| `ZenRoute(module: M(), child: Page())` | `ZenRoute(moduleBuilder: () => M(), page: Page())` |
| `build(BuildContext context)` + magic `controller` getter | `build(BuildContext context, MyController controller)` |
| `Zen.put(CartController())` for UI state | `ZenProvider.create` or `ZenRoute` + module |
| Reading `.value` outside `ZenObserver` | Wrap in `ZenObserver(() => ...)` |
| `FutureBuilder` for network data | `ZenQuery` + `.when()` |
| `isPermanent: true` on `Zen.put(MyService())` | Just `Zen.put(MyService())` — `ZenService` is auto-permanent |
| `ZenView<T>` to consume a `Zen.put<T>()` controller | `ZenObserver` + `.to` static getter |

---

## 11. Migration Cheat Sheet

| From GetX | From Riverpod / Provider | Zenify V2 |
| :--- | :--- | :--- |
| `Get.put(Ctrl())` | `ChangeNotifierProvider` | `ZenRoute(moduleBuilder:...)` / `ZenProvider.create` |
| `Get.find<Ctrl>()` | `Provider.of<T>(context)` | `context.controller<T>()` / `Zen.find<T>()` |
| `Obx(() => ...)` | `Consumer<T>` / `ref.watch` | `ZenObserver(() => ...)` |
| `GetxController` | `ChangeNotifier` / `Notifier` | `ZenController` |
| `GetxService` | Permanent Provider | `ZenService` (auto-permanent) |
| `FutureProvider` / `AsyncValue` | Handcrafted `bool _isLoading` | `ZenQuery<T>` + `.when()` |
| `ZenBuilder<T>` (V1) | — | `ZenUpdater<T>` (renamed) |
| `ZenControllerScope<T>` (V1) | — | `ZenProvider.create<T>` |

---

## 12. Key Verified V2 Behaviours

1. `scope.find<T>()` **walks the parent chain upward** — resolves from any ancestor scope.
2. `ZenRoute` **connects to `Zen.rootScope` as parent** — root services accessible inside `register()`.
3. `ZenProvider` (bare) **does NOT** connect to `Zen.rootScope` — use `Zen.find<T>()` in controllers.
4. `ZenService` is **auto-permanent** — `isPermanent: true` flag is redundant.
5. `ZenController` is **not auto-permanent** — pass `isPermanent: true` explicitly for global registration.
6. `ZenObserver` is **not scope-bound** — works with both tree-scoped and globally-registered state.
7. `ZenView` is **strictly tree-bound** — `Zen.put<T>()` + `ZenView<T>` always throws `ZenControllerNotFoundException`.

---

## Deep-Dive References

These are the authoritative maintained docs — the agent should read them for detailed implementation guidance:

| Topic | File |
| :--- | :--- |
| Architecture & Design Decisions | [`doc/v2_architecture_design.md`](../../../doc/v2_architecture_design.md) |
| Reactive Core (all Rx types, computed, workers) | [`doc/reactive_core_guide.md`](../../../doc/reactive_core_guide.md) |
| ZenQuery (full config, pagination, streaming) | [`doc/zen_query_guide.md`](../../../doc/zen_query_guide.md) |
| Offline-First & ZenStorage | [`doc/offline_guide.md`](../../../doc/offline_guide.md) |
| Effects (`ZenEffect`, `createEffect`) | [`doc/effects_usage_guide.md`](../../../doc/effects_usage_guide.md) |
| GoRouter + ShellRoute | [`doc/gorouter_guide.md`](../../../doc/gorouter_guide.md) |
| Hierarchical Scopes (deep) | [`doc/hierarchical_scopes_guide.md`](../../../doc/hierarchical_scopes_guide.md) |
| State Management Patterns | [`doc/state_management_patterns.md`](../../../doc/state_management_patterns.md) |
| Testing (RxTester, ZenTestContainer) | [`doc/testing_guide.md`](../../../doc/testing_guide.md) |
| Real-World Patterns (infinite scroll, mutations) | [`doc/real_world_patterns.md`](../../../doc/real_world_patterns.md) |
| Migration from V1 / GetX / Riverpod | [`doc/migration_guide.md`](../../../doc/migration_guide.md) |
