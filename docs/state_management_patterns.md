# State Management Patterns

## Overview

Zenify provides multiple state management patterns to handle different application needs. This guide covers architectural patterns, best practices, and real-world examples for building scalable Flutter applications with Zenify.

## Table of Contents
- [Quick Start](#quick-start)
- [Core Patterns](#core-patterns)
- [UI Integration Patterns](#ui-integration-patterns)
- [Pattern Selection Guide](#pattern-selection-guide)
- [Reactive State Patterns](#reactive-state-patterns)
- [Controller Patterns](#controller-patterns)
- [Effect-Based State](#effect-based-state)
- [Scope-Based Architecture](#scope-based-architecture)
- [Advanced Patterns](#advanced-patterns)
- [Testing Patterns](#testing-patterns)
- [Performance Patterns](#performance-patterns)
- [Migration Patterns](#migration-patterns)
- [Complete Examples](#complete-examples)
- [Anti-Patterns to Avoid](#anti-patterns-to-avoid)
- [Summary](#summary)

## Quick Start

Choose the right pattern for your use case:

```dart
// Simple reactive state
class CounterController extends ZenController {
  final count = 0.obs();
  void increment() => count.value++;
}

// Async operations with effects
class DataController extends ZenController {
  late final dataEffect = createEffect<List<Item>>(name: 'data');
  
  Future<void> loadData() async {
    await dataEffect.run(() => api.fetchData());
  }
}

// Complex state management
class FeatureController extends ZenController {
  // Reactive state
  final isLoading = false.obs();
  final items = <Item>[].obs();
  final selectedItem = Rx<Item?>(null);
  
  // Computed properties
  List<Item> get filteredItems => items.where((item) => item.isActive).toList();
  bool get hasSelection => selectedItem.value != null;
  
  // Actions
  void selectItem(Item item) {
    selectedItem.value = item;
    update(['selection']); // Targeted UI updates
  }
}
```

## Core Patterns
### 1. **Local State Pattern**
For component-specific state that doesn't need to be shared:
``` dart
class CounterController extends ZenController {
  final count = 0.obs();
  final isEven = true.obs();
  
  void increment() {
    count.value++;
    isEven.value = count.value.isEven;
  }
  
  void reset() {
    count.value = 0;
    isEven.value = true;
  }
}

// ✅ BEST PRACTICE: Use ZenView for pages with controllers
class CounterPage extends ZenView<CounterController> {
  @override
  CounterController createController() => CounterController();

  @override
  Widget build(BuildContext context, CounterController controller) {
    return Scaffold(
      appBar: AppBar(title: Text('Counter')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Obx(() => Text(
            'Count: ${controller.count.value}',
            style: Theme.of(context).textTheme.headlineMedium,
          )),
          Obx(() => Text(
            'Is Even: ${controller.isEven.value}',
            style: Theme.of(context).textTheme.bodyLarge,
          )),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: controller.increment,
            child: Text('Increment'),
          ),
          ElevatedButton(
            onPressed: controller.reset,
            child: Text('Reset'),
          ),
        ],
      ),
    );
  }
}
```
### 2. **Global State Pattern**
For application-wide state shared across multiple features:
``` dart
class AppStateController extends ZenController {
  final currentUser = Rx<User?>(null);
  final theme = ThemeMode.system.obs();
  final notifications = <Notification>[].obs();
  
  bool get isLoggedIn => currentUser.value != null;
  int get unreadCount => notifications.where((n) => !n.isRead).length;
  
  Future<void> login(String email, String password) async {
    final user = await authService.login(email, password);
    currentUser.value = user;
    loadNotifications();
  }
  
  void logout() {
    currentUser.value = null;
    notifications.clear();
  }
}

// Register globally in app module
class AppModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.putLazy<AppStateController>(() => AppStateController(), isPermanent: true);
  }
}

// ✅ BEST PRACTICE: Access global controllers with ZenBuilder
class HeaderWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenBuilder<AppStateController>(
      builder: (context, controller) => AppBar(
        title: Obx(() => Text(
          controller.isLoggedIn 
            ? 'Welcome ${controller.currentUser.value?.name}' 
            : 'Not logged in'
        )),
        actions: [
          Obx(() => Badge(
            label: Text('${controller.unreadCount}'),
            child: Icon(Icons.notifications),
          )),
        ],
      ),
    );
  }
}
```
### 3. **Feature State Pattern**
For feature-specific state with clear boundaries:
``` dart
class ShoppingCartController extends ZenController {
  final items = <CartItem>[].obs();
  final isCheckingOut = false.obs();
  final appliedCoupon = Rx<Coupon?>(null);
  
  // Computed values
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);
  double get discount => appliedCoupon.value?.discount ?? 0.0;
  double get total => subtotal - discount;
  bool get isEmpty => items.isEmpty;
  
  void addItem(Product product, {int quantity = 1}) {
    final existingIndex = items.indexWhere((item) => item.productId == product.id);
    
    if (existingIndex >= 0) {
      items[existingIndex] = items[existingIndex].copyWith(
        quantity: items[existingIndex].quantity + quantity,
      );
    } else {
      items.add(CartItem.fromProduct(product, quantity));
    }
    
    update(['cart-summary']); // Targeted update
  }
  
  Future<void> checkout() async {
    isCheckingOut.value = true;
    try {
      await paymentService.processPayment(total, items.toList());
      items.clear();
      appliedCoupon.value = null;
    } finally {
      isCheckingOut.value = false;
    }
  }
}

// ✅ BEST PRACTICE: Use ZenView for feature pages
class ShoppingCartPage extends ZenView<ShoppingCartController> {
  @override
  ShoppingCartController createController() => ShoppingCartController();

  @override
  Widget build(BuildContext context, ShoppingCartController controller) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping Cart'),
        actions: [
          Obx(() => Text('${controller.items.length} items')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() => controller.isEmpty
              ? Center(child: Text('Your cart is empty'))
              : ListView.builder(
                  itemCount: controller.items.length,
                  itemBuilder: (context, index) {
                    final item = controller.items[index];
                    return CartItemTile(
                      item: item,
                      onRemove: () => controller.removeItem(item.id),
                    );
                  },
                ),
            ),
          ),
          CartSummary(controller: controller),
          Obx(() => ElevatedButton(
            onPressed: controller.isEmpty || controller.isCheckingOut.value
              ? null
              : controller.checkout,
            child: controller.isCheckingOut.value
              ? CircularProgressIndicator()
              : Text('Checkout - \$${controller.total.toStringAsFixed(2)}'),
          )),
        ],
      ),
    );
  }
}
```
## UI Integration Patterns
### 1. **ZenView Pattern** ⭐ (Recommended for Pages)
The simplest and most direct way to access controllers in pages:
``` dart
// ✅ OPTION A: Create controller locally (when not in scope)
class UserProfilePage extends ZenView<UserProfileController> {
  final String userId;
  
  const UserProfilePage({required this.userId});

  @override
  UserProfileController createController() => UserProfileController(userId);

  @override
  Widget build(BuildContext context, UserProfileController controller) {
    return Scaffold(/* ... */);
  }
}

// ✅ OPTION B: Use existing controller from scope (no createController needed!)
class DashboardPage extends ZenView<DashboardController> {
  // No createController override needed!
  // ZenView will automatically find DashboardController from:
  // - ZenRoute modules
  // - Global registration (Zen.put)
  // - Parent scope hierarchy
  
  @override
  Widget build(BuildContext context, DashboardController controller) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: Obx(() => controller.isLoading.value
        ? Center(child: CircularProgressIndicator())
        : DashboardContent(data: controller.data.value),
      ),
    );
  }
}

// Controller registered in module or globally:
class AppModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<DashboardController>(DashboardController());
  }
}

// Or registered globally:
void main() {
  Zen.init();
  Zen.put<DashboardController>(DashboardController()); // Available globally
  runApp(MyApp());
}
```
**ZenView Controller Resolution:**
- **First**: Checks if `createController()` is overridden → uses that
- **Then**: Searches current scope hierarchy for existing controller
- **Finally**: Throws error if controller not found anywhere

**When to override `createController()`:**
- ✅ Controller needs constructor parameters
- ✅ Controller is page-specific and not shared
- ✅ You want to create a new instance every time

**When NOT to override `createController()`:**
- ✅ Controller is registered in ZenRoute module
- ✅ Controller is available in parent scope
- ✅ Controller is registered globally
- ✅ You want to reuse existing controller instance

### 2. **ZenConsumer Pattern**
Lightweight widget for accessing controllers already available in scope:
``` dart
// ✅ EXCELLENT: For simple controller access with null safety
class UserStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenConsumer<UserController>(
      builder: (userController) {
        // Handle both found and not-found cases
        if (userController == null) {
          return Text('Not logged in');
        }
        
        return Obx(() => Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(userController.avatar.value),
            ),
            SizedBox(width: 8),
            Text(userController.displayName.value),
            if (userController.isOnline.value)
              Icon(Icons.circle, color: Colors.green, size: 12),
          ],
        ));
      },
    );
  }
}

// ✅ PERFECT: For optional features that may or may not have controllers
class NotificationBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenConsumer<NotificationController>(
      tag: 'notifications', // Optional tag support
      builder: (controller) {
        // Gracefully handle missing controller
        if (controller == null) {
          return Icon(Icons.notifications); // Basic icon
        }
        
        return Obx(() => Badge(
          label: controller.unreadCount.value > 0 
            ? Text('${controller.unreadCount.value}')
            : null,
          child: Icon(Icons.notifications),
        ));
      },
    );
  }
}

// ✅ GREAT: For widgets that work with or without specific controllers
class ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenConsumer<ThemeController>(
      builder: (themeController) {
        if (themeController == null) {
          // Fallback to basic Flutter theme switching
          return IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: () {
              // Use basic theme switching
            },
          );
        }
        
        // Enhanced theme control with ZenController
        return Obx(() => IconButton(
          icon: Icon(themeController.isDark.value 
            ? Icons.brightness_3 
            : Icons.brightness_7
          ),
          onPressed: themeController.toggleTheme,
        ));
      },
    );
  }
}
```
**ZenConsumer Benefits:**
- **️ Null-safe**: Handles missing controllers gracefully
- **⚡ Efficient**: Cached lookups, no repeated searches
- ** Targeted**: Perfect for optional or conditional features
- ** Lightweight**: Minimal overhead for simple access patterns

### 3. **ZenBuilder Pattern**
For accessing existing controllers with error handling:
``` dart
// ✅ GOOD: For accessing shared/global controllers (with error handling)
class ProductListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenBuilder<ProductController>(
      builder: (context, controller) {
        return RefreshIndicator(
          onRefresh: controller.refreshProducts,
          child: Column(
            children: [
              // Search bar
              TextField(
                onChanged: controller.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  suffixIcon: Obx(() => controller.isSearching.value
                    ? CircularProgressIndicator()
                    : Icon(Icons.search)
                  ),
                ),
              ),
              
              // Product list
              Expanded(
                child: Obx(() => ListView.builder(
                  itemCount: controller.filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = controller.filteredProducts[index];
                    return ProductTile(
                      product: product,
                      onTap: () => controller.selectProduct(product),
                    );
                  },
                )),
              ),
            ],
          ),
        );
      },
    );
  }
}
```
### 4. **ZenControllerScope Pattern**
For local controllers with explicit lifecycle management:
``` dart
// ✅ GOOD: When you need more control over scope and lifecycle
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenControllerScope<SettingsController>(
      create: () => SettingsController(),
      permanent: false, // Will dispose when widget is removed
      child: ZenBuilder<SettingsController>(
        builder: (context, controller) => Scaffold(
          appBar: AppBar(title: Text('Settings')),
          body: Column(
            children: [
              Obx(() => SwitchListTile(
                title: Text('Dark Mode'),
                value: controller.isDarkMode.value,
                onChanged: controller.toggleDarkMode,
              )),
              Obx(() => ListTile(
                title: Text('Language'),
                subtitle: Text(controller.selectedLanguage.value),
                onTap: controller.showLanguageDialog,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
```
### 5. **Obx Pattern**
For simple reactive UI updates (when you already have controller reference):
``` dart
// ✅ GOOD: When controller is already available in scope
class CounterView extends StatelessWidget {
  final CounterController controller;
  
  const CounterView({required this.controller});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Simple reactive text
        Obx(() => Text('Count: ${controller.count.value}')),
        
        // Conditional reactive UI
        Obx(() => controller.isEven.value
          ? Icon(Icons.check, color: Colors.green)
          : Icon(Icons.close, color: Colors.red)
        ),
        
        // Reactive list
        Obx(() => Column(
          children: controller.items.map((item) => 
            ListTile(title: Text(item.name))
          ).toList(),
        )),
      ],
    );
  }
}
```
## Pattern Selection Guide
### **When to use ZenView** ⭐
- **Page-level state management** - most common pattern for new pages
- **Mixed scenarios** - works with both local and existing controllers
- **Simple controller access** without scope lookups
- **Automatic lifecycle** management
``` dart
// Works with existing controller from scope
class ProductsPage extends ZenView<ProductsController> {
  // No createController needed - uses existing from scope
  @override
  Widget build(BuildContext context, ProductsController controller) {
    return Scaffold(/* ... */);
  }
}

// Works with local controller creation
class ProductDetailPage extends ZenView<ProductDetailController> {
  final String productId;
  
  const ProductDetailPage({required this.productId});

  @override
  ProductDetailController createController() => ProductDetailController(productId);

  @override
  Widget build(BuildContext context, ProductDetailController controller) {
    return Scaffold(/* ... */);
  }
}
```
### **When to use ZenConsumer** ️
- **Optional controllers** that may or may not exist
- **Conditional features** based on controller availability
- **Simple access patterns** without complex logic
- **Graceful degradation** when controllers are missing
``` dart
// Perfect for optional features
class PremiumFeature extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenConsumer<PremiumController>(
      builder: (premium) => premium?.hasAccess.value == true
        ? PremiumContent()
        : UpgradePrompt(),
    );
  }
}
```
### **When to use ZenBuilder**
- **Shared controllers** registered in scope (global state)
- **Child widgets** that need access to parent controllers
- **Existing controllers** that are managed elsewhere
- **When you KNOW controller exists** and want error if not found
``` dart
// Access shared cart controller from any widget
class CartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenBuilder<CartController>(
      builder: (context, cart) => Badge(
        label: Text('${cart.itemCount}'),
        child: Icon(Icons.shopping_cart),
      ),
    );
  }
}
```
### **When to use ZenControllerScope**
- **Custom lifecycle management** needs
- **Multiple controllers** in one widget tree
- **Specific scope requirements**
- **Fine-grained control** over creation and disposal
``` dart
// Multiple controllers with custom lifecycle
ZenControllerScope<AuthController>(
  create: () => AuthController(),
  permanent: true, // Don't dispose on widget removal
  child: ZenControllerScope<ThemeController>(
    create: () => ThemeController(),
    child: MyWidget(),
  ),
)
```
## Reactive State Patterns
### 1. **Simple Reactive Values**
Use extension for basic reactive state: `.obs()`
``` dart
class UserController extends ZenController {
  // Primitive reactive values
  final username = ''.obs();
  final age = 0.obs();
  final isOnline = false.obs();
  
  // Object reactive values
  final profile = Rx<UserProfile?>(null);
  
  // Collection reactive values
  final preferences = <String, dynamic>{}.obs();
  final tags = <String>[].obs();
  
  void updateUsername(String newName) {
    username.value = newName;
    // Automatically triggers UI updates
  }
  
  void toggleOnlineStatus() {
    isOnline.toggle(); // RxBool specific method
  }
}
```
### 2. **Computed Reactive Values**
Create derived state that automatically updates:
``` dart
class ShoppingController extends ZenController {
  final items = <CartItem>[].obs();
  final discount = 0.0.obs();
  final taxRate = 0.08.obs();
  
  // Computed values - automatically update when dependencies change
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);
  double get discountAmount => subtotal * discount.value;
  double get taxAmount => (subtotal - discountAmount) * taxRate.value;
  double get total => subtotal - discountAmount + taxAmount;
  
  // Computed reactive list
  List<CartItem> get expensiveItems => 
    items.where((item) => item.price > 100).toList();
  
  // Computed boolean
  bool get hasExpensiveItems => expensiveItems.isNotEmpty;
}
```
### 3. **Complex State Composition**
Combine multiple reactive values for complex state:
``` dart
class FormController extends ZenController {
  // Form fields
  final email = ''.obs();
  final password = ''.obs();
  final confirmPassword = ''.obs();
  final agreeToTerms = false.obs();
  
  // Validation state
  final emailError = Rx<String?>(null);
  final passwordError = Rx<String?>(null);
  final confirmPasswordError = Rx<String?>(null);
  
  // Form state
  final isSubmitting = false.obs();
  final hasSubmitted = false.obs();
  
  @override
  void onInit() {
    super.onInit();
    
    // Auto-validate on changes
    email.listen((value) => validateEmail(value));
    password.listen((value) => validatePassword(value));
    confirmPassword.listen((value) => validateConfirmPassword(value));
  }
  
  // Computed validation state
  bool get isEmailValid => emailError.value == null && email.value.isNotEmpty;
  bool get isPasswordValid => passwordError.value == null && password.value.isNotEmpty;
  bool get isConfirmPasswordValid => confirmPasswordError.value == null;
  bool get isFormValid => isEmailValid && isPasswordValid && isConfirmPasswordValid && agreeToTerms.value;
  
  Future<void> submitForm() async {
    if (!isFormValid) return;
    
    isSubmitting.value = true;
    hasSubmitted.value = true;
    
    try {
      await authService.register(email.value, password.value);
      // Handle success
    } catch (e) {
      // Handle error
    } finally {
      isSubmitting.value = false;
    }
  }
}
```
## Controller Patterns
### 1. **Repository Pattern Controller**
Separate data access from business logic:
``` dart
class UserRepository {
  final ApiService _api;
  final CacheService _cache;
  
  UserRepository(this._api, this._cache);
  
  Future<User> getUser(String id) async {
    // Check cache first
    final cached = await _cache.get<User>('user_$id');
    if (cached != null) return cached;
    
    // Fetch from API
    final user = await _api.getUser(id);
    
    // Cache result
    await _cache.set('user_$id', user);
    
    return user;
  }
}

class UserController extends ZenController {
  final UserRepository _repository;
  
  UserController(this._repository);
  
  final currentUser = Rx<User?>(null);
  final isLoading = false.obs();
  final error = Rx<String?>(null);
  
  Future<void> loadUser(String id) async {
    isLoading.value = true;
    error.value = null;
    
    try {
      final user = await _repository.getUser(id);
      currentUser.value = user;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
```
### 2. **Service Layer Pattern**
Encapsulate business logic in services:
``` dart
class NotificationService {
  final List<NotificationListener> _listeners = [];
  
  void addListener(NotificationListener listener) {
    _listeners.add(listener);
  }
  
  void removeListener(NotificationListener listener) {
    _listeners.remove(listener);
  }
  
  void notify(String message, NotificationType type) {
    for (final listener in _listeners) {
      listener.onNotification(message, type);
    }
  }
}

class MainController extends ZenController {
  final NotificationService _notificationService;
  
  MainController(this._notificationService);
  
  final notifications = <AppNotification>[].obs();
  
  @override
  void onInit() {
    super.onInit();
    
    // Subscribe to notification service
    _notificationService.addListener(this);
  }
  
  @override
  void onClose() {
    _notificationService.removeListener(this);
    super.onClose();
  }
  
  void onNotification(String message, NotificationType type) {
    notifications.add(AppNotification(message, type, DateTime.now()));
    update(['notifications']);
  }
}
```
### 3. **Command Pattern Controller**
Encapsulate actions as commands:
``` dart
abstract class Command {
  Future<void> execute();
  Future<void> undo();
}

class AddItemCommand implements Command {
  final ShoppingCartController controller;
  final Product product;
  final int quantity;
  
  AddItemCommand(this.controller, this.product, this.quantity);
  
  @override
  Future<void> execute() async {
    controller.addItem(product, quantity: quantity);
  }
  
  @override
  Future<void> undo() async {
    controller.removeItem(product.id);
  }
}

class ShoppingCartController extends ZenController {
  final items = <CartItem>[].obs();
  final commandHistory = <Command>[];
  
  Future<void> executeCommand(Command command) async {
    await command.execute();
    commandHistory.add(command);
  }
  
  Future<void> undoLastCommand() async {
    if (commandHistory.isNotEmpty) {
      final lastCommand = commandHistory.removeLast();
      await lastCommand.undo();
    }
  }
}
```
## Effect-Based State
### 1. **Basic Effect Usage**
Handle async operations with automatic state management:
``` dart
class DataController extends ZenController {
  late final userEffect = createEffect<User>(name: 'user');
  late final postsEffect = createEffect<List<Post>>(name: 'posts');
  
  Future<void> loadUser(String userId) async {
    await userEffect.run(() => userService.getUser(userId));
  }
  
  Future<void> loadPosts() async {
    await postsEffect.run(() => postService.getPosts());
  }
  
  @override
  void onInit() {
    super.onInit();
    
    // Watch effect states
    userEffect.watch(
      this,
      onData: (user) {
        if (user != null) {
          print('User loaded: ${user.name}');
        }
      },
      onError: (error) {
        if (error != null) {
          showErrorSnackbar('Failed to load user: $error');
        }
      },
    );
  }
}
```
### 2. **Effect Composition**
Combine multiple effects for complex async flows:
``` dart
class ProfileController extends ZenController {
  late final profileEffect = createEffect<UserProfile>(name: 'profile');
  late final settingsEffect = createEffect<UserSettings>(name: 'settings');
  late final avatarEffect = createEffect<String>(name: 'avatar');
  
  final isAllDataLoaded = false.obs();
  
  Future<void> loadAllData(String userId) async {
    final futures = [
      profileEffect.run(() => userService.getProfile(userId)),
      settingsEffect.run(() => userService.getSettings(userId)),
      avatarEffect.run(() => userService.getAvatarUrl(userId)),
    ];
    
    await Future.wait(futures);
    isAllDataLoaded.value = true;
  }
  
  @override
  void onInit() {
    super.onInit();
    
    // Watch all effects
    ever(profileEffect.data, (_) => checkAllLoaded());
    ever(settingsEffect.data, (_) => checkAllLoaded());
    ever(avatarEffect.data, (_) => checkAllLoaded());
  }
  
  void checkAllLoaded() {
    isAllDataLoaded.value = profileEffect.hasData &&
                            settingsEffect.hasData &&
                            avatarEffect.hasData;
  }
}
```
### 3. **Effect Error Handling**
Comprehensive error handling for effects:
``` dart
class RobustController extends ZenController {
  late final dataEffect = createEffect<ApiResponse>(name: 'data');
  
  final retryCount = 0.obs();
  final maxRetries = 3;
  
  Future<void> loadDataWithRetry() async {
    retryCount.value = 0;
    
    while (retryCount.value <= maxRetries) {
      try {
        await dataEffect.run(() => apiService.getData());
        break; // Success, exit retry loop
      } catch (e) {
        retryCount.value++;
        
        if (retryCount.value > maxRetries) {
          // Final failure
          showErrorDialog('Failed after ${maxRetries} retries: $e');
          break;
        }
        
        // Wait before retry
        await Future.delayed(Duration(seconds: retryCount.value * 2));
      }
    }
  }
  
  @override
  void onInit() {
    super.onInit();
    
    dataEffect.watchError(this, (error) {
      if (error != null) {
        // Log error for analytics
        analytics.logError('data_load_error', error);
        
        // Show user-friendly message
        final message = _getUserFriendlyErrorMessage(error);
        showSnackbar(message);
      }
    });
  }
  
  String _getUserFriendlyErrorMessage(Object error) {
    if (error is NetworkException) {
      return 'Please check your internet connection';
    } else if (error is AuthException) {
      return 'Please log in again';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }
}
```
## Scope-Based Architecture
### 1. **Feature Scope Pattern**
Organize controllers by feature with proper scoping:
``` dart
// Feature module
class UserFeatureModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // Shared services
    scope.put<UserRepository>(UserRepository());
    scope.put<UserService>(UserService());
    
    // Feature controllers
    scope.put<UserListController>(UserListController());
    scope.put<UserDetailController>(UserDetailController());
  }
}

// Route with feature scope
ZenRoute(
  moduleBuilder: () => UserFeatureModule(),
  scopeName: 'UserFeature',
  useParentScope: true,
  autoDispose: true,
  page: UserListPage(),
)

// Page accessing feature-scoped controllers
class UserListPage extends ZenView<UserListController> {
  // No createController needed - uses controller from feature scope
  @override
  Widget build(BuildContext context, UserListController controller) {
    return Scaffold(
      body: Obx(() => ListView.builder(
        itemCount: controller.users.length,
        itemBuilder: (context, index) => UserTile(
          user: controller.users[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserDetailPage(userId: controller.users[index].id),
            ),
          ),
        ),
      )),
    );
  }
}
```
### 2. **Hierarchical Scope Dependencies**
Leverage scope hierarchy for service sharing:
``` dart
// App-level module (persistent)
class AppModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<DatabaseService>(DatabaseService());
    scope.put<AuthService>(AuthService());
    scope.put<ConfigService>(ConfigService());
  }
}

// Feature-level module (inherits app services)
class ShoppingModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // Access app-level services
    final db = scope.find<DatabaseService>()!;
    final auth = scope.find<AuthService>()!;
    
    // Register feature services
    scope.put<ProductRepository>(ProductRepository(db));
    scope.put<CartService>(CartService(auth));
    scope.put<ShoppingController>(ShoppingController());
  }
}

// Page-level access to hierarchical services
class ShoppingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenConsumer<ShoppingController>(
      builder: (shopping) => ZenConsumer<AuthService>(
        builder: (auth) => Scaffold(
          appBar: AppBar(
            title: Text('Shopping'),
            actions: [
              if (auth?.isLoggedIn == true)
                IconButton(
                  icon: Icon(Icons.account_circle),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfilePage()),
                  ),
                ),
            ],
          ),
          body: shopping != null
            ? ShoppingContent(controller: shopping)
            : Center(child: Text('Shopping not available')),
        ),
      ),
    );
  }
}
```
### 3. **Scope-Aware State Management**
Use scopes to isolate and share state appropriately:
``` dart
class ScopeAwareController extends ZenController {
  final String scopeId;
  
  ScopeAwareController(this.scopeId);
  
  final localState = 'local'.obs();
  
  @override
  void onInit() {
    super.onInit();
    
    // Access shared state from parent scope
    final sharedController = Zen.findInScope<SharedStateController>();
    if (sharedController != null) {
      // React to shared state changes
      ever(sharedController.globalCounter, (count) {
        print('Scope $scopeId sees global count: $count');
      });
    }
    
    // Listen for scope disposal
    Zen.currentScope.onDispose(() {
      print('Scope $scopeId is being disposed');
      cleanup();
    });
  }
  
  void cleanup() {
    // Cleanup resources specific to this scope
    localState.value = '';
  }
}
```
## Advanced Patterns
### 1. **State Machine Pattern**
Implement complex state transitions:
``` dart
enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthStateMachine extends ZenController {
  final currentState = AuthState.initial.obs();
  final error = Rx<String?>(null);
  final user = Rx<User?>(null);
  
  // State transition map
  final Map<AuthState, Set<AuthState>> _allowedTransitions = {
    AuthState.initial: {AuthState.loading},
    AuthState.loading: {AuthState.authenticated, AuthState.unauthenticated, AuthState.error},
    AuthState.authenticated: {AuthState.loading, AuthState.unauthenticated},
    AuthState.unauthenticated: {AuthState.loading},
    AuthState.error: {AuthState.loading, AuthState.initial},
  };
  
  void _transitionTo(AuthState newState) {
    final allowedStates = _allowedTransitions[currentState.value] ?? {};
    if (allowedStates.contains(newState)) {
      currentState.value = newState;
    } else {
      throw StateError('Invalid transition from ${currentState.value} to $newState');
    }
  }
  
  Future<void> login(String email, String password) async {
    _transitionTo(AuthState.loading);
    error.value = null;
    
    try {
      final authenticatedUser = await authService.login(email, password);
      user.value = authenticatedUser;
      _transitionTo(AuthState.authenticated);
    } catch (e) {
      error.value = e.toString();
      _transitionTo(AuthState.error);
    }
  }
  
  void logout() {
    if (currentState.value == AuthState.authenticated) {
      user.value = null;
      _transitionTo(AuthState.unauthenticated);
    }
  }
}
```
### 2. **Event-Driven Pattern**
Implement event-driven architecture:
``` dart
abstract class AppEvent {}

class UserLoggedIn extends AppEvent {
  final User user;
  UserLoggedIn(this.user);
}

class ProductAddedToCart extends AppEvent {
  final Product product;
  ProductAddedToCart(this.product);
}

class EventBus {
  final _eventController = StreamController<AppEvent>.broadcast();
  
  Stream<T> on<T extends AppEvent>() => 
    _eventController.stream.where((event) => event is T).cast<T>();
  
  void emit(AppEvent event) => _eventController.add(event);
  
  void dispose() => _eventController.close();
}

class EventDrivenController extends ZenController {
  final EventBus _eventBus;
  
  EventDrivenController(this._eventBus);
  
  final cartItemCount = 0.obs();
  final welcomeMessage = ''.obs();
  
  @override
  void onInit() {
    super.onInit();
    
    // Listen to events
    _eventBus.on<UserLoggedIn>().listen((event) {
      welcomeMessage.value = 'Welcome, ${event.user.name}!';
    });
    
    _eventBus.on<ProductAddedToCart>().listen((event) {
      cartItemCount.value++;
    });
  }
  
  void addToCart(Product product) {
    // Emit event
    _eventBus.emit(ProductAddedToCart(product));
  }
}
```
### 3. **Middleware Pattern**
Add cross-cutting concerns with middleware:
``` dart
abstract class Middleware {
  Future<void> before(String action, Map<String, dynamic> context);
  Future<void> after(String action, Map<String, dynamic> context);
}

class LoggingMiddleware implements Middleware {
  @override
  Future<void> before(String action, Map<String, dynamic> context) async {
    print('Starting action: $action with context: $context');
  }
  
  @override
  Future<void> after(String action, Map<String, dynamic> context) async {
    print('Completed action: $action');
  }
}

class AnalyticsMiddleware implements Middleware {
  @override
  Future<void> before(String action, Map<String, dynamic> context) async {
    analytics.trackEvent('action_started', {'action': action});
  }
  
  @override
  Future<void> after(String action, Map<String, dynamic> context) async {
    analytics.trackEvent('action_completed', {'action': action});
  }
}

class MiddlewareController extends ZenController {
  final List<Middleware> _middlewares;
  
  MiddlewareController(this._middlewares);
  
  Future<T> executeWithMiddleware<T>(
    String action,
    Future<T> Function() operation, {
    Map<String, dynamic> context = const {},
  }) async {
    // Run before middleware
    for (final middleware in _middlewares) {
      await middleware.before(action, context);
    }
    
    try {
      final result = await operation();
      
      // Run after middleware
      for (final middleware in _middlewares.reversed) {
        await middleware.after(action, context);
      }
      
      return result;
    } catch (e) {
      // Run after middleware even on error
      for (final middleware in _middlewares.reversed) {
        await middleware.after(action, {...context, 'error': e});
      }
      rethrow;
    }
  }
}
```
## Testing Patterns
### 1. **Controller Unit Testing**
Test controllers in isolation:
``` dart
// test/controllers/user_controller_test.dart
void main() {
  group('UserController', () {
    late UserController controller;
    late MockUserService mockUserService;
    
    setUp(() {
      Zen.init();
      mockUserService = MockUserService();
      controller = UserController(mockUserService);
    });
    
    tearDown(() {
      controller.dispose();
      Zen.deleteAll(force: true);
    });
    
    test('should load user successfully', () async {
      // Arrange
      final user = User(id: '1', name: 'John Doe');
      when(mockUserService.getUser('1')).thenAnswer((_) async => user);
      
      // Act
      await controller.loadUser('1');
      
      // Assert
      expect(controller.currentUser.value, equals(user));
      expect(controller.isLoading.value, isFalse);
      expect(controller.error.value, isNull);
    });
    
    test('should handle loading error', () async {
      // Arrange
      when(mockUserService.getUser('1')).thenThrow(Exception('Network error'));
      
      // Act
      await controller.loadUser('1');
      
      // Assert
      expect(controller.currentUser.value, isNull);
      expect(controller.isLoading.value, isFalse);
      expect(controller.error.value, contains('Network error'));
    });
  });
}
```
### 2. **Widget Testing with Controllers**
Test UI integration with controllers:
``` dart
// test/widgets/user_page_test.dart
void main() {
  group('UserPage Widget Tests', () {
    late MockUserService mockUserService;
    
    setUp(() {
      Zen.init();
      mockUserService = MockUserService();
      
      // Register mock service
      Zen.put<UserService>(mockUserService);
    });
    
    tearDown(() {
      Zen.deleteAll(force: true);
    });
    
    testWidgets('should display user information', (tester) async {
      // Arrange
      final user = User(id: '1', name: 'John Doe', email: 'john@example.com');
      when(mockUserService.getUser('1')).thenAnswer((_) async => user);
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: UserPage(userId: '1'),
        ),
      );
      
      // Wait for async operation
      await tester.pumpAndSettle();
      
      // Assert
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('john@example.com'), findsOneWidget);
    });
    
    testWidgets('should show loading indicator', (tester) async {
      // Arrange
      when(mockUserService.getUser('1')).thenAnswer(
        (_) async => Future.delayed(Duration(seconds: 1), () => User(id: '1', name: 'John')),
      );
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: UserPage(userId: '1'),
        ),
      );
      
      // Assert - should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Wait for completion
      await tester.pumpAndSettle();
      
      // Assert - should show content
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('John'), findsOneWidget);
    });
  });
}
```
### 3. **Effect Testing**
Test async effects:
``` dart
// test/effects/data_effect_test.dart
void main() {
  group('DataController Effects', () {
    late DataController controller;
    late MockDataService mockDataService;
    
    setUp(() {
      Zen.init();
      mockDataService = MockDataService();
      controller = DataController(mockDataService);
    });
    
    tearDown(() {
      controller.dispose();
      Zen.deleteAll(force: true);
    });
    
    test('should handle effect states correctly', () async {
      // Arrange
      final testData = ['item1', 'item2'];
      when(mockDataService.getData()).thenAnswer((_) async => testData);
      
      // Track state changes
      final states = <String>[];
      
      controller.dataEffect.watchLoading(controller, (loading) {
        states.add('loading: $loading');
      });
      
      controller.dataEffect.watchData(controller, (data) {
        states.add('data: $data');
      });
      
      // Act
      await controller.loadData();
      
      // Assert
      expect(states, [
        'loading: true',
        'loading: false',
        'data: [item1, item2]',
      ]);
      expect(controller.dataEffect.data.value, equals(testData));
    });
  });
}
```
## Performance Patterns
### 1. **Selective Rebuilding**
Use targeted updates to minimize rebuilds:
``` dart
class OptimizedController extends ZenController {
  final items = <Item>[].obs();
  final selectedIndex = 0.obs();
  final searchQuery = ''.obs();
  
  // Use specific update IDs for targeted rebuilds
  void selectItem(int index) {
    selectedIndex.value = index;
    update(['selected-item']); // Only rebuild widgets listening to this ID
  }
  
  void updateSearchQuery(String query) {
    searchQuery.value = query;
    update(['search-results']); // Only rebuild search results
  }
  
  void addItem(Item item) {
    items.add(item);
    update(['item-list']); // Only rebuild item list
  }
}

// UI with targeted rebuilds
class OptimizedItemList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.find<OptimizedController>();
    
    return Column(
      children: [
        // Only rebuilds when search query changes
        GetBuilder<OptimizedController>(
          id: 'search-results',
          builder: (_) => SearchBar(query: controller.searchQuery.value),
        ),
        
        // Only rebuilds when item list changes
        GetBuilder<OptimizedController>(
          id: 'item-list',
          builder: (_) => Expanded(
            child: ListView.builder(
              itemCount: controller.items.length,
              itemBuilder: (context, index) => ItemTile(
                item: controller.items[index],
                isSelected: controller.selectedIndex.value == index,
                onTap: () => controller.selectItem(index),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```
### 2. **Lazy Loading Pattern**
Implement efficient data loading:
``` dart
class LazyLoadController extends ZenController {
  final items = <Item>[].obs();
  final isLoading = false.obs();
  final hasMore = true.obs();
  
  int _currentPage = 0;
  final int _pageSize = 20;
  
  Future<void> loadMore() async {
    if (isLoading.value || !hasMore.value) return;
    
    isLoading.value = true;
    
    try {
      final newItems = await itemService.getItems(
        page: _currentPage,
        pageSize: _pageSize,
      );
      
      if (newItems.length < _pageSize) {
        hasMore.value = false;
      }
      
      items.addAll(newItems);
      _currentPage++;
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> refresh() async {
    _currentPage = 0;
    hasMore.value = true;
    items.clear();
    await loadMore();
  }
}

// UI with lazy loading
class LazyLoadedList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.find<LazyLoadController>();
    
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: Obx(() => ListView.builder(
        itemCount: controller.items.length + (controller.hasMore.value ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == controller.items.length) {
            // Load more trigger
            if (controller.hasMore.value && !controller.isLoading.value) {
              controller.loadMore();
            }
            return controller.isLoading.value
              ? Center(child: CircularProgressIndicator())
              : SizedBox.shrink();
          }
          
          return ItemTile(item: controller.items[index]);
        },
      )),
    );
  }
}
```
### 3. **Memory Management**
Implement proper cleanup and memory management:
``` dart
class MemoryEfficientController extends ZenController {
  final _subscriptions = <StreamSubscription>[];
  final _timers = <Timer>[];
  final _workers = <Worker>[];
  
  final data = <String>[].obs();
  late final StreamSubscription _dataSubscription;
  
  @override
  void onInit() {
    super.onInit();
    
    // Track subscriptions for cleanup
    _dataSubscription = dataStream.listen((newData) {
      data.assignAll(newData);
    });
    _subscriptions.add(_dataSubscription);
    
    // Track workers for cleanup
    final worker = ever(data, (List<String> items) {
      if (items.length > 1000) {
        // Trim data if it gets too large
        data.removeRange(0, items.length - 500);
      }
    });
    _workers.add(worker);
    
    // Track timers for cleanup
    final timer = Timer.periodic(Duration(minutes: 5), (_) {
      cleanupOldData();
    });
    _timers.add(timer);
  }
  
  @override
  void onClose() {
    // Cleanup all resources
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    
    for (final timer in _timers) {
      timer.cancel();
    }
    
    for (final worker in _workers) {
      worker.dispose();
    }
    
    super.onClose();
  }
  
  void cleanupOldData() {
    // Remove data older than 1 hour
    final cutoff = DateTime.now().subtract(Duration(hours: 1));
    data.removeWhere((item) => item.timestamp.isBefore(cutoff));
  }
}
```
## Migration Patterns
### 1. **From Provider to Zenify**
Migrate existing Provider-based code:
``` dart
// OLD: Provider pattern
class OldCounterNotifier extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  
  void increment() {
    _count++;
    notifyListeners();
  }
}

// NEW: Zenify pattern
class NewCounterController extends ZenController {
  final count = 0.obs();
  
  void increment() => count.value++;
}

// OLD: Provider usage
class OldCounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OldCounterNotifier(),
      child: Consumer<OldCounterNotifier>(
        builder: (context, counter, child) {
          return Text('Count: ${counter.count}');
        },
      ),
    );
  }
}

// NEW: Zenify usage
class NewCounterPage extends ZenView<NewCounterController> {
  @override
  NewCounterController createController() => NewCounterController();
  
  @override
  Widget build(BuildContext context, NewCounterController controller) {
    return Obx(() => Text('Count: ${controller.count.value}'));
  }
}
```
### 2. **From Bloc to Zenify**
Migrate BLoC pattern to Zenify:
``` dart
// OLD: BLoC pattern
abstract class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}

class CounterState {
  final int count;
  CounterState(this.count);
}

class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(CounterState(0)) {
    on<Increment>((event, emit) => emit(CounterState(state.count + 1)));
    on<Decrement>((event, emit) => emit(CounterState(state.count - 1)));
  }
}

// NEW: Zenify equivalent
class CounterController extends ZenController {
  final count = 0.obs();
  
  void increment() => count.value++;
  void decrement() => count.value--;
}

// OLD: BLoC usage
class OldBlocPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterBloc(),
      child: BlocBuilder<CounterBloc, CounterState>(
        builder: (context, state) {
          return Column(
            children: [
              Text('Count: ${state.count}'),
              ElevatedButton(
                onPressed: () => context.read<CounterBloc>().add(Increment()),
                child: Text('Increment'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// NEW: Zenify usage
class NewZenifyPage extends ZenView<CounterController> {
  @override
  CounterController createController() => CounterController();
  
  @override
  Widget build(BuildContext context, CounterController controller) {
    return Column(
      children: [
        Obx(() => Text('Count: ${controller.count.value}')),
        ElevatedButton(
          onPressed: controller.increment,
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```
### 3. **Incremental Migration Strategy**
Migrate large applications incrementally:
``` dart
// Step 1: Create adapter layer
class LegacyAdapter {
  static void migrateProvider<T extends ChangeNotifier>(
    T provider,
    ZenController controller,
  ) {
    // Listen to provider changes and update controller
    provider.addListener(() {
      controller.update();
    });
  }
}

// Step 2: Hybrid page during migration
class HybridPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LegacyProvider()),
      ],
      child: ZenView<NewController>(
        createController: () => NewController(),
        child: (controller) => Column(
          children: [
            // Legacy widget
            Consumer<LegacyProvider>(
              builder: (context, legacy, child) => LegacyWidget(legacy),
            ),
            
            // New Zenify widget
            Obx(() => NewWidget(controller.data.value)),
          ],
        ),
      ),
    );
  }
}

// Step 3: Complete migration
class FullyMigratedPage extends ZenView<CompleteController> {
  @override
  CompleteController createController() => CompleteController();
  
  @override
  Widget build(BuildContext context, CompleteController controller) {
    return Column(
      children: [
        Obx(() => ModernWidget(controller.legacyData.value)),
        Obx(() => ModernWidget(controller.newData.value)),
      ],
    );
  }
}
```
## Complete Examples
### **ZenRoute Module Registration**
``` dart
// 1. Register controller in route module
class UserModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<UserController>(UserController());
  }
}

// 2. Use ZenRoute with module
ZenRoute(
  moduleBuilder: () => UserModule(),
  page: UserPage(), // Can use ZenView without createController!
)

// 3. Page automatically finds controller from module
class UserPage extends ZenView<UserController> {
  // No createController override needed!
  @override
  Widget build(BuildContext context, UserController controller) {
    return Scaffold(
      body: Obx(() => Text(controller.userName.value)),
    );
  }
}
```
### **Global Registration**
``` dart
// 1. Register globally at app start
void main() {
  Zen.init();
  
  // Global controllers available everywhere
  Zen.put<AppStateController>(AppStateController());
  Zen.put<ThemeController>(ThemeController());
  Zen.put<AuthController>(AuthController());
  
  runApp(MyApp());
}

// 2. Access from any page without createController
class HomePage extends ZenView<AppStateController> {
  @override
  Widget build(BuildContext context, AppStateController controller) {
    return Scaffold(
      body: Obx(() => Text('User: ${controller.currentUser.value?.name ?? "Guest"}')),
    );
  }
}

// 3. Optional access with ZenConsumer
class OptionalFeature extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenConsumer<PremiumController>(
      builder: (premium) => premium != null 
        ? PremiumWidget(controller: premium)
        : StandardWidget(),
    );
  }
}
```
### **Scope Hierarchy Access**
``` dart
// Parent scope has shared services
class AppModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<DatabaseService>(DatabaseService());
    scope.put<UserService>(UserService());
  }
}

// Child scope adds feature-specific controllers
class FeatureModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    final userService = scope.find<UserService>()!; // From parent
    scope.put<FeatureController>(FeatureController(userService));
  }
}

// Page can access both parent and child controllers
class FeaturePage extends ZenView<FeatureController> {
  @override
  Widget build(BuildContext context, FeatureController controller) {
    return ZenConsumer<UserService>( // Access parent service
      builder: (userService) => Scaffold(
        body: Column(
          children: [
            if (userService != null)
              UserInfo(service: userService),
            Obx(() => FeatureContent(
              data: controller.featureData.value,
            )),
          ],
        ),
      ),
    );
  }
}
```
## Anti-Patterns to Avoid
### ❌ **DON'T: Find controllers in build method**
``` dart
// DON'T DO THIS
class BadExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.find<MyController>(); // ❌ Bad
    
    return Obx(() => Text(controller.value.value));
  }
}
```
### ✅ **DO: Use appropriate pattern based on scenario**
``` dart
// ✅ When controller is required and should exist
class GoodExample extends ZenView<MyController> {
  @override
  Widget build(BuildContext context, MyController controller) {
    return Obx(() => Text(controller.value.value));
  }
}

// ✅ When controller is optional
class FlexibleExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZenConsumer<MyController>(
      builder: (controller) => controller != null
        ? Obx(() => Text(controller.value.value))
        : Text('Default value'),
    );
  }
}
```
### ❌ **DON'T: Override createController when not needed**
``` dart
// DON'T DO THIS if controller is already in scope
class UnnecessaryOverride extends ZenView<GlobalController> {
  @override
  GlobalController createController() => GlobalController(); // ❌ Wasteful
  
  @override
  Widget build(BuildContext context, GlobalController controller) {
    return MyWidget();
  }
}
```
### ✅ **DO: Let ZenView find existing controllers**
``` dart
// DO THIS - ZenView automatically finds existing controller
class EfficientExample extends ZenView<GlobalController> {
  // No createController override - uses existing from scope
  @override
  Widget build(BuildContext context, GlobalController controller) {
    return MyWidget();
  }
}
```
### ❌ **DON'T: Create reactive values outside controllers**
``` dart
// DON'T DO THIS
class BadWidget extends StatelessWidget {
  final counter = 0.obs(); // ❌ Memory leak - no cleanup
  
  @override
  Widget build(BuildContext context) {
    return Obx(() => Text('${counter.value}'));
  }
}
```
### ✅ **DO: Always use controllers for state management**
``` dart
// DO THIS
class CounterController extends ZenController {
  final counter = 0.obs();
  
  void increment() => counter.value++;
}

class GoodWidget extends ZenView<CounterController> {
  @override
  CounterController createController() => CounterController();
  
  @override
  Widget build(BuildContext context, CounterController controller) {
    return Obx(() => Text('${controller.counter.value}'));
  }
}
```
## Summary
Zenify's state management patterns provide:
- ** ZenView**: Best for pages - works with both local and existing controllers
- **️ ZenConsumer**: Perfect for optional/conditional controller access
- **⚡ ZenBuilder**: Reliable access to existing controllers with error handling
- ** ZenControllerScope**: Fine-grained control over controller lifecycle
- ** Obx**: Simple reactive UI when you already have controller reference

**Key Decision Tree:**
1. **Building a page?** → Use `ZenView<Controller>`
2. **Controller might not exist?** → Use `ZenConsumer<Controller>`
3. **Need existing shared controller?** → Use `ZenBuilder<Controller>`
4. **Need custom lifecycle control?** → Use `ZenControllerScope<Controller>`
5. **Already have controller reference?** → Use `Obx(() => ...)`

**ZenView Controller Resolution:**
- ✅ **First**: Uses `createController()` if overridden
- ✅ **Then**: Searches scope hierarchy for existing controller
- ✅ **Finally**: Provides controller directly in `build()` method

**Best Practices:**
- Use reactive values () for all state `.obs()`
- Implement proper cleanup in `onClose()`
- Leverage scope hierarchy for service sharing
- Use effects for async operations
- Test controllers in isolation
- Apply targeted updates for performance
- Follow single responsibility principle

This comprehensive approach lets you choose the right pattern for each situation while maintaining clean, efficient, and scalable code.
