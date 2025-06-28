# Zenify E-Commerce Example

This example demonstrates a more complex application built with the Zenify framework, showcasing advanced features like module-based architecture, automatic dependency injection, and proper scope management with ZenModulePage.

## Key Features

- **Module-Based Architecture**: The app is organized into feature modules (Auth, Product, Cart) that encapsulate related functionality.
- **Automatic Dependency Injection**: Services and controllers are automatically injected where needed.
- **Reactive State Management**: Uses Zenify's reactive state management for UI updates.
- **Automatic Cleanup with ZenModulePage**: Demonstrates proper scope management and automatic cleanup when navigating between pages.
- **Comprehensive Routing System**: Shows how to implement a clean routing system with ZenModulePage.

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

### 1. Module-Based Architecture

Each feature has its own module that registers its dependencies:

```dart
class ProductModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // Register controllers for this module
    scope.lazyPut<HomeController>(
      () => HomeController(productService: productService),
    );
    
    scope.lazyPut<ProductDetailController>(
      () => ProductDetailController(productService: productService),
    );
  }
}
```

### 2. Routing with ZenModulePage

The app uses ZenModulePage for routing, which automatically creates and disposes scopes:

```dart
static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case productDetail:
      final args = settings.arguments as Map<String, dynamic>?;
      final productId = args?['productId'] as String? ?? '';
      
      return MaterialPageRoute(
        builder: (_) => ZenModulePage(
          moduleBuilder: () => ProductModule(),
          page: ProductDetailPage(productId: productId),
          scopeName: 'ProductDetailScope',
        ),
      );
  }
}
```

### 3. Automatic Cleanup

ZenModulePage automatically handles cleanup when navigating away from a page:

- Creates a new scope for the page
- Registers the module's dependencies in that scope
- Automatically disposes the scope when the page is popped
- Calls the module's onDispose method for additional cleanup

### 4. Reactive State Management

Controllers use reactive state that automatically updates the UI:

```dart
class CartController extends ZenController {
  final cartItems = <CartItem>[].obs;
  final totalPrice = 0.0.obs;
  
  // When cartItems changes, totalPrice is automatically updated
  void _updateCartStats() {
    double total = 0;
    for (final item in cartItems) {
      total += item.totalPrice;
    }
    totalPrice.value = total;
  }
}
```

## Running the Example

1. Navigate to the example directory: `cd examples/ecommerce`
2. Get dependencies: `flutter pub get`
3. Run the app: `flutter run`

## Key Files to Explore

- `lib/ecommerce/routes/app_routes.dart`: Shows how to use ZenModulePage for routing
- `lib/ecommerce/modules/`: Contains the feature modules
- `lib/ecommerce/controllers/`: Contains the controllers with reactive state
- `lib/ecommerce/pages/`: Contains the UI pages that use ZenView