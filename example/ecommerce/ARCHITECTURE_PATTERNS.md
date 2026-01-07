# E-Commerce App Architecture Patterns

This example app demonstrates various Zenify patterns for building scalable Flutter applications.

## Static `.to` Accessor Pattern

### Services Using `.to` Pattern

All global services in this app use the static `.to` accessor for convenient access:

```dart
// Services with .to accessor
CartService.to.addToCart(product);
AuthService.to.login(email, password);
ProductService.to.getProducts();
```

**Files demonstrating this pattern:**
- `lib/shared/services/cart_service.dart` - Cart management
- `lib/shared/services/auth_service.dart` - Authentication
- `lib/ecommerce/widgets/quick_cart_button.dart` - Example usage

## Dependency Injection vs `.to` Lookup

### Example 1: Pure `.to` Pattern (Simple)

```dart
class ProductDetailController extends ZenController {
  // No injected dependencies!

  Future<void> addToCart(Product product) async {
    // Direct access via .to
    await CartService.to.addToCart(product, quantity: quantity.value);

    if (AuthService.to.isAuthenticated.value) {
      // Save to favorites
    }
  }
}
```

**Benefits:**
- Clean, minimal code
- No dependency wiring
- Works anywhere

### Example 2: Constructor Injection (Testable)

```dart
class ProductDetailController extends ZenController {
  final ProductService productService;

  ProductDetailController({required this.productService});

  Future<void> loadProduct(String id) async {
    final product = await productService.getProductById(id);
    // ...
  }
}
```

**Benefits:**
- Explicit dependencies
- Easy to mock in tests
- Clear API

### Example 3: Hybrid Approach (Recommended) ⭐

```dart
class ProductDetailController extends ZenController {
  // Inject testable/optional dependencies
  final ProductService productService;

  ProductDetailController({required this.productService});

  Future<void> addToCart(Product product) async {
    // Use injected service for business logic
    await productService.validateProduct(product);

    // Use .to for global services
    await CartService.to.addToCart(product, quantity: quantity.value);

    // Mix and match!
    if (AuthService.to.isAuthenticated.value) {
      await productService.addToFavorites(product.id);
    }
  }
}
```

**This gives you:**
- Testability for repositories/APIs (injected)
- Convenience for global services (`.to`)
- Clear separation of concerns

## When to Use Each Pattern

### Use `.to` Pattern For:
- ✅ Global services (auth, cart, theme)
- ✅ Services that are ALWAYS available
- ✅ Accessed from many places
- ✅ Don't need to be mocked often

**Examples in this app:**
```dart
// Cart operations from anywhere
CartService.to.addToCart(product);
CartService.to.itemCount.value;

// Auth checks
if (AuthService.to.isAuthenticated.value) { ... }

// Works in widgets without builders!
class QuickButton extends StatelessWidget {
  Widget build(context) => ElevatedButton(
    onPressed: () => CartService.to.addToCart(product),
    child: Text('Add to Cart'),
  );
}
```

### Use Constructor Injection For:
- ✅ Repositories and data sources
- ✅ Services you want to mock in tests
- ✅ Optional dependencies
- ✅ Services with complex initialization

**Examples:**
```dart
class HomeController extends ZenController {
  final ProductService productService;

  HomeController({required this.productService});

  // Easy to test by injecting mock ProductService
}
```

## Module Registration Patterns

### Minimal Registration with `.to`

```dart
class AppModule extends ZenModule {
  void register(ZenScope scope) {
    // Services don't need factory functions - just instantiate!
    scope.put<CartService>(CartService(), isPermanent: true);
    scope.put<AuthService>(AuthService(), isPermanent: true);
  }
}
```

### Injection-Based Registration

```dart
class ProductModule extends ZenModule {
  void register(ZenScope scope) {
    // Get dependencies from scope
    final productService = scope.find<ProductService>()!;

    // Inject into controller
    scope.putLazy<ProductDetailController>(
      () => ProductDetailController(productService: productService),
    );
  }
}
```

### Hybrid Registration (Best of Both)

```dart
class FeatureModule extends ZenModule {
  void register(ZenScope scope) {
    // Global services with .to (no factory needed)
    final productService = scope.find<ProductService>()!;

    // Controllers use injection for testable deps
    scope.putLazy<FeatureController>(() => FeatureController(
      productService: productService,
      // CartService and AuthService accessed via .to inside controller
    ));
  }
}
```

## Communication Between Controllers

### Pattern 1: Via Shared Service (Recommended)

```dart
// Controller A adds to cart
class ProductController extends ZenController {
  void addProduct(Product p) {
    CartService.to.addToCart(p);
  }
}

// Controller B reacts to cart changes
class CheckoutController extends ZenController {
  @override
  void onInit() {
    super.onInit();

    // Watch cart service
    ever(CartService.to.cartItems, (items) {
      print('Cart updated: ${items.length} items');
    });
  }
}

// Widget C displays cart badge
class CartBadge extends StatelessWidget {
  Widget build(context) => Obx(() =>
    Badge(label: Text('${CartService.to.itemCount.value}'))
  );
}
```

### Pattern 2: Direct Controller Access

```dart
class CheckoutController extends ZenController {
  void processOrder() async {
    // Access other controllers if needed
    final cart = Zen.find<CartService>();
    final auth = Zen.find<AuthService>();

    if (auth.isAuthenticated.value) {
      await checkout(cart.cartItems.value);
    }
  }
}
```

## Best Practices Demonstrated

1. **Global services use `.to` pattern**
   - CartService, AuthService, ProductService
   - Accessible from anywhere
   - Minimal boilerplate

2. **Controllers use injection for business logic**
   - ProductDetailController injects ProductService
   - Easy to test with mocks
   - Clear dependencies

3. **Widgets use `.to` for direct access**
   - No need for ZenConsumer/ZenBuilder for global services
   - Clean, readable code
   - Works in any widget

4. **Modules register both patterns**
   - Services as singletons with `.to`
   - Controllers with injected dependencies
   - Flexible and maintainable

## Testing Examples

### Testing with `.to` Pattern

```dart
test('cart operations', () {
  Zen.testMode();

  // Register mock service
  final mockCart = MockCartService();
  Zen.put<CartService>(mockCart);

  // Use .to pattern in test
  CartService.to.addToCart(product);

  verify(mockCart.addToCart(product)).called(1);
});
```

### Testing with Injection

```dart
test('product loading', () {
  final mockService = MockProductService();
  final controller = ProductDetailController(
    productService: mockService,
  );

  when(mockService.getProductById('1'))
    .thenAnswer((_) async => testProduct);

  await controller.loadProduct('1');

  verify(mockService.getProductById('1')).called(1);
});
```

### Testing Hybrid Approach

```dart
test('add to cart with auth check', () {
  Zen.testMode();

  // Mock global services
  Zen.put<CartService>(MockCartService());
  Zen.put<AuthService>(MockAuthService());

  // Inject testable service
  final mockProduct = MockProductService();
  final controller = ProductDetailController(
    productService: mockProduct,
  );

  // Test uses both patterns
  await controller.addToCart(product);

  // Verify injected service
  verify(mockProduct.validateProduct(product)).called(1);

  // Verify .to service
  verify(CartService.to.addToCart(product)).called(1);
});
```

## Summary

This app demonstrates that **both injection and `.to` patterns work great in Zenify**:

- **`.to` pattern** = Convenience for global services
- **Injection** = Testability for business logic
- **Hybrid** = Best of both worlds ⭐

Choose based on your needs - Zenify supports all approaches!