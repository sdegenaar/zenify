# State Management Patterns

**Production-ready patterns for building scalable Flutter applications with Zenify**

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Understanding Scopes: Where State Lives](#understanding-scopes-where-state-lives)
3. [Fundamentals](#fundamentals)
4. [Core Patterns](#core-patterns)
5. [UI Integration](#ui-integration)
6. [Advanced Patterns](#advanced-patterns)
7. [Performance Optimization](#performance-optimization)
8. [Testing](#testing)
9. [Examples](#complete-examples)
10. [Anti-Patterns](#anti-patterns-to-avoid)

---

## Architecture Overview

### The Three Layers

```
┌─────────────────────────────────────────┐
│  VIEW LAYER (UI)                        │
│  - ZenObserver() for reactive (.obs())  │
│  - ZenUpdater for manual (update())     │
└─────────────────────────────────────────┘
              ↓ uses
┌─────────────────────────────────────────┐
│  CONTROLLER LAYER (State & Logic)       │
│  - Reactive: .obs() values              │
│  - Manual: regular vars + update()      │
└─────────────────────────────────────────┘
              ↑ managed by
┌─────────────────────────────────────────┐
│  REGISTRATION LAYER                     │
│  PRIMARY: Modules → ZenRoute → Scopes   │
│  SIMPLE: ZenProvider.create<T>(...)     │
└─────────────────────────────────────────┘
```

### Key Principles

1. **Controllers** hold state and logic
2. **Views** display state using `ZenView` (Preferred), `ZenObserver()`, or `ZenUpdater`
3. **Registration** via modules (standard) or `ZenProvider.create<T>` (simple routes)

### The "Goldilocks Zone" Philosophy
* **Versus Riverpod**: Riverpod is an incredibly powerful, deeply flexible tool that relies on code generation (`build_runner`) and global scope binding. Zenify offers an alternative for teams looking for standard object-oriented controllers without requiring a code generation step.
* **Versus BLoC**: BLoC provides excellent structural cleanliness via its strictly typed event-to-state mapping. Zenify provides a similar separation of logic via `ZenController`, but leverages a more direct reactive mutation approach commonly found in React Query. 
* **Zenify's Advantage**: We sit exactly in the middle. We provide the robust class-based separation of BLoC, the asynchronous loading mastery of Riverpod, and the lightweight syntax of GetX. With strictly localized component scopes via `ZenView` and **>95% test coverage**, it is enterprise-ready and highly productive.

---

## Understanding Scopes: Where State Lives

Zenify uses **hierarchical scopes** to organize dependencies with automatic lifecycle management. Understanding where state lives helps you decide between Controllers and Services.

### The Three Scope Levels

```
┌──────────────────────────────────────────────────┐
│  ROOTSCOPE (Global - App Lifetime)               │
│  Services: auth, api, cart, theme                │
│  Lives: Entire app session                       │
│  Access: Zen.find() anywhere                     │
└──────────────────────────────────────────────────┘
              ↓ child scopes
┌──────────────────────────────────────────────────┐
│  MODULE SCOPE (Feature - Feature Lifetime)       │
│  Controllers: shared across feature pages        │
│  Lives: While in feature (company → dept → emp)  │
│  Access: Zen.find() within feature scope         │
│  Cleanup: Auto-dispose when leaving feature      │
└──────────────────────────────────────────────────┘
              ↓ child scopes
┌──────────────────────────────────────────────────┐
│  PAGE SCOPE (Page - Page Lifetime)               │
│  Controllers: page-specific state                │
│  Lives: While page is visible                    │
│  Access: injected into ZenView.build()           │
│  Cleanup: Auto-dispose when page pops            │
└──────────────────────────────────────────────────┘
```

### Controller vs Service: It's About Scope

The distinction between Controller and Service is **lifecycle intent**, not capability. Both can have reactive state and be accessed via `Zen.find()`.

| What | Where | When It Dies | Example |
|------|-------|--------------|---------|
| **Service** | RootScope | Never (app lifetime) | `CartService`, `AuthService`, `ApiService` |
| **Controller (Module)** | Module Scope | When leaving feature | `CompanyController`, `DepartmentController` |
| **Controller (Page)** | Page Scope | When page pops | `LoginController`, `ProfileController` |

### When to Use Which

**Use Service (RootScope) when:**
- Needed across the entire app (cart, auth, theme)
- Should survive navigation (user session, app config)
- Truly global state

```dart
// Services live in RootScope
class CartService extends ZenService {
  static CartService get to => Zen.find<CartService>();

  final items = <CartItem>[].obs();
  final total = 0.0.obs();

  void addItem(Product product) {
    items.add(CartItem.fromProduct(product));
    _updateTotal();
  }
}

// Register once at app startup
void main() {
  Zen.put(CartService());
  Zen.put(AuthService());
  runApp(MyApp());
}
```

**Use Controller in Module Scope when:**
- Shared across multiple pages in a feature
- Should dispose when leaving the feature
- Feature-specific state

```dart
// HR Feature with multiple pages sharing controllers
class HRModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // All these controllers shared across HR feature pages
    scope.putLazy<CompanyController>(() => CompanyController());
    scope.putLazy<DepartmentController>(() => DepartmentController());
    scope.putLazy<EmployeeController>(() => EmployeeController());
  }
}

// Used with ZenRoute - controllers live during entire HR feature
ZenRoute(
  moduleBuilder: () => HRModule(),
  page: CompanyPage(),
  scopeName: 'HRScope',
)

// Access in any HR feature widget
class EmployeeBreadcrumbController extends ZenController {
  // Lookup once in controller
  late final company = Zen.find<CompanyController>();
  late final department = Zen.find<DepartmentController>();
  late final employee = Zen.find<EmployeeController>();

  late final breadcrumb = computed(() =>
    '${company.name.value} > ${department.name.value} > ${employee.name.value}'
  );
}
```

When you navigate: Company → Department → Division → Employee, all controllers stay alive. When you exit back to main menu, the entire HRScope disposes and all controllers clean up automatically.

**Use Controller in Page Scope when:**
- Only needed on one page
- Should dispose when page pops
- Page-specific UI state

```dart
// Page-specific controller — provide via ZenProvider.create at the route callsite
ZenProvider.create<LoginController>(
  create: () => LoginController(),
  child: const LoginPage(),
)

class LoginPage extends ZenView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, LoginController controller) {
    return ZenObserver(() => LoginForm(
      isLoading: controller.isLoading.value,
      onSubmit: controller.login,
    ));
  }
}
```

### Rule of Thumb

- **Needed everywhere?** → Service (RootScope)
- **Needed across a feature?** → Controller (Module Scope)
- **Needed on one page?** → `ZenRoute` + `ZenModule`, or `ZenProvider.create<T>` for simple cases

If you find yourself putting a "Controller" in RootScope, it's probably a Service. The name signals lifecycle intent to your team.

### Learn More

For technical details on how hierarchical scopes work (parent-child relationships, automatic discovery, navigation patterns), see the [Hierarchical Scopes Guide](hierarchical_scopes_guide.md).

---

## Fundamentals

### 1. Controller Access in ZenView

**When using ZenView, the controller is injected as an explicit parameter:**

```dart
class MyPage extends ZenView<MyController> {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, MyController controller) {
    // ✅ Controller is injected — compiler-enforced, no magic getter
    return Text(controller.someValue);
  }
}
```

**Common mistake — do not use the old V1 getter signature:**
```dart
// ❌ WRONG - V1 signature, no longer valid in V2
Widget build(BuildContext context) {
  return Text(controller.someValue); // 'controller' getter no longer exists
}

// ✅ CORRECT - explicit parameter (V2)
Widget build(BuildContext context, MyController controller) {
  return Text(controller.someValue);
}
```

### 2. Obx vs ZenUpdater

**Two approaches for state management - choose based on your needs:**

| Approach | Update Method | View Widget | Trade-offs |
|----------|---------------|-------------|------------|
| **Reactive** | `.obs()` values auto-update | `ZenObserver()` | Simple code, more listeners |
| **Manual** | `update()` triggers rebuild | `ZenUpdater` | More control, less overhead |
| **Mixed** | Both in same controller | Both | Flexibility, optimize where needed |

#### Option 1: Reactive Pattern

**Best for:** Simple state, rapid development, automatic updates

```dart
// Controller with reactive state
class ReactiveController extends ZenController {
  final count = 0.obs();  // Reactive
  final name = ''.obs();  // Reactive

  void increment() => count.value++;  // Auto-updates Obx widgets
}

// View uses ZenObserver()
class ReactiveView extends StatelessWidget {
  final ReactiveController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ZenObserver(() => Text('Count: ${controller.count.value}')),
        ZenObserver(() => Text('Name: ${controller.name.value}')),
      ],
    );
  }
}
```

**Trade-offs:**
- ✅ Less code, automatic updates
- ⚠️ More listeners (memory overhead)
- ⚠️ Less control over when rebuilds happen

#### Option 2: Manual Pattern

**Best for:** Performance-critical code, complex objects, precise control

```dart
// Controller with manual state
class ManualController extends ZenController {
  int count = 0;  // Non-reactive
  String status = 'idle';  // Non-reactive

  void increment() {
    count++;
    update(['counter']);  // Manually trigger rebuild
  }

  void updateStatus(String newStatus) {
    status = newStatus;
    update(['status']);  // Manually trigger rebuild
  }
}

// View uses ZenUpdater
class ManualView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenUpdater<ManualController>(
      builder: (context, controller) => Column(
        children: [
          ZenUpdater<ManualController>(
            id: 'counter',
            builder: (context, ctrl) => Text('Count: ${ctrl.count}'),
          ),
          ZenUpdater<ManualController>(
            id: 'status',
            builder: (context, ctrl) => Text('Status: ${ctrl.status}'),
          ),
        ],
      ),
    );
  }
}
```

**Trade-offs:**
- ✅ Precise control, targeted rebuilds
- ✅ Less memory overhead
- ⚠️ More boilerplate
- ⚠️ Must remember to call update()

#### Option 3: Mixed Pattern

**Best for:** Large apps, optimize where needed, flexibility

**Mix both approaches in the same controller:**

```dart
// Controller with BOTH types of state
class MixedController extends ZenController {
  // Reactive state
  final isLoading = false.obs();

  // Non-reactive state (complex objects)
  List<Item> items = [];

  Future<void> loadItems() async {
    isLoading.value = true;  // Auto-updates Obx

    items = await fetchItems();
    update(['item-list']);  // Manually update ZenUpdater

    isLoading.value = false;  // Auto-updates Obx
  }
}

// View uses BOTH (only when necessary!)
class MixedView extends ZenView<MixedController> {
  const MixedView({super.key});

  @override
  Widget build(BuildContext context, MixedController controller) {
    return Column(
      children: [
        // Obx for reactive loading state
        ZenObserver(() => controller.isLoading.value
          ? CircularProgressIndicator()
          : Text('Loaded')
        ),

        // ZenUpdater for manual item list
        ZenUpdater<MixedController>(
          id: 'item-list',
          builder: (context, ctrl) => ItemList(ctrl.items),
        ),
      ],
    );
  }
}
```

**Rule:** Don't mix unless you have a good reason!

### 3. Controller Registration

**Two approaches - use modules when possible:**

#### PRIMARY: Module Registration (Recommended) ⭐

```dart
// 1. Define module
class FeatureModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<FeatureController>(FeatureController());
    scope.put<FeatureService>(FeatureService(), isPermanent: true);
  }
}

// 2. Use with ZenRoute
ZenRoute(
  moduleBuilder: () => FeatureModule(),
  page: FeaturePage(),
  scopeName: 'FeatureScope',
)

// 3. Page automatically finds controller from module — no initController needed
class FeaturePage extends ZenView<FeatureController> {
  const FeaturePage({super.key});

  @override
  Widget build(BuildContext context, FeatureController controller) {
    return Text(controller.data);
  }
}
```

**Benefits:**
- ✅ Automatic lifecycle management
- ✅ Automatic disposal
- ✅ Hierarchical dependency injection
- ✅ Testable (swap modules)

#### SECONDARY: Simple routes — `ZenProvider.create<T>`

When a route has a single controller with no dependencies, skip the module:

```dart
// Simple route — no module needed
ZenProvider.create<UserProfileController>(
  create: () => UserProfileController(userId: userId),
  child: const UserProfilePage(),
)

class UserProfilePage extends ZenView<UserProfileController> {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context, UserProfileController controller) {
    return Text(controller.userName);
  }
}
```

**When to use `ZenProvider.create`:**
- ✅ Single controller, no inter-dependencies
- ✅ Quick routes in smaller apps
- ✅ Prototyping

**Prefer `ZenRoute` + `ZenModule` when:**
- The controller depends on other services
- Multiple controllers share the same route scope
- You want to keep registration logic testable and separate

---

## Core Patterns

### 1. Local Page State

**For page-specific state using modules:**

```dart
// Controller
class CounterController extends ZenController {
  final count = 0.obs();

  void increment() => count.value++;
}

// Module
class CounterModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<CounterController>(CounterController());
  }
}

// Route
ZenRoute(
  moduleBuilder: () => CounterModule(),
  page: CounterPage(),
)

// Page
class CounterPage extends ZenView<CounterController> {
  const CounterPage({super.key});
  // No initController — module provides it

  @override
  Widget build(BuildContext context, CounterController controller) {
    return Scaffold(
      body: Column(
        children: [
          ZenObserver(() => Text('Count: ${controller.count.value}')),
          ElevatedButton(
            onPressed: controller.increment,
            child: Text('Increment'),
          ),
        ],
      ),
    );
  }
}
```

### 2. Global App State

**For app-wide state with static accessor:**

```dart
// Controller with static accessor
class AppStateController extends ZenController {
  static AppStateController get to => Zen.find<AppStateController>();

  final currentUser = Rx<User?>(null);
  final theme = ThemeMode.system.obs();

  bool get isLoggedIn => currentUser.value != null;

  Future<void> login(String email, String password) async {
    final user = await authService.login(email, password);
    currentUser.value = user;
  }
}

// Register globally
void main() {
  Zen.init();
  Zen.put<AppStateController>(AppStateController(), isPermanent: true);
  runApp(MyApp());
}

// Access from anywhere
class AnyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ZenObserver(() => Text('User: ${AppStateController.to.currentUser.value?.name ?? "Guest"}')),
        if (AppStateController.to.isLoggedIn)
          ProfileButton(),
      ],
    );
  }
}
```

### 3. Service with Shared State

**Services CAN have reactive state for business logic:**

```dart
// Service with reactive state
class CartService extends ZenService {
  static CartService get to => Zen.find<CartService>();

  final cartItems = <CartItem>[].obs();
  final totalPrice = 0.0.obs();

  Future<void> addToCart(Product product) async {
    cartItems.add(CartItem.fromProduct(product));
    _updateTotals();
  }

  void _updateTotals() {
    totalPrice.value = cartItems.fold(0.0, (sum, item) => sum + item.price);
  }

  @override
  void onClose() {
    // Cleanup happens automatically
    super.onClose();
  }
}

// Register globally
void main() {
  Zen.init();
  Zen.put<CartService>(CartService(), isPermanent: true);
  runApp(MyApp());
}

// Use from anywhere
class ProductCard extends StatelessWidget {
  final Product product;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => CartService.to.addToCart(product),
      child: ZenObserver(() => Text('Add to Cart (${CartService.to.cartItems.length})')),
    );
  }
}
```

**Key distinction:**
- **Services** = Business logic state (cart items, user session, settings)
- **Controllers** = UI-specific state (loading, selection, form values)

---

## UI Integration

### 1. ZenView (Pages)

**Primary pattern for pages:**

```dart
class ProductListPage extends ZenView<ProductListController> {
  const ProductListPage({super.key});
  // No initController — module provides it

  @override
  Widget build(BuildContext context, ProductListController controller) {
    return Scaffold(
      appBar: AppBar(title: Text('Products')),
      body: ZenObserver(() => controller.isLoading.value
        ? CircularProgressIndicator()
        : ProductGrid(controller.products),
      ),
    );
  }
}
```

### 2. ZenConsumer (Optional Controllers)

**For controllers that might not exist:**

```dart
class OptionalFeature extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenConsumer<PremiumController>(
      builder: (premium) {
        if (premium == null) {
          return BasicFeature();
        }

        return ZenObserver(() => premium.hasAccess.value
          ? PremiumContent()
          : UpgradePrompt()
        );
      },
    );
  }
}
```

### 3. ZenUpdater (Accessing Shared Controllers)

**For accessing existing controllers from any widget:**

```dart
class CartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenUpdater<CartService>(
      builder: (context, cart) => ZenObserver(() => Badge(
        label: Text('${cart.cartItems.length}'),
        child: Icon(Icons.shopping_cart),
      )),
    );
  }
}
```

**Or simpler with static accessor:**

```dart
class CartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenObserver(() => Badge(
      label: Text('${CartService.to.cartItems.length}'),
      child: Icon(Icons.shopping_cart),
    ));
  }
}
```

---

## Advanced Patterns

### 1. Hierarchical Scopes

```dart
// App-level module
class AppModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<DatabaseService>(DatabaseService(), isPermanent: true);
    scope.put<AuthService>(AuthService(), isPermanent: true);
  }
}

// Feature-level module (inherits app services)
class FeatureModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    final db = scope.find<DatabaseService>()!;  // From parent scope
    scope.put<FeatureRepository>(FeatureRepository(db));
    scope.put<FeatureController>(FeatureController());
  }
}

// Page accesses both
class FeaturePage extends ZenView<FeatureController> {
  const FeaturePage({super.key});

  @override
  Widget build(BuildContext context, FeatureController controller) {
    return ZenConsumer<AuthService>(  // From app scope
      builder: (auth) => Scaffold(
        appBar: AppBar(
          title: Text('Feature'),
          actions: auth != null && auth.isAuthenticated.value
            ? [LogoutButton()]
            : null,
        ),
        body: ZenObserver(() => FeatureContent(controller.data.value)),
      ),
    );
  }
}
```
f
### 2. Controller Communication

**Controllers communicate through shared services:**

```dart
// Service as communication hub
class CartService extends ZenService {
  static CartService get to => Zen.find<CartService>();

  final cartItems = <CartItem>[].obs();

  void addToCart(Product product) {
    cartItems.add(CartItem.fromProduct(product));
  }

  @override
  void onClose() {
    super.onClose();
  }
}

// Controller A adds to cart
class ProductDetailController extends ZenController {
  Future<void> addToCart(Product product) async {
    await CartService.to.addToCart(product);
  }
}

// Controller B reacts to cart changes
class CheckoutController extends ZenController {
  @override
  void onInit() {
    super.onInit();

    // Watch cart changes
    ever(CartService.to.cartItems, (items) {
      print('Cart updated: ${items.length} items');
    });
  }

  Future<void> checkout() async {
    final items = CartService.to.cartItems.value;
    await processPayment(items);
    CartService.to.cartItems.clear();
  }
}
```

### 3. Computed Values

```dart
class ShoppingController extends ZenController {
  final items = <CartItem>[].obs();
  final discount = 0.0.obs();

  // Computed getters - auto-recalculate
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.price);
  double get total => subtotal * (1 - discount.value);

  // Or use RxComputed for cached computed values
  late final totalComputed = computed(() => subtotal * (1 - discount.value));
}

// In UI
ZenObserver(() => Text('Total: \$${controller.total.toStringAsFixed(2)}'))
```

---

## Performance Optimization

### Selective Rebuilds with ZenUpdater

**Use IDs for targeted rebuilds:**

```dart
class OptimizedController extends ZenController {
  List<Item> items = [];
  String searchQuery = '';

  void updateSearch(String query) {
    searchQuery = query;
    update(['search']);  // Only rebuilds search widgets
  }

  void addItem(Item item) {
    items.add(item);
    update(['items']);  // Only rebuilds item list
  }
}

// UI with targeted rebuilds
class OptimizedView extends ZenView<OptimizedController> {
  const OptimizedView({super.key});

  @override
  Widget build(BuildContext context, OptimizedController controller) {
    return Column(
      children: [
        ZenUpdater<OptimizedController>(
          id: 'search',
          builder: (context, ctrl) => SearchBar(query: ctrl.searchQuery),
        ),
        ZenUpdater<OptimizedController>(
          id: 'items',
          builder: (context, ctrl) => ItemList(items: ctrl.items),
        ),
      ],
    );
  }
}
```

**Recommendation:** Use reactive state (`.obs()` + `ZenObserver()`) for most cases. It's simpler and sufficient for 90% of use cases. Use manual updates only when you need precise control over complex object rebuilds.

---

## Testing

### Testing Reactive Controllers

```dart
test('increments counter', () {
  final controller = CounterController();
  expect(controller.count.value, 0);

  controller.increment();
  expect(controller.count.value, 1);

  controller.dispose();
});
```

### Testing with Static Accessors

```dart
test('adds to cart', () {
  Zen.testMode();
  final mockCart = MockCartService();
  Zen.put<CartService>(mockCart);

  // CartService.to now returns mock
  CartService.to.addToCart(testProduct);

  verify(mockCart.addToCart(testProduct)).called(1);
  Zen.reset();
});
```

### Testing with Modules

```dart
testWidgets('displays products', (tester) async {
  Zen.testMode();

  // Register test module
  final testModule = TestProductModule();
  testModule.register(Zen.currentScope);

  await tester.pumpWidget(
    MaterialApp(home: ProductListPage()),
  );

  await tester.pumpAndSettle();

  expect(find.text('Product 1'), findsOneWidget);
  Zen.reset();
});
```

---

## Complete Examples

### Example 1: Simple Counter (Module Registration)

```dart
// 1. Controller
class CounterController extends ZenController {
  final count = 0.obs();
  void increment() => count.value++;
}

// 2. Module
class CounterModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<CounterController>(CounterController());
  }
}

// 3. Route
ZenRoute(
  moduleBuilder: () => CounterModule(),
  page: CounterPage(),
)

// 4. Page (no initController — module provides it)
class CounterPage extends ZenView<CounterController> {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context, CounterController controller) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            ZenObserver(() => Text('Count: ${controller.count.value}')),
            ElevatedButton(
              onPressed: controller.increment,
              child: Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Example 2: E-Commerce (Mixed Patterns)

```dart
// 1. Global cart service
class CartService extends ZenService {
  static CartService get to => Zen.find<CartService>();

  final cartItems = <CartItem>[].obs();

  void addToCart(Product product) {
    cartItems.add(CartItem.fromProduct(product));
  }

  @override
  void onClose() {
    super.onClose();
  }
}

// 2. Product detail controller (in module)
class ProductDetailController extends ZenController {
  final Product product;

  ProductDetailController(this.product);

  final quantity = 1.obs();

  void addToCart() {
    CartService.to.addToCart(product);
  }
}

// 3. Product module
class ProductModule extends ZenModule {
  final String productId;

  ProductModule(this.productId);

  @override
  void register(ZenScope scope) {
    final product = scope.find<ProductService>()!.getProduct(productId);
    scope.put<ProductDetailController>(ProductDetailController(product));
  }
}

// 4. Page
class ProductDetailPage extends ZenView<ProductDetailController> {
  const ProductDetailPage({super.key});

  @override
  Widget build(BuildContext context, ProductDetailController controller) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.product.name),
        actions: [
          // Access global cart from anywhere
          ZenObserver(() => Badge(
            label: Text('${CartService.to.cartItems.length}'),
            child: Icon(Icons.shopping_cart),
          )),
        ],
      ),
      body: Column(
        children: [
          Image.network(controller.product.imageUrl),
          Text(controller.product.name),
          Text('\$${controller.product.price}'),
          Row(
            children: [
              Text('Quantity:'),
              ZenObserver(() => Text('${controller.quantity.value}')),
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () => controller.quantity.value++,
              ),
            ],
          ),
          ElevatedButton(
            onPressed: controller.addToCart,
            child: Text('Add to Cart'),
          ),
        ],
      ),
    );
  }
}
```

---

## Anti-Patterns to Avoid

### ❌ DON'T: Mix Obx and ZenUpdater Without Reason

```dart
// ❌ BAD - Why use ZenUpdater if everything is reactive?
ZenUpdater<MyController>(
  builder: (context, controller) => Column(
    children: [
      ZenObserver(() => Text(controller.name.value)),
      ZenObserver(() => Text(controller.age.value)),   // Why ZenUpdater?!
    ],
  ),
)

// ✅ GOOD - Just use Obx directly
Column(
  children: [
    ZenObserver(() => Text(controller.name.value)),
    ZenObserver(() => Text(controller.age.value)),
  ],
)
```

### ❌ DON'T: Register a controller twice (both in module AND via `ZenProvider.create`)

```dart
// ❌ BAD - Controller registered in module but also via ZenProvider.create at route
// The ZenProvider.create will create a second instance — unexpected behaviour
ZenProvider.create<MyController>(
  create: () => MyController(), // duplicate!
  child: const MyPage(),
)
// AND the module also calls scope.put<MyController>(...)

// ✅ GOOD - Pick one. Use the module if you have dependencies:
ZenRoute(
  moduleBuilder: () => MyModule(),
  page: const MyPage(),
)
```

### ❌ DON'T: Create Reactive Values Outside Controllers

```dart
// ❌ BAD - Memory leak!
class BadWidget extends StatelessWidget {
  final counter = 0.obs();  // Never disposed!

  @override
  Widget build(BuildContext context) {
    return ZenObserver(() => Text('${counter.value}'));
  }
}

// ✅ GOOD - In controller with proper lifecycle
class CounterController extends ZenController {
  final counter = 0.obs();  // Disposed in onClose()
}
```

---

## Summary

### Key Patterns

1. **Controllers hold state** (reactive or manual)
2. **Views use ZenObserver() or ZenUpdater** (not both unless necessary)
3. **Registration** via modules and `ZenRoute` (standard), or `ZenProvider.create<T>` (simple routes)

### Decision Tree

1. **New feature?** → Create module + use ZenRoute
2. **Per-instance widget?** → Use `ZenProvider.create<T>(create: ...)` at the callsite
3. **Reactive state?** → Use `.obs()` + `ZenObserver()`
4. **Manual control needed?** → Use regular vars + `update()` + `ZenUpdater`
5. **Global service?** → Add static `.to` accessor
6. **Controller communication?** → Use shared services

### Best Practices

- ✅ Use modules for most controllers
- ✅ Use `.obs()` + `ZenObserver()` for most state (simpler)
- ✅ Reserve ZenUpdater for manual control needs
- ✅ Don't mix patterns without clear reason
- ✅ Services can have state (business logic)
- ✅ Use static `.to` for global access

---

**Next:** See [ZenQuery Guide](zen_query_guide.md) for async state management patterns.
