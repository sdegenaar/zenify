# GoRouter Integration Guide

Zenify works with any Flutter router. This guide shows how to use `ZenRoute` with [GoRouter](https://pub.dev/packages/go_router) — the recommended navigation package.

---

## Setup

```yaml
# pubspec.yaml
dependencies:
  zenify: ^1.10.0
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

For a clean class-level syntax, the best approach is to extend `ZenView<T>`. This automatically locates your scoped controller and makes it available via the `controller` getter:

```dart
class ProfilePage extends ZenView<ProfileController> {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Controller is automatically found in the scope and ready to use!
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      // ZenQuery.when handles its own reactivity so ZenBuilder isn't required here.
      // If you are relying on controller.update(), wrap reactive portions in ZenBuilder.
      body: controller.userQuery.when(
        data: (user) => UserCard(user),
        loading: () => const CircularProgressIndicator(),
        error: (e, retry) => ErrorView(e, onRetry: retry),
      ),
    );
  }
}
```

### Alternative: Using `StatelessWidget` with `ZenBuilder`

If your page already extends `StatelessWidget` or another widget class, you can use `ZenBuilder<T>` to automatically fetch and react to the controller:

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ZenBuilder<ProfileController>(
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

## Nested Routes (ShellRoute)

For nested navigation with a shared shell (e.g. bottom nav bar), use `ShellRoute`
with a root `ZenRoute` at the shell level:

```dart
GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => ZenRoute(
        moduleBuilder: () => AppShellModule(),
        page: AppShell(child: child),
        scopeName: 'AppShell',
      ),
      routes: [
        GoRoute(
          path: '/feed',
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
    ),
  ],
)
```

The `FeedModule` and `SettingsModule` scopes automatically inherit from the
`AppShell` scope, so they can access anything registered in `AppShellModule`.

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
