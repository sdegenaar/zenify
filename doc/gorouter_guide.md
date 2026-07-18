# GoRouter Integration Guide

Zenify works with any Flutter router. This guide shows how to use `ZenRoute` with [GoRouter](https://pub.dev/packages/go_router) — the recommended navigation package.

---

## Setup

```yaml
# pubspec.yaml
dependencies:
  zenify: ^2.0.0
  go_router: ^14.0.0
```

---

## Basic Pattern

Wrap each GoRouter `builder` with `ZenRoute`. This creates a scoped dependency
injection context for the page and tears it down automatically when you navigate away.

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => ZenRoute(
        moduleBuilder: () => HomeModule(),
        page: const HomePage(),
      ),
    ),
    GoRoute(
      path: '/profile/:id',
      builder: (context, state) => ZenRoute(
        moduleBuilder: () => ProfileModule(state.pathParameters['id']!),
        page: const ProfilePage(),
        scopeName: 'ProfileScope', // optional — useful for debug logging
      ),
    ),
  ],
);
```

---

## Defining a Module

```dart
class ProfileModule extends ZenModule {
  final String userId;
  ProfileModule(this.userId);

  @override
  String get name => 'ProfileModule';

  @override
  void register(ZenScope scope) {
    scope.put<ProfileRepository>(ProfileRepository());
    scope.put<ProfileController>(
      ProfileController(userId: userId, repo: scope.find()!),
    );
  }
}
```

---

## Accessing Scoped Dependencies

For a clean class-level syntax, the best approach is to extend `ZenView<T>`. The scoped controller is injected directly into `build()` — no getter magic, compiler-enforced:

```dart
class ProfilePage extends ZenView<ProfileController> {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, ProfileController controller) {
    // Controller is injected directly — no magic getter needed.
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      // ZenQuery.when handles its own reactivity so ZenUpdater isn't required here.
      // If you are relying on controller.update(), wrap reactive portions in ZenUpdater.
      body: controller.userQuery.when(
        data: (user) => UserCard(user),
        loading: () => const CircularProgressIndicator(),
        error: (e, retry) => ErrorView(e, onRetry: retry),
      ),
    );
  }
}
```

### Alternative: Using `StatelessWidget` with `ZenUpdater`

If your page already extends `StatelessWidget` or another widget class, you can use `ZenUpdater<T>` to rebuild when `controller.update()` is called:

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ZenUpdater<ProfileController>(
      builder: (context, controller) {
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: controller.userQuery.when(
            data: (user) => UserCard(user),
            loading: () => const CircularProgressIndicator(),
            error: (e, retry) => ErrorView(e, onRetry: retry),
          ),
        );
      },
    );
  }
}
```

---

## Nested Routes (ShellRoute) — Canonical V2 Pattern

For nested navigation with a shared shell (e.g., bottom nav bar, split views, or deep sub-flows), use `ShellRoute` with a parent `ZenRoute` at the shell level.

> [!TIP]
> **Why is this important in V2?** 
> Standard flat routes (like `context.push` or `GoRoute` without a shell) create detached overlays that break the widget tree. If you use flat routes, you must explicitly pass `parentScope` to inherit dependencies.
> 
> Because `ShellRoute` renders its children *inside* the widget tree, Zenify can automatically walk up the tree to discover parent scopes. **This is the canonical, zero-config way to implement deep hierarchical dependency injection in Zenify V2.**

The `ShellRoute`'s `child` argument can be passed directly as `page` — the `ZenRoute` scope wraps it, and all child routes inherit automatically. For apps with a persistent scaffold (e.g., bottom nav bar), you wrap `child` in your shell widget instead:

```dart
// --- Variant A: Deep sub-flow (no persistent shell UI) ---
ShellRoute(
  builder: (context, state, child) => ZenRoute(
    moduleBuilder: () => DepartmentsModule(),
    scopeName: 'DepartmentsScope',
    page: child, // child is the nested Navigator — rendered inside the scope!
  ),
  routes: [
    GoRoute(
      path: '/departments',
      builder: (context, state) => const DepartmentsPage(),
    ),
    GoRoute(
      path: '/departments/detail/:id',
      // Zero-config: automatically inherits DepartmentsScope!
      builder: (context, state) => ZenRoute(
        moduleBuilder: () => DepartmentDetailModule(state.pathParameters['id']!),
        page: DepartmentDetailPage(departmentId: state.pathParameters['id']!),
      ),
    ),
  ],
)
```

```dart
// --- Variant B: Bottom nav bar (persistent shell UI) ---
ShellRoute(
  builder: (context, state, child) => ZenRoute(
    moduleBuilder: () => AppShellModule(),
    scopeName: 'AppShell',
    page: AppShell(child: child), // wrap child in your shell widget
  ),
  routes: [
    GoRoute(
      path: '/feed',
      // Automatically inherits AppShell scope
      builder: (context, state) => ZenRoute(
        moduleBuilder: () => FeedModule(),
        page: const FeedPage(),
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => ZenRoute(
        moduleBuilder: () => SettingsModule(),
        page: const SettingsPage(),
      ),
    ),
  ],
)
```

In both variants, because the widget tree remains intact inside the shell, all child `ZenRoute` scopes automatically inherit from the parent scope — no explicit `parentScope` needed.


---

## Passing Route Parameters

Pass route state into modules via the constructor:

```dart
GoRoute(
  path: '/product/:id',
  builder: (context, state) => ZenRoute(
    moduleBuilder: () => ProductModule(
      productId: state.pathParameters['id']!,
      // Extra params from query string, state object, etc.
      referrer: state.uri.queryParameters['ref'],
    ),
    page: const ProductPage(),
  ),
),
```

---

## Named Routes

Named routes work identically — `ZenRoute` is route-agnostic:

```dart
GoRoute(
  path: '/cart',
  name: 'cart',
  builder: (context, state) => ZenRoute(
    moduleBuilder: () => CartModule(),
    page: const CartPage(),
  ),
),

// Navigate
context.goNamed('cart');
```

---

## Redirects & Guards

Place guards before `ZenRoute` — the module only initializes if navigation succeeds:

```dart
GoRoute(
  path: '/dashboard',
  redirect: (context, state) async {
    final isLoggedIn = await AuthService.isLoggedIn();
    return isLoggedIn ? null : '/login';
  },
  builder: (context, state) => ZenRoute(
    moduleBuilder: () => DashboardModule(),
    page: const DashboardPage(),
  ),
),
```

---

## Custom Loading & Error States

```dart
ZenRoute(
  moduleBuilder: () => HeavyModule(),
  page: const HeavyPage(),
  loadingWidget: const Scaffold(
    body: Center(child: Text('Initializing...')),
  ),
  onError: (error) => Scaffold(
    body: Center(child: Text('Failed: $error')),
  ),
)
```

---

## Scope Lifecycle

`ZenRoute` automatically:
- Creates the scope when the route is pushed
- Calls `module.onInit(scope)` after registration
- Calls `module.onDispose(scope)` when the route is popped
- Disposes the scope and all registered dependencies

No manual cleanup needed.

---

## See Also

- [`ZenRoute` API reference](../lib/widgets/components/zen_route.dart)
- [Module Guide](zen_module_guide.md)
- [Migration Guide](migration_guide.md)
