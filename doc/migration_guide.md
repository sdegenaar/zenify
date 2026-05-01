# GetX to Zenify Migration Guide

Zenify is intentionally familiar to GetX developers. The reactive system (`.obs()`, `Obx()`), controller lifecycle (`onInit`, `onClose`), and DI verbs (`put`, `find`, `delete`) are all close enough that most migration is mechanical.

This guide covers every major GetX concept and its Zenify equivalent.

> **Why migrate from GetX?** 
> GetX is an incredibly productive and beloved library. Zenify preserves the same highly-ergonomic syntax (`.obs`) that developers love, while introducing `BuildContext`-safe hierarchical scopes. This ensures your components integrate cleanly into Flutter's native `Element` lifecycle, enabling high testability (backed by **>95% line test coverage**) and rock-solid architecture for growing enterprise teams, all while feeling immediately familiar.

---

## Migration Script

A script handles the mechanical parts automatically:

```bash
# Preview changes (dry run — no files modified)
dart tool/migrate_from_getx.dart /path/to/your/project --dry-run

# Apply changes
dart tool/migrate_from_getx.dart /path/to/your/project
```

> **Before running:** commit or stash your current changes so you can easily review the diff or revert if needed.
>
> The script uses text replacement, not AST parsing. It handles the common patterns reliably but cannot account for every codebase. Always run with `--dry-run` first, review the output, and verify with `dart analyze` after applying. It is provided as a convenience with no guarantees.

**What it converts automatically:**
- Import statements
- `GetxController` / `GetxService` → `ZenController` / `ZenService`
- `.obs` → `.obs()` (adds parentheses throughout)
- `Get.put` / `Get.find` / `Get.delete` / `Get.lazyPut` → Zen equivalents
- `Get.isRegistered` → `Zen.has`
- `GetBuilder` / `GetView` / `GetX<T>` → Zen widget equivalents
- `permanent:` → `isPermanent:` (parameter rename)

**What it flags for manual review:**
- Navigation (`Get.to`, `Get.back`, `Get.off`, `Get.offAll`)
- `GetMaterialApp` → `MaterialApp`
- `Bindings` → `ZenModule`
- Worker functions (`ever(`, `once(`, `debounce(`, `interval(`) → `ZenWorkers.*`
- `Get.context` → pass `BuildContext` explicitly
- `GetStorage` → `ZenStorage`
- `Get.snackbar` / `Get.dialog` / `Get.bottomSheet`
- GetX i18n (`.tr`)

After running the script: `dart analyze` will surface any remaining issues.

---

## Concept Map

| GetX | Zenify | Notes |
|------|--------|-------|
| `GetxController` | `ZenController` | Same lifecycle hooks |
| `GetxService` | `ZenService` | Same, but scoped by default |
| `.obs` | `.obs()` | Add parentheses |
| `Obx()` | `Obx()` or `ZenObserver()` | Both work |
| `GetBuilder` | `ZenBuilder` | Same API |
| `GetView<T>` | `ZenView<T>` | Same pattern |
| `Get.put()` | `Zen.put()` | Same |
| `Get.find()` | `Zen.find()` or `Zen.get()` | Both throw when missing — `findOrNull()` is the nullable form |
| `Get.delete()` | `Zen.delete()` or `Zen.remove()` | Same |
| `Get.lazyPut()` | `Zen.putLazy()` | Same concept |
| `Bindings` | `ZenModule` | Scoped, not global |
| `GetMaterialApp` | `MaterialApp` | No wrapper needed |
| `Get.to()` / `Get.back()` | Flutter Navigator or GoRouter | No built-in navigation |
| `ever`, `once`, `debounce`, `interval` | `ZenWorkers` | Direct equivalents |
| `GetStorage` | `ZenStorage` / `InMemoryStorage` | Interface-based |
| `GetConnect` / Async state | `ZenQuery` / `ZenMutation` | Much more capable |

---

## Step-by-Step Migration

### 1. Update pubspec.yaml

```yaml
# Remove
dependencies:
  get: ^4.6.5

# Add
dependencies:
  zenify: ^1.10.0
```

### 2. Update imports

```dart
// Before
import 'package:get/get.dart';

// After
import 'package:zenify/zenify.dart';
```

### 3. Initialize

```dart
// Before
void main() {
  runApp(GetMaterialApp(home: HomePage()));
}

// After
void main() async {
  await Zen.init();
  runApp(MaterialApp(home: HomePage()));
}
```

---

## Controllers

The lifecycle is identical. The only differences are the base class name and `.obs()` parentheses.

```dart
// Before
class CounterController extends GetxController {
  final count = 0.obs;           // no parentheses
  final name = ''.obs;
  final items = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    // setup
  }

  @override
  void onClose() {
    // cleanup
    super.onClose();
  }
}

// After
class CounterController extends ZenController {
  final count = 0.obs();         // parentheses required
  final name = ''.obs();
  final items = <String>[].obs();

  @override
  void onInit() {
    super.onInit();
    // setup — identical
  }

  @override
  void onClose() {
    // cleanup — identical
    super.onClose();
  }
}
```

---

## Dependency Injection

```dart
// Before
Get.put(MyController());
Get.put(MyService(), permanent: true);
Get.lazyPut(() => MyController());
Get.lazyPut(() => MyController(), fenix: true);  // recreate after delete

final ctrl = Get.find<MyController>();
Get.delete<MyController>();

// After
Zen.put(MyController());
Zen.put(MyService(), isPermanent: true);  // note: isPermanent
Zen.putLazy(() => MyController());
Zen.putLazy(() => MyController(), alwaysNew: true);  // equivalent to fenix

// Get.find<T>() throws when missing — Zen.find<T>() behaves identically.
// Use findOrNull<T>() when the dependency might not be registered:
final ctrl = Zen.find<MyController>();          // throws if missing (like Get.find)
final ctrlOrNull = Zen.findOrNull<MyController>(); // returns null if missing
Zen.delete<MyController>();             // or Zen.remove<MyController>()
```

---

## Reactive Widgets

```dart
// Before — all of these
Obx(() => Text('${controller.count}'))

GetX<MyController>(
  builder: (controller) => Text('${controller.count}'),
)

GetBuilder<MyController>(
  builder: (controller) => Text('${controller.count}'),
)

// After
ZenObserver(() => Text('${controller.count.value}'))  // reactive
// or Obx() still works — Zenify keeps it as an alias

ZenBuilder<MyController>(
  builder: (controller) => Text('${controller.count.value}'),
)
// Note: ZenBuilder requires manual controller.update() to rebuild
// Use ZenObserver for automatic reactive rebuilds
```

---

## Page Widgets

```dart
// Before
class ProfilePage extends GetView<ProfileController> {
  @override
  Widget build(BuildContext context) {
    return Text(controller.name.value);
  }
}

// After
class ProfilePage extends ZenView<ProfileController> {
  @override
  Widget build(BuildContext context) {
    return Text(controller.name.value);
  }
}
```

`ZenView` optionally lets you create and own the controller directly on the page:

```dart
class ProfilePage extends ZenView<ProfileController> {
  @override
  ProfileController Function()? get createController => () => ProfileController();

  @override
  Widget build(BuildContext context) {
    return Text(controller.name.value);  // auto-disposed when page pops
  }
}
```

---

## Services

```dart
// Before
class AuthService extends GetxService {
  static AuthService get to => Get.find();

  final isLoggedIn = false.obs;

  Future<AuthService> init() async {
    // setup
    return this;
  }
}

// Register
await Get.putAsync(() async {
  final service = AuthService();
  return await service.init();
});

// After
class AuthService extends ZenService {
  static AuthService get to => Zen.find<AuthService>();

  final isLoggedIn = false.obs();

  @override
  void onInit() {
    super.onInit();
    // setup — called automatically
  }
}

// Register
Zen.put<AuthService>(AuthService(), isPermanent: true);
```

---

## Bindings → Modules

GetX Bindings are global. Zenify Modules are scoped — dependencies are automatically disposed when you leave the feature.

```dart
// Before
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => HomeController());
    Get.lazyPut(() => UserRepository());
  }
}

GetPage(name: '/home', page: () => HomePage(), binding: HomeBinding())

// After — ZenModule requires a name and a register() method
class HomeModule extends ZenModule {
  @override
  String get name => 'HomeModule';  // required — must be unique across your app

  @override
  void register(ZenScope scope) {
    scope.putLazy(() => HomeController());
    scope.putLazy(() => UserRepository());
  }

  // Optional: async setup after dependencies are registered
  @override
  Future<void> onInit(ZenScope scope) async {
    final repo = scope.require<UserRepository>(); // throws if not registered
    await repo.preload();
  }

  // Optional: cleanup when the module's scope disposes
  @override
  Future<void> onDispose(ZenScope scope) async {}
}
```

`ZenRoute` creates a scope, loads the module, and disposes both when the widget leaves the tree:

```dart
// Wrap your page with ZenRoute — works with any router (GoRouter, Navigator, etc.)
ZenRoute(
  moduleBuilder: () => HomeModule(),
  page: HomePage(),
  scopeName: 'HomeScope',  // optional, used for debugging
)

// GoRouter example
GoRoute(
  path: '/home',
  builder: (context, state) => ZenRoute(
    moduleBuilder: () => HomeModule(),
    page: HomePage(),
  ),
)
```

For app-wide services loaded at startup, register modules globally instead:

```dart
void main() async {
  await Zen.init();
  await Zen.registerModules([
    CoreModule(),
    AuthModule(),
  ]);
  runApp(MyApp());
}
```

---

## Workers

Zenify has direct equivalents for all GetX workers:

```dart
// Before
ever(controller.count, (value) => print('changed: $value'));
once(controller.count, (value) => print('first change: $value'));
debounce(controller.count, (value) => search(value), time: Duration(milliseconds: 500));
interval(controller.count, (value) => sync(value), time: Duration(seconds: 1));

// After (inside a ZenController)
@override
void onInit() {
  super.onInit();
  ZenWorkers.ever(count, (value) => print('changed: $value'));
  ZenWorkers.once(count, (value) => print('first change: $value'));
  ZenWorkers.debounce(count, (value) => search(value),
      duration: Duration(milliseconds: 500));
  ZenWorkers.interval(count, (value) => sync(value),
      duration: Duration(seconds: 1));
  // Workers are automatically cancelled when the controller closes
}
```

---

## Navigation

Zenify does not provide navigation helpers. Use Flutter's built-in Navigator or a dedicated router.

```dart
// Before
Get.to(() => DetailPage());
Get.back();
Get.off(() => LoginPage());
Get.offAll(() => HomePage());
Get.toNamed('/detail');

// After — standard Flutter Navigator
Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage()));
Navigator.pop(context);
Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => HomePage()), (_) => false);

// Or use GoRouter (recommended for larger apps)
context.go('/detail');
context.pop();
```

Zenify's `ZenRoute` integrates with any router to provide scoped dependency injection per route — it is not a navigation API.

---

## Snackbars & Dialogs

GetX provides `Get.snackbar()` and `Get.dialog()`. Zenify does not — use Flutter's built-in APIs instead.

```dart
// Before
Get.snackbar('Title', 'Message');
Get.dialog(AlertDialog(...));
Get.bottomSheet(Container(...));

// After
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Message')));
showDialog(context: context, builder: (_) => AlertDialog(...));
showModalBottomSheet(context: context, builder: (_) => Container(...));
```

---

## Storage

```dart
// Before (GetStorage)
final box = GetStorage();
box.write('token', 'abc123');
final token = box.read('token');
box.remove('token');

// After — implement ZenStorage with your preferred backend
// SharedPreferences example (see example/zen_offline/lib/storage.dart):
await Zen.init(storage: SharedPreferencesStorage());

// For tests — built-in, no dependencies
await Zen.init(storage: InMemoryStorage());
```

The `ZenStorage` interface is simple to implement for any backend:

```dart
class MyStorage implements ZenStorage {
  @override
  Future<void> write(String key, Map<String, dynamic> json) async { ... }

  @override
  Future<Map<String, dynamic>?> read(String key) async { ... }

  @override
  Future<void> delete(String key) async { ... }
}
```

---

## Async State

If you're managing async data with `GetxController` + manual `isLoading`/`hasError` flags, `ZenQuery` replaces the whole pattern:

```dart
// Before — typical GetX async pattern
class UserController extends GetxController {
  final isLoading = false.obs;
  final hasError = false.obs;
  final user = Rxn<User>();

  @override
  void onInit() {
    super.onInit();
    fetchUser();
  }

  Future<void> fetchUser() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      user.value = await api.getUser();
    } catch (e) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }
}

// After — ZenQuery handles all of this
class UserController extends ZenController {
  late final userQuery = ZenQuery<User>(
    queryKey: 'user',
    fetcher: (_) => api.getUser(),
  );
}

// In UI — concise form (recommended)
controller.userQuery.when(
  data: (user) => UserCard(user),
  loading: () => CircularProgressIndicator(),
  error: (err, retry) => ErrorView(err, onRetry: retry),
)

// Or the explicit widget form
ZenQueryBuilder<User>(
  query: controller.userQuery,
  builder: (context, user) => UserCard(user),
  loading: () => CircularProgressIndicator(),
  error: (err, retry) => ErrorView(err, onRetry: retry),
)
```

You get caching, deduplication, retries, and background refetch for free.

---

## The `.to` Pattern

This is identical and works exactly the same in Zenify:

```dart
// Both use the same static accessor pattern
class CartService extends ZenService {
  // Zen.find<T>() throws when missing — same as Get.find<T>()
  static CartService get to => Zen.find<CartService>();

  final items = <CartItem>[].obs();
}

// Usage — unchanged from GetX
CartService.to.items.add(item);
```

---

## What GetX Has That Zenify Doesn't

Be aware of these before migrating:

| GetX Feature | Zenify | Alternative |
|---|---|---|
| `Get.to()` / navigation | None | GoRouter, AutoRoute, Navigator |
| `Get.snackbar()` | None | `ScaffoldMessenger` |
| `Get.dialog()` | None | `showDialog()` |
| `GetMaterialApp` theme/locale | None | Standard `MaterialApp` |
| Internationalization (`.tr`) | None | `flutter_localizations` |
| `GetConnect` HTTP client | None | `http`, `dio` |

If your app relies heavily on GetX navigation or i18n, factor that into your migration timeline.

---

## Migration Checklist

- [ ] Replace `get:` with `zenify:` in `pubspec.yaml`
- [ ] Replace `import 'package:get/get.dart'` with `import 'package:zenify/zenify.dart'`
- [ ] Change `GetMaterialApp` to `MaterialApp`, add `await Zen.init()`
- [ ] Rename `GetxController` → `ZenController`, `GetxService` → `ZenService`
- [ ] Add parentheses: `.obs` → `.obs()`
- [ ] Rename `GetBuilder` → `ZenBuilder`, `GetView` → `ZenView`
- [ ] Rename `Get.put/find/delete` → `Zen.put/find/delete`
- [ ] Convert `Bindings` → `ZenModule` with `ZenRoute`
- [ ] Migrate `Get.to/back/off` to Flutter Navigator or GoRouter
- [ ] Migrate `Get.snackbar/dialog` to `ScaffoldMessenger`/`showDialog`
- [ ] Replace GetStorage with a `ZenStorage` implementation
- [ ] Replace manual async state with `ZenQuery`/`ZenMutation`
- [ ] Update workers: `ever/debounce/interval` → `ZenWorkers.*`
- [ ] Run `flutter analyze`
- [ ] Run `flutter test`

---

## Need Help?

- [Documentation](../README.md)
- [GitHub Issues](https://github.com/sdegenaar/zenify/issues)
- [GitHub Discussions](https://github.com/sdegenaar/zenify/discussions)
