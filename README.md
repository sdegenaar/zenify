# Zenify

[![pub package](https://img.shields.io/pub/v/zenify.svg)](https://pub.dev/packages/zenify)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A modern state management library for Flutter offering an intuitive approach to reactive state management with a clean, concise API.

## What is Zenify?

Zenify is a lightweight yet powerful state management library that brings true "zen" to Flutter development. It combines the best aspects of existing solutions while addressing their limitations, creating a balanced approach that's both intuitive and robust.

## Why Choose Zenify?

Struggling with state management in Flutter? Zenify offers an elegant solution that keeps your codebase clean and your mind at peace:

- **🚀 Less Boilerplate**: Write less code while accomplishing more
- **🏗️ Natural Hierarchy**: Nested scopes that follow your UI structure
- **⚡ Flexible Reactivity**: Choose between automatic UI updates or manual control
- **🔒 Strong Type Safety**: Catch errors at compile-time with enhanced type constraints
- **✨ Elegant Async Handling**: Built-in effects system for loading, error, and success states
- **🧪 Testing Ready**: Comprehensive testing utilities out of the box

### Key Advantages

✅ **Hierarchical Scopes**: Nested controller access with proper dependency inheritance  
✅ **Module System**: Organized dependency registration with clear boundaries  
✅ **Dependency Safety**: Automatic circular dependency detection and resolution  
✅ **Unified Syntax**: Consistent API for state management operations  
✅ **Reduced Boilerplate**: Concise syntax for common state operations  
✅ **Flexibility**: Choose the right approach for different scenarios  
✅ **Performance Monitoring**: Built-in metrics to identify bottlenecks  
✅ **Async Operations**: Built-in effect system for handling loading states  
✅ **Reactive Base**: Core reactive primitives for building reactive systems  
✅ **Zen Effects**: Handle async operations with built-in loading, error, and success states  
✅ **Enhanced Type Safety**: Generic type constraints throughout the library  
✅ **Performance Optimizations**: Intelligent rebuild management and memory efficiency  
✅ **Enhanced Testing Utilities**: Comprehensive support for testing reactive state  
✅ **Improved Reference System**: Type-safe references with eager and lazy initialization  
✅ **Production-Ready Reactive System**: Comprehensive error handling and resilient operations

## 🚀 Quick Start

### Installation

Add Zenify to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  zenify:
    git:
      url: https://github.com/sdegenaar/zenify.git
      ref: v0.3.0
```

### Initialize Zenify

```dart
import 'package:zenify/zenify.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize for development environment
  ZenConfig.applyEnvironment('dev');

  // Register global modules at startup
  await Zen.registerModules([
    AppModule(),
    AuthModule(),
    ApiModule(),
  ]);

  runApp(const MyApp());
}
```

### Your First ZenController

```dart
class CounterController extends ZenController {
  // Reactive state
  final RxInt counter = 0.obs();

  void increment() {
    counter.value++; // Simple increment
  }

  void decrement() {
    counter.value--;
  }

  void reset() {
    counter.value = 0;
  }
}
```

### Using in Pages with ZenView

The recommended approach is to extend `ZenView` for your pages:

```dart
class ProductDetailPage extends ZenView<ProductDetailController> {
  final String productId;

  const ProductDetailPage({
    super.key,
    required this.productId,
  });

  @override
  ProductDetailController Function()? get createController => () {
    return ProductDetailController(
      productService: Zen.find<ProductService>(),
    )..initialize(productId); // Initialize immediately
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ZenEffectBuilder<Product>(
          effect: controller.productDetailEffect,
          onLoading: () => const Text('Loading...'),
          onError: (error) => const Text('Product Details'),
          onSuccess: (product) => Text(product.name),
        ),
      ),
      body: ZenEffectBuilder<Product>(
        effect: controller.productDetailEffect,
        onLoading: () => const Center(child: CircularProgressIndicator()),
        onError: (error) => Center(
          child: Text('Error: $error', style: TextStyle(color: Colors.red)),
        ),
        onSuccess: (product) => ProductDetailView(product: product),
      ),
    );
  }
}
```

### Using with Module Registration

For controllers registered via modules, simply omit the `createController`:

```dart
class CounterPage extends ZenView<CounterController> {
  const CounterPage({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zenify Counter')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Direct access to controller - no Zen.find() needed!
            Obx(() => Text(
              'Count: ${controller.counter.value}',
              style: Theme.of(context).textTheme.headlineMedium,
            )),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: controller.decrement,
                  child: const Icon(Icons.remove),
                ),
                ElevatedButton(
                  onPressed: controller.reset,
                  child: const Text('Reset'),
                ),
                ElevatedButton(
                  onPressed: controller.increment,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### Benefits of ZenView

✅ **Direct Controller Access**: Use `controller.property` instead of `Zen.find<T>()`  
✅ **Automatic Lifecycle**: Controller binding handled automatically  
✅ **Type Safety**: Full compile-time type checking  
✅ **Cleaner Code**: Less boilerplate, more readable  
✅ **Error Handling**: Clear exceptions when controllers aren't available  
✅ **Consistent Pattern**: All pages follow the same structure

## ⚡ Production-Ready Reactive System

**New in v0.3.0** - Zenify includes a comprehensive reactive system designed for production applications with robust error handling and performance optimization.

### RxFuture - Reactive Async Operations

Handle async operations with automatic state management:

```dart
class DataController extends ZenController {
  late final RxFuture<List<User>> usersFuture;

  @override
  void onInit() {
    super.onInit();

    // Create reactive future with factory function
    usersFuture = RxFuture.fromFactory(() => userService.getUsers());

    // Or set future directly
    // usersFuture = RxFuture(userService.getUsers());
  }

  void refreshData() {
    usersFuture.refresh(); // Automatically handles loading states
  }

  void handleError() {
    if (usersFuture.hasError) {
      // Access both wrapped and original errors
      final originalError = usersFuture.originalError;
      final errorMessage = usersFuture.errorMessage;
      showSnackbar('Error: $errorMessage');
    }
  }
}

// In UI - automatic state management
Obx(() {
if (controller.usersFuture.isLoading) {
return const CircularProgressIndicator();
}

if (controller.usersFuture.hasError) {
return ErrorWidget(controller.usersFuture.errorMessage ?? 'Unknown error');
}

if (controller.usersFuture.hasData) {
return UserList(users: controller.usersFuture.data!);
}

return const SizedBox.shrink();
})
```

### RxComputed - Smart Dependency Tracking

Create computed values that automatically update when dependencies change:

```dart
class ShoppingController extends ZenController {
  final RxList<CartItem> cartItems = <CartItem>[].obs();
  final RxDouble taxRate = 0.08.obs();

  // Computed values with automatic dependency tracking
  late final RxComputed<double> subtotal;
  late final RxComputed<double> tax;
  late final RxComputed<double> total;
  late final RxComputed<int> itemCount;

  @override
  void onInit() {
    super.onInit();

    // These automatically update when cartItems or taxRate change
    subtotal = computed(() =>
        cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity))
    );

    tax = computed(() => subtotal.value * taxRate.value);

    total = computed(() => subtotal.value + tax.value);

    itemCount = computed(() =>
        cartItems.fold(0, (sum, item) => sum + item.quantity)
    );
  }

  void addItem(CartItem item) {
    cartItems.add(item); // All computed values automatically update!
  }

  @override
  void onClose() {
    // Computed values automatically dispose their dependencies
    subtotal.dispose();
    tax.dispose();
    total.dispose();
    itemCount.dispose();
    super.onClose();
  }
}

// In UI - automatic updates
Obx(() => Text('Subtotal: \$${controller.subtotal.value.toStringAsFixed(2)}'))
Obx(() => Text('Tax: \$${controller.tax.value.toStringAsFixed(2)}'))
Obx(() => Text('Total: \$${controller.total.value.toStringAsFixed(2)}'))
```

### RxResult - Robust Error Handling

Handle operations that can fail with explicit error handling:

```dart
class UserController extends ZenController {
  final RxList<User> users = <User>[].obs();

  Future<void> saveUser(User user) async {
    // Try* methods return RxResult for explicit error handling
    final result = await RxResult.tryExecuteAsync(() async {
      return await userService.saveUser(user);
    }, 'save user');

    result.onSuccess((savedUser) {
      // Success - update the list
      final index = users.indexWhere((u) => u.id == savedUser.id);
      if (index != -1) {
        users[index] = savedUser;
      } else {
        users.add(savedUser);
      }
      showSuccessMessage('User saved successfully');
    });

    result.onFailure((error) {
      // Failure - show error message
      showErrorMessage('Failed to save user: ${error.message}');
    });
  }

  void updateUserSafely(int index, User newUser) {
    // Safe list operations with error handling
    final result = users.trySetAt(index, newUser);

    if (result.isFailure) {
      showErrorMessage('Invalid index: $index');
    }
  }

  User? getUserSafely(int index) {
    // Safe access with fallback
    return users.tryElementAt(index).valueOrNull;
  }
}
```

### Advanced Reactive Patterns

```dart
class AdvancedController extends ZenController {
  final RxString searchQuery = ''.obs();
  final RxList<Product> products = <Product>[].obs();
  final RxBool isLoading = false.obs();

  @override
  void onInit() {
    super.onInit();

    // Debounced search with error handling
    searchQuery.debounce(const Duration(milliseconds: 500), (query) async {
      if (query.isEmpty) {
        products.clear();
        return;
      }

      isLoading.value = true;

      final result = await RxResult.tryExecuteAsync(() async {
        return await productService.search(query);
      }, 'search products');

      result.onSuccess((results) {
        products.assignAll(results);
      });

      result.onFailure((error) {
        products.clear();
        showError('Search failed: ${error.message}');
      });

      isLoading.value = false;
    });

    // Performance tracking
    products.addListener(() {
      products.trackChange(); // Track for performance monitoring
    });
  }

  void clearSearch() {
    searchQuery.value = '';
    products.clear();
  }
}
```

### Error Configuration for Production

Configure error handling behavior for different environments:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure reactive error handling for production
  setRxErrorConfig(RxErrorConfig(
    logErrors: kDebugMode, // Only log in debug mode
    throwOnCriticalErrors: false, // Graceful degradation in production
    maxRetries: 3,
    retryDelay: const Duration(milliseconds: 500),
    customLogger: (error) {
      // Use your logging service
      FirebaseCrashlytics.instance.recordError(
        error.originalError,
        error.stackTrace,
        reason: error.message,
      );
    },
  ));

  runApp(const MyApp());
}
```

### Key Benefits of the Reactive System

✅ **Production-Ready**: Comprehensive error handling and resilient operations  
✅ **Type Safety**: Full generic support with compile-time guarantees  
✅ **Memory Efficient**: Automatic cleanup and leak prevention  
✅ **Performance Optimized**: Smart dependency tracking and minimal rebuilds  
✅ **Error Resilient**: Graceful degradation with fallback values  
✅ **Async Ready**: Built-in support for futures and async operations  
✅ **Testing Friendly**: Extensive testing utilities and mocking support  
✅ **Resource Management**: Automatic disposal and subscription cleanup

## 🔧 Widget System

Zenify provides different widgets for different use cases, each optimized for specific scenarios:

### ZenConsumer - Efficient Dependency Access

Use `ZenConsumer` to efficiently access any dependency with automatic caching:

```dart
// Access services efficiently
ZenConsumer<CartService>(
  builder: (cartService) => cartService != null
      ? CartIcon(itemCount: cartService.itemCount)
      : const EmptyCartIcon(),
)

// Access optional dependencies gracefully
ZenConsumer<AuthService>(
  tag: 'premium',
  builder: (authService) => authService?.isAuthenticated.value == true
      ? const PremiumFeatures()
      : const UpgradePrompt(),
)

// Use in complex widgets
class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(product.name),
          Text('\$${product.price}'),
          ZenConsumer<CartService>(
            builder: (cartService) => ElevatedButton(
              onPressed: cartService != null
                  ? () => cartService.addItem(product)
                  : null,
              child: const Text('Add to Cart'),
            ),
          ),
        ],
      ),
    );
  }
}
```


### ZenBuilder - Manual Updates with Performance Control

Use `ZenBuilder` for fine-grained manual update control with ZenControllers:

```dart
class PerformanceOptimizedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Only rebuilds when controller.update(['header']) is called
        ZenBuilder<DashboardController>(
          id: 'header',
          builder: (context, controller) => AppBar(
            title: Text(controller.title),
            actions: [
              IconButton(
                icon: Icon(controller.settingsIcon),
                onPressed: controller.openSettings,
              ),
            ],
          ),
        ),

        // Only rebuilds when controller.update(['content']) is called
        ZenBuilder<DashboardController>(
          id: 'content',
          builder: (context, controller) => Expanded(
            child: ListView.builder(
              itemCount: controller.items.length,
              itemBuilder: (context, index) =>
                  ItemWidget(item: controller.items[index]),
            ),
          ),
        ),

        // Only rebuilds when controller.update(['footer']) is called
        ZenBuilder<DashboardController>(
          id: 'footer',
          builder: (context, controller) => BottomNavigationBar(
            currentIndex: controller.selectedIndex,
            onTap: controller.onTabTapped,
            items: controller.navigationItems,
          ),
        ),
      ],
    );
  }
}

class DashboardController extends ZenController {
  // ... properties ...

  void updateTitle(String newTitle) {
    _title = newTitle;
    update(['header']); // Only header rebuilds
  }

  void addItem(Item item) {
    _items.add(item);
    update(['content']); // Only content rebuilds
  }

  void changeTab(int index) {
    _selectedIndex = index;
    update(['footer']); // Only footer rebuilds
  }

  void refreshAll() {
    // Refresh all data
    update(); // All ZenBuilders rebuild
  }
}
```

### Obx - Reactive Updates

Use `Obx` for automatic rebuilds when reactive values change:

```dart
class ReactiveWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Zen.find<CounterController>();
    
    return Column(
      children: [
        // Automatically rebuilds when counter.value changes
        Obx(() => Text('Count: ${controller.counter.value}')),
        
        // Automatically rebuilds when isLoading.value changes
        Obx(() => controller.isLoading.value
          ? const CircularProgressIndicator()
          : const Text('Ready')
        ),
        
        // Multiple reactive values
        Obx(() => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: controller.isActive.value ? Colors.green : Colors.red,
          child: Text('Status: ${controller.status.value}'),
        )),
      ],
    );
  }
}
```

### Widget Comparison

| Widget | Purpose | Rebuild Trigger | Use Case |
|--------|---------|----------------|----------|
| **ZenConsumer** | Dependency access | No automatic rebuilds | Accessing any service efficiently |
| **ZenBuilder** | Manual updates | `controller.update()` | Fine-grained performance control |
| **Obx** | Reactive updates | Reactive value changes | Simple reactive widgets |
| **ZenView** | Page base class | N/A (base class) | Full pages with controllers |

### Accessing Controllers in Nested Widgets

For nested widgets that need controller access, you have several options:

```dart
// Option 1: Use ZenConsumer (recommended for flexibility)
class MyNestedWidget extends StatelessWidget {
  const MyNestedWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ZenConsumer<CounterController>(
      builder: (controller) => controller != null
        ? Obx(() => Text('Count: ${controller.counter.value}'))
        : const Text('Controller not available'),
    );
  }
}

// Option 2: Use context extension (within a ZenView)
class MyNestedWidget extends StatelessWidget {
  const MyNestedWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.controller<CounterController>();
    return Obx(() => Text('Count: ${controller.counter.value}'));
  }
}

// Option 3: Pass controller down from parent
class MyNestedWidget extends StatelessWidget {
  final CounterController controller;
  
  const MyNestedWidget({Key? key, required this.controller}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Obx(() => Text('Count: ${controller.counter.value}'));
  }
}

// Option 4: Manual lookup (less preferred)
class MyNestedWidget extends StatelessWidget {
  const MyNestedWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Zen.find<CounterController>();
    return Obx(() => Text('Count: ${controller.counter.value}'));
  }
}
```

## 🎯 ZenView Patterns

### Simple Page with Local Controller

```dart
class SettingsPage extends ZenView<SettingsController> {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  SettingsController Function()? get createController => () => SettingsController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          Obx(() => SwitchListTile(
            title: const Text('Dark Mode'),
            value: controller.isDarkMode.value,
            onChanged: controller.toggleDarkMode,
          )),
          Obx(() => SwitchListTile(
            title: const Text('Notifications'),
            value: controller.notificationsEnabled.value,
            onChanged: controller.toggleNotifications,
          )),
        ],
      ),
    );
  }
}
```

### Page with Module-Registered Controller

```dart
class HomePage extends ZenView<HomeController> {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          Obx(() => IconButton(
            icon: Icon(controller.isGridView.value ? Icons.list : Icons.grid_view),
            onPressed: controller.toggleViewMode,
          )),
        ],
      ),
      body: Obx(() => controller.isLoading.value
        ? const Center(child: CircularProgressIndicator())
        : controller.isGridView.value
          ? _buildGridView()
          : _buildListView()
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
      ),
      itemCount: controller.items.length,
      itemBuilder: (context, index) => ItemCard(item: controller.items[index]),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: controller.items.length,
      itemBuilder: (context, index) => ItemTile(item: controller.items[index]),
    );
  }
}
```

### Page with Tagged Controller

```dart
class ChatPage extends ZenView<ChatController> {
  final String chatId;
  
  const ChatPage({Key? key, required this.chatId}) : super(key: key);

  @override
  String? get tag => 'chat_$chatId';

  @override
  ChatController Function()? get createController => () => ChatController(chatId: chatId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.chatTitle.value)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: controller.showChatInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() => ListView.builder(
              reverse: true,
              itemCount: controller.messages.length,
              itemBuilder: (context, index) => MessageBubble(
                message: controller.messages[index],
              ),
            )),
          ),
          MessageInput(
            onSend: controller.sendMessage,
            isLoading: controller.isSending,
          ),
        ],
      ),
    );
  }
}
```

## 🏗️ Dependency Management

### Global Module Registration

Register core modules at application startup for global availability:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Zenify
  ZenConfig.applyEnvironment('dev');
  
  // Register global modules
  await Zen.registerModules([
    CoreModule(),      // Database, API, Authentication
    ThemeModule(),     // Theme and styling services
    LocalizationModule(), // Internationalization
  ]);
  
  runApp(const MyApp());
}

class CoreModule extends ZenModule {
  @override
  String get name => 'CoreModule';

  @override
  void register(ZenScope scope) {
    // Register core services globally
    scope.putLazy<ApiService>(() => ApiService());
    scope.putLazy<DatabaseService>(() => DatabaseService());
    scope.putLazy<AuthService>(() => AuthService());
    scope.putLazy<CacheService>(() => CacheService());
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    // Initialize services
    await scope.find<DatabaseService>()?.initialize();
    await scope.find<AuthService>()?.initialize();
  }
}
```

### Hierarchical Scopes

Zenify automatically manages hierarchical scopes, allowing child components to access parent dependencies seamlessly:

```dart
// Module registers shared services at the page level
class ProductModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.putLazy(() => ProductService());
    scope.putLazy(() => CartService());
  }
}

// Page creates scope with module
class ProductPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenModulePage(
      moduleBuilder: () => ProductModule(),
      page: ProductDetailView(),
      scopeName: 'ProductScope',
    );
  }
}

// Child widgets automatically access parent services
class ProductDetailView extends ZenView<ProductDetailController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ProductInfo(),
          ProductReviews(), // Can access ProductService from parent scope
          // Use ZenConsumer for optional services
          ZenConsumer<CartService>(
            builder: (cartService) => cartService != null
              ? AddToCartButton(service: cartService)
              : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// Controllers automatically inject dependencies from scope hierarchy
class ProductDetailController extends ZenController {
  // Automatically injected from parent scope
  final ProductService productService = Zen.find<ProductService>();
  
  final product = Rxn<Product>();
  
  void addToCart() {
    // Use ZenConsumer in UI for optional services
    // or check if available before using
    final cartService = Zen.findOrNull<CartService>();
    if (cartService != null) {
      cartService.addItem(product.value!);
    }
  }
}
```

**Key Benefits:**
- 🔄 **Automatic Cleanup**: Scopes dispose when pages are popped
- 🎯 **Smart Resolution**: Dependencies resolve from nearest scope
- 🏗️ **Module Organization**: Group related dependencies together
- 🚀 **Zero Boilerplate**: No manual scope management needed

### Module System

Organize your controllers with the module system:

```dart
// Define a module for related controllers
class AuthModule extends ZenModule {
  @override
  String get name => 'AuthModule';

  @override
  void register(ZenScope scope) {
    // Register services
    scope.putLazy<AuthService>(() => AuthService());
    
    // Register controllers
    scope.putLazy<AuthController>(() => AuthController());
    scope.putLazy<UserProfileController>(() => UserProfileController());
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    // Initialize module-specific logic
    final authService = scope.find<AuthService>();
    await authService?.initialize();
  }
}
```

### Type-Safe References

Use the enhanced reference system for type-safe dependency access:

```dart
class UserService extends ZenController {
  // Eager reference - for dependencies that should always be available
  final authService = EagerRef<AuthService>();
  
  // Lazy reference - for dependencies that should be created on demand
  final analytics = LazyRef<AnalyticsService>();
  
  // Controller reference - specifically for ZenControllers
  final profileController = ControllerRef<ProfileController>();
  
  void initialize() {
    // Access dependencies safely
    if (analytics.exists()) {
      analytics.find()?.logEvent('UserService initialized');
    }
    
    // Register dependencies
    authService.put(AuthService());
    analytics.lazyPut(() => AnalyticsService());
  }
}
```

## 🛣️ Routing Integration with ZenModulePage

Zenify provides seamless integration with Flutter's routing system through `ZenModulePage`, enabling automatic module lifecycle management tied to your navigation.

### ZenModulePage Widget

The `ZenModulePage` widget automatically manages module registration and disposal based on route navigation. Use it directly in your route builders:

```dart
class AppRoutes {
  static const String home = '/';
  static const String productDetail = '/product';
  static const String cart = '/cart';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => ZenModulePage(
            moduleBuilder: () => HomeModule(),
            page: const HomePage(),
            scopeName: 'HomeScope',
          ),
        );

      case productDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        final productId = args?['productId'] as String? ?? '';

        return MaterialPageRoute(
          builder: (_) => ZenModulePage(
            moduleBuilder: () => ProductDetailModule(),
            page: ProductDetailPage(productId: productId),
            scopeName: 'ProductDetailScope',
          ),
        );

      case cart:
        return MaterialPageRoute(
          builder: (_) => ZenModulePage(
            moduleBuilder: () => CartModule(),
            page: const CartPage(),
            scopeName: 'CartScope',
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const NotFoundPage(),
        );
    }
  }
}
```

### Advanced Module Dependencies

Handle complex module hierarchies with shared dependencies:

```dart
// Feature-specific module that depends on core services
class ProductModule extends ZenModule {
  @override
  String get name => 'ProductModule';

  @override
  void register(ZenScope scope) {
    // Access shared services from parent scope
    final apiService = Zen.find<ApiService>();
    final cacheService = Zen.find<CacheService>();
    
    if (apiService == null || cacheService == null) {
      throw Exception('Required services not found in parent scope');
    }

    // Register product-specific services and controllers
    scope.putLazy<ProductService>(() => ProductService(
      apiService: apiService,
      cacheService: cacheService,
    ));
    
    scope.putLazy<HomeController>(() => HomeController(
      productService: scope.find<ProductService>()!,
    ));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    // Initialize feature-specific logic
    final productService = scope.find<ProductService>();
    await productService?.initialize();
  }
}
```

### Module Lifecycle Hooks

Leverage module lifecycle for complex initialization and cleanup:

```dart
class AnalyticsModule extends ZenModule {
  @override
  String get name => 'AnalyticsModule';

  @override
  void register(ZenScope scope) {
    scope.putLazy<AnalyticsService>(() => AnalyticsService());
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    final analytics = scope.find<AnalyticsService>();
    
    // Initialize analytics when module loads
    await analytics?.initialize();
    analytics?.trackPageView('Module initialized: $name');
    
    ZenLogger.logInfo('AnalyticsModule initialized for scope: ${scope.name}');
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    final analytics = scope.find<AnalyticsService>();
    
    // Cleanup before module disposal
    analytics?.trackPageView('Module disposed: $name');
    await analytics?.flush();
    
    ZenLogger.logInfo('AnalyticsModule disposed for scope: ${scope.name}');
  }
}
```

### Benefits of ZenModulePage

✅ **Automatic Cleanup**: Modules are automatically disposed when leaving routes  
✅ **Dependency Isolation**: Each route can have its own isolated dependencies  
✅ **Memory Efficiency**: Controllers and services are cleaned up when not needed  
✅ **Hierarchical Dependencies**: Child modules can access parent module services  
✅ **Lifecycle Management**: Initialize and cleanup resources at the right time  
✅ **Debug-Friendly**: Clear logging of module registration and disposal

## 🎭 Advanced: ZenScopeWidget for Custom Scoping

For scenarios beyond routing, use `ZenScopeWidget` to create scopes at any widget level:

### Non-Route Scoping

Perfect for modals, dialogs, and dynamic content:

```dart
// Modal with isolated dependencies
void showFilterModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (context) => ZenScopeWidget(
      moduleBuilder: () => FilterModule(),
      scopeName: 'FilterScope',
      child: const FilterBottomSheet(),
    ),
  );
}

// Tab content with separate modules
TabBarView(
  children: [
    ZenScopeWidget(
      moduleBuilder: () => HomeTabModule(),
      child: const HomeTabContent(),
    ),
    ZenScopeWidget(
      moduleBuilder: () => SearchTabModule(), 
      child: const SearchTabContent(),
    ),
  ],
)
```

### Conditional Feature Modules

```dart
// Load different modules based on user permissions
@override
Widget build(BuildContext context) {
  return user.hasAdvancedFeatures
    ? ZenScopeWidget(
        moduleBuilder: () => AdvancedDashboardModule(),
        child: const AdvancedDashboard(),
      )
    : ZenScopeWidget(
        moduleBuilder: () => BasicDashboardModule(),
        child: const BasicDashboard(),
      );
}
```

### Reusable Component Scoping

```dart
// Self-contained widget with its own dependencies
class ChatWidget extends StatelessWidget {
  final String chatId;
  
  const ChatWidget({Key? key, required this.chatId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ZenScopeWidget(
      moduleBuilder: () => ChatModule(chatId: chatId),
      scopeName: 'Chat_$chatId',
      child: const ChatContent(),
    );
  }
}
```

### When to Use ZenScopeWidget vs ZenModulePage

| Use Case | Widget | Reason |
|----------|--------|--------|
| **Full Screen Routes** | `ZenModulePage` | Automatic navigation lifecycle |
| **Modals & Dialogs** | `ZenScopeWidget` | Non-route scoping |
| **Tab Content** | `ZenScopeWidget` | Multiple scopes per page |
| **Conditional Features** | `ZenScopeWidget` | Dynamic module loading |
| **Reusable Components** | `ZenScopeWidget` | Widget-level isolation |

### Context Extensions

Access scopes from nested widgets:

```dart
class MyNestedWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Find the nearest scope
    final scope = context.findScope();
    final controller = scope.find<MyController>();
    
    return Text('Data: ${controller.data}');
  }
}
```

**Benefits:**
- **Granular Control**: Create scopes exactly where needed
- **Automatic Cleanup**: Scopes dispose when widgets are removed
- **Flexible Architecture**: Mix routing and widget-level scoping
- **Reusable Components**: Self-contained widgets with dependencies

## 📊 State Management Approaches

### Reactive State

Zenify provides intuitive reactive state management:

```dart
class TodoController extends ZenController {
  // Reactive state
  final RxList<Todo> todos = <Todo>[].obs();
  final RxString filter = 'all'.obs();
  final RxBool isLoading = false.obs();

  // Computed values
  List<Todo> get filteredTodos {
    switch (filter.value) {
      case 'active':
        return todos.where((todo) => !todo.completed).toList();
      case 'completed':
        return todos.where((todo) => todo.completed).toList();
      default:
        return todos.toList();
    }
  }

  void addTodo(String title) {
    todos.add(Todo(title: title));
  }

  void toggleTodo(int index) {
    todos[index].completed = !todos[index].completed;
    todos.refresh(); // Notify listeners
  }

  void removeTodo(int index) {
    todos.removeAt(index);
  }
}

// In UI - use Obx for automatic rebuilds
Obx(() => ListView.builder(
  itemCount: controller.filteredTodos.length,
  itemBuilder: (context, index) {
    final todo = controller.filteredTodos[index];
    return TodoListItem(
      todo: todo, 
      onToggle: () => controller.toggleTodo(index),
    );
  },
))
```

### Manual Updates

For fine-grained control and maximum performance:

```dart
class PerformanceController extends ZenController {
  int _counter = 0;
  String _status = 'Ready';

  int get counter => _counter;
  String get status => _status;

  void incrementCounter() {
    _counter++;
    update(['counter']); // Update only counter section
  }

  void updateStatus(String newStatus) {
    _status = newStatus;
    update(['status']); // Update only status section
  }

  void updateAll() {
    _counter++;
    _status = 'Updated';
    update(); // Update all ZenBuilder widgets
  }
}

// In UI
ZenBuilder<PerformanceController>(
  id: 'counter',
  builder: (context, controller) => Text('Counter: ${controller.counter}'),
)

ZenBuilder<PerformanceController>(
  id: 'status',
  builder: (context, controller) => Text('Status: ${controller.status}'),
)
```

## 🔥 Advanced Features

### Zen Effects for Async Operations

Handle async operations with built-in loading, error, and success states:

```dart
class UserController extends ZenController {
  late final ZenEffect<User> userEffect;
  late final ZenEffect<void> deleteEffect;

  @override
  void onInit() {
    super.onInit();
    userEffect = createEffect<User>(name: 'userLoad');
    deleteEffect = createEffect<void>(name: 'userDelete');
  }

  Future<void> loadUser(int userId) async {
    await userEffect.run(() async {
      final user = await userRepository.getUser(userId);
      return user;
    });
  }

  Future<void> deleteUser(int userId) async {
    await deleteEffect.run(() async {
      await userRepository.deleteUser(userId);
    });
  }

  @override
  void onClose() {
    userEffect.dispose();
    deleteEffect.dispose();
    super.onClose();
  }
}

// In UI
ZenEffectBuilder<User>(
  effect: controller.userEffect,
  onLoading: () => const CircularProgressIndicator(),
  onError: (error) => Text('Error: $error'),
  onSuccess: (user) => UserDetailCard(user: user),
)
```

### Workers for Reactive Operations

```dart
class SearchController extends ZenController {
  final RxString searchQuery = ''.obs();
  final RxList<SearchResult> results = <SearchResult>[].obs();

  @override
  void onInit() {
    super.onInit();
    
    // Debounce search queries
    ZenWorkers.debounce(
      searchQuery,
      (query) => performSearch(query),
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> performSearch(String query) async {
    if (query.isEmpty) {
      results.clear();
      return;
    }
    
    final searchResults = await searchService.search(query);
    results.assignAll(searchResults);
  }
}
```

### Performance Monitoring

```dart
class AnalyticsController extends ZenController {
  @override
  void onInit() {
    super.onInit();
    
    // Track expensive operations
    ZenMetrics.startTiming('initialization');
    performInitialization();
    ZenMetrics.stopTiming('initialization');
    
    // Start periodic logging in development
    if (ZenConfig.enableDebugLogs) {
      ZenMetrics.startPeriodicLogging(const Duration(minutes: 1));
    }
  }

  Future<void> performExpensiveOperation() async {
    ZenMetrics.startTiming('expensiveOperation');
    
    try {
      await expensiveTask();
    } finally {
      ZenMetrics.stopTiming('expensiveOperation');
    }
  }
}
```

## 🧪 Testing Support

Zenify provides comprehensive testing utilities:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  group('CounterController Tests', () {
    late CounterController controller;

    setUp(() {
      controller = CounterController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('should increment counter', () {
      expect(controller.counter.value, 0);
      
      controller.increment();
      
      expect(controller.counter.value, 1);
    });

    test('should reset counter', () {
      controller.counter.value = 5;
      
      controller.reset();
      
      expect(controller.counter.value, 0);
    });
  });

  group('Reactive System Tests', () {
    test('RxFuture should handle successful operations', () async {
      final future = Future.delayed(Duration(milliseconds: 10), () => 42);
      final rxFuture = RxFuture<int>(future);

      expect(rxFuture.isLoading, true);
      
      await future;
      await Future.delayed(Duration(milliseconds: 20));
      
      expect(rxFuture.hasData, true);
      expect(rxFuture.data, 42);
    });

    test('RxResult should handle errors gracefully', () {
      final result = RxResult.tryExecute(() {
        throw Exception('Test error');
      }, 'test operation');

      expect(result.isFailure, true);
      expect(result.errorOrNull?.message, contains('test operation'));
    });
  });

  group('Widget Tests', () {
    testWidgets('Counter increments test', (tester) async {
      // Setup test environment
      await tester.pumpWidget(TestApp());
      
      // Test interactions
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      
      expect(find.text('Count: 1'), findsOneWidget);
    });
  });
}
```

## 🔄 Migration Guide

### From GetX

Zenify's API is inspired by GetX, making migration straightforward:

| GetX | Zenify | Notes |
|------|--------|-------|
| `Get.put()` | `Zen.put()` | Same functionality |
| `Get.find()` | `Zen.find()` | Same functionality |
| `Get.lazyPut()` | `Zen.putLazy()` | Same lazy initialization |
| `Get.delete()` | `Zen.delete()` | Same functionality |
| `GetX()` | `ZenBuilder()` | Manual update builder |
| `GetBuilder()` | `ZenBuilder()` | Manual update builder |
| `Obx()` | `Obx()` | Identical usage |
| `GetView` | `ZenView` | Base view with controller access |

#### Migration Steps

1. **Update Dependencies**: Replace `get` with `zenify` in `pubspec.yaml`
2. **Update Imports**: Change `import 'package:get/get.dart';` to `import 'package:zenify/zenify.dart';`
3. **Update References**: Change `Get.` to `Zen.` for dependency injection
4. **Update Widgets**: Replace `GetX` with `ZenBuilder` for manual updates
5. **Update Modules**: Convert GetX bindings to `ZenModule`
6. **Update Controllers**: Extend `ZenController` instead of `GetxController`

### From Provider

```dart
// Before (Provider)
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CounterModel()),
        ChangeNotifierProvider(create: (_) => UserModel()),
      ],
      child: const MaterialApp(home: MyHomePage()),
    );
  }
}

// After (Zenify)
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MyHomePage());
  }
}

// Register dependencies in main()
void main() async {
  await Zen.registerModules([
    AppModule(), // Contains CounterController and UserController
  ]);
  runApp(const MyApp());
}
```

## 📱 Best Practices

### Widget Selection

1. **ZenConsumer**: Use for accessing any dependency efficiently
2. **ZenBuilder**: Use for manual update control with ZenControllers
3. **Obx**: Use for reactive state with automatic rebuilds
4. **ZenView**: Use as base class for pages with controllers

### Module Organization

1. **Core Modules**: Register shared services in global modules
2. **Feature Modules**: Create specific modules for each major feature/route
3. **Dependency Checking**: Always verify required dependencies exist in parent scopes
4. **Lifecycle Hooks**: Use `onInit` and `onDispose` for resource management
5. **Error Handling**: Provide clear error messages when dependencies are missing

### Performance Optimization

1. **Use Effects**: Leverage `ZenEffect` for async operations with built-in state management
2. **Selective Updates**: Use `ZenBuilder` with specific IDs for fine-grained updates
3. **Lazy Loading**: Use `putLazy()` for dependencies that aren't immediately needed
4. **Memory Management**: Dispose controllers and effects properly in `onClose`
5. **Module Cleanup**: Use `ZenModulePage` for automatic resource cleanup on navigation

### Performance Tips

1. **Use computed values** for derived state instead of manual calculations
2. **Leverage try* methods** for operations that might fail
3. **Configure error handling** appropriately for your environment
4. **Use ZenBuilder** for fine-grained performance control
5. **Dispose resources** properly to prevent memory leaks

### Error Handling Guidelines

1. **Use RxResult** for operations that can fail
2. **Configure global error handling** for production
3. **Provide fallback values** for resilient UIs
4. **Log errors** appropriately for debugging

### Testing Strategy

1. **Unit Tests**: Test controllers in isolation using dependency injection
2. **Widget Tests**: Use `ZenTestScope` for component testing
3. **Integration Tests**: Test module interactions and lifecycle
4. **Mock Dependencies**: Replace services with mocks for testing

### Code Organization

1. **Group related functionality** in modules
2. **Use hierarchical scopes** for dependency management
3. **Keep controllers focused** on single responsibilities
4. **Test reactive logic** thoroughly

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

```shell script
git clone https://github.com/sdegenaar/zenify.git
cd zenify
flutter pub get
flutter test
```


### Contribution Guidelines

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

Zenify draws inspiration from several excellent state management libraries:

- **GetX** by Jonny Borges - For the intuitive reactive syntax and dependency injection approach
- **Provider** by Remi Rousselet - For context-based dependency inheritance concepts
- **Riverpod** by Remi Rousselet - For improved type safety and testability patterns

## 📞 Support

- 📖 [Documentation](https://github.com/sdegenaar/zenify/wiki)
- 🐛 [Issue Tracker](https://github.com/sdegenaar/zenify/issues)
- 💬 [Discussions](https://github.com/sdegenaar/zenify/discussions)

---