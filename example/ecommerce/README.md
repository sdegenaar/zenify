# Zenify E-Commerce Example

This example demonstrates a **production-ready** application built with Zenify, showcasing best practices for architecture, state management, and dependency injection patterns.

## Key Features

- **Module-Based Architecture**: Feature modules (Auth, Product, Cart) with clean separation of concerns
- **Static `.to` Accessor Pattern**: Global services accessible from anywhere
- **Hybrid DI Approach**: Mix of constructor injection and `.to` pattern for optimal developer experience
- **Reactive State Management**: Zero-boilerplate reactivity with `.obs()` and `Obx()`
- **Automatic Cleanup**: Proper scope management and memory leak prevention
- **Controller Communication**: Multiple patterns for controllers to communicate
- **State in Services**: Demonstrates services with business logic state

## Architecture Patterns Demonstrated

This app showcases **three dependency access patterns**:

1. **Static `.to` Accessor** (Global services)
2. **Constructor Injection** (Testable dependencies)
3. **Hybrid Approach** (Best of both worlds) ⭐

See [ARCHITECTURE_PATTERNS.md](ARCHITECTURE_PATTERNS.md) for detailed explanation.

## Project Structure

```
lib/
├── ecommerce/
│   ├── controllers/       # Feature-specific controllers
│   ├── modules/           # Feature modules for DI
│   ├── pages/             # UI pages
│   ├── routes/            # Routing configuration
│   └── widgets/           # Reusable UI components
└── shared/
    ├── models/            # Data models
    └── services/          # Business logic and data services
```

## Key Concepts Demonstrated

### 1. Static `.to` Accessor Pattern ⭐

Global services use the `.to` pattern for clean, context-free access:

```dart
// Services with static accessor
class CartService {
  static CartService get to => Zen.find<CartService>();

  final cartItems = <CartItem>[].obs();
  final totalPrice = 0.0.obs();

  Future<void> addToCart(Product product) async { ... }
}

class AuthService {
  static AuthService get to => Zen.find<AuthService>();

  final currentUser = Rx<User?>(null);
  final isAuthenticated = false.obs();
}

// Access from anywhere - no injection, no builders!
class QuickAddButton extends StatelessWidget {
  Widget build(context) => ElevatedButton(
    onPressed: () => CartService.to.addToCart(product),
    child: Text('Add to Cart'),
  );
}

// Works in controllers too
class CheckoutController extends ZenController {
  Future<void> checkout() async {
    if (!AuthService.to.isAuthenticated.value) return;

    final items = CartService.to.cartItems.value;
    await process(items);
  }
}
```

See [quick_cart_button.dart](lib/ecommerce/widgets/quick_cart_button.dart) for complete example.

### 2. State in Services

Services **can and should** have reactive state for business logic:

```dart
class CartService {
  // ✅ Services can have reactive state!
  final cartItems = <CartItem>[].obs();
  final totalPrice = 0.0.obs();
  final itemCount = 0.obs();

  Future<void> addToCart(Product product) async {
    cartItems.add(CartItem.fromProduct(product));
    _updateCartStats();
  }
}
```

**Key distinction:**
- **Services** = Business logic state (cart items, user session)
- **Controllers** = UI-specific state (loading, selection, form values)

### 3. Module-Based Architecture

Each feature has its own module that registers dependencies:

```dart
class ProductModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // Get global services (registered elsewhere)
    final productService = scope.find<ProductService>()!;

    // Register controllers with injection
    scope.putLazy<ProductDetailController>(
      () => ProductDetailController(productService: productService),
    );
  }
}
```

### 4. Controller Communication

Controllers communicate through shared services:

```dart
// ProductDetailController adds to cart
class ProductDetailController extends ZenController {
  Future<void> addToCart(Product product) async {
    // Access global service via .to
    await CartService.to.addToCart(product);
  }
}

// CartBadge widget shows cart count from anywhere
class CartBadge extends StatelessWidget {
  Widget build(context) => ZenConsumer<CartService>(
    builder: (cart) => Obx(() =>
      Badge(label: Text('${cart!.itemCount.value}'))
    ),
  );
}

// Or use .to directly!
class CartBadgeSimple extends StatelessWidget {
  Widget build(context) => Obx(() =>
    Badge(label: Text('${CartService.to.itemCount.value}'))
  );
}
```

### 5. Hybrid DI Approach (Recommended) ⭐

Mix injection for testable dependencies with `.to` for global services:

```dart
class ProductDetailController extends ZenController {
  // Inject testable/complex dependencies
  final ProductService productService;

  ProductDetailController({required this.productService});

  Future<void> addToCart(Product product) async {
    // Use injected service for business logic
    await productService.validateProduct(product);

    // Use .to for global services
    await CartService.to.addToCart(product);

    if (AuthService.to.isAuthenticated.value) {
      await productService.syncToCloud();
    }
  }
}
```

### 6. Reactive State Management

Controllers and services use reactive state that automatically updates UI:

```dart
class CartController extends ZenController {
  final CartService cartService;

  // Delegate to service
  List<CartItem> get cartItems => cartService.cartItems.value;
  double get totalPrice => cartService.totalPrice.value;

  Future<void> checkout() async {
    await processPayment(cartService.cartItems.value);
    await cartService.clearCart();
  }
}

// In UI - automatic rebuilds
Obx(() => Text('Total: \$${controller.totalPrice.toStringAsFixed(2)}'))
```

## Running the Example

1. Navigate to the example directory: `cd examples/ecommerce`
2. Get dependencies: `flutter pub get`
3. Run the app: `flutter run`

## Key Files to Explore

**Architecture Patterns:**
- `ARCHITECTURE_PATTERNS.md`: Comprehensive guide to all patterns used
- `lib/ecommerce/widgets/quick_cart_button.dart`: Static `.to` pattern example

**Services (with reactive state):**
- `lib/shared/services/cart_service.dart`: Service with `.to` accessor
- `lib/shared/services/auth_service.dart`: Authentication service with `.to`
- `lib/shared/services/product_service.dart`: Product data service

**Controllers (UI orchestration):**
- `lib/ecommerce/controllers/cart_controller.dart`: Delegates to CartService
- `lib/ecommerce/controllers/product_detail_controller.dart`: Hybrid DI approach
- `lib/ecommerce/controllers/home_controller.dart`: Uses injected services

**Modules (dependency registration):**
- `lib/ecommerce/modules/app_module.dart`: Global services
- `lib/ecommerce/modules/cart_module.dart`: Cart feature module
- `lib/ecommerce/modules/product_module.dart`: Product feature module

**Pages (ZenView usage):**
- `lib/ecommerce/pages/cart_page.dart`: ZenView with controller
- `lib/ecommerce/pages/product_detail_page.dart`: createController override
- `lib/ecommerce/pages/home_page.dart`: Module-provided controller

## Testing Examples

### Testing with `.to` Pattern

```dart
test('adds product to cart via .to', () {
  Zen.testMode();

  final mockCart = MockCartService();
  Zen.put<CartService>(mockCart);

  // CartService.to now returns mock
  CartService.to.addToCart(testProduct);

  verify(mockCart.addToCart(testProduct)).called(1);
  Zen.reset();
});
```

### Testing with Injection

```dart
test('loads product details', () async {
  final mockService = MockProductService();
  when(mockService.getProductById('123'))
    .thenAnswer((_) async => testProduct);

  final controller = ProductDetailController(
    productService: mockService,
  );

  await controller.loadProduct('123');

  verify(mockService.getProductById('123')).called(1);
});
```

## Architecture Decision Guide

**When should I use which pattern?**

| Scenario | Pattern | Example |
|----------|---------|---------|
| Global service accessed everywhere | Static `.to` | CartService, AuthService |
| Service you want to mock in tests | Constructor injection | ProductService, ApiService |
| Page-specific controller | ZenView createController | ProductDetailController |
| Shared controller in module | Module registration | HomeController |
| Optional feature | ZenConsumer | PremiumController |

## Learning Resources

1. Start with `ARCHITECTURE_PATTERNS.md` - explains all patterns
2. Read service files to see `.to` pattern usage
3. Check controller files for hybrid DI approach
4. Explore widget files for reactive UI patterns
5. Review module files for dependency organization