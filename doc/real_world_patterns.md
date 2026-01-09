# Real-World Patterns

**Production-ready patterns for common use cases in Zenify**

This guide shows detailed examples of how to implement common patterns in real-world applications.

---

## Table of Contents

1. [Infinite Scroll with Pagination](#infinite-scroll-with-pagination)
2. [Mutations with Optimistic Updates](#mutations-with-optimistic-updates)
3. [Real-Time Data Streams](#real-time-data-streams)
4. [Global Access with .to Pattern](#global-access-with-to-pattern)
5. [Effects for Async Operations](#effects-for-async-operations)
6. [Computed Values with Dependency Tracking](#computed-values-with-dependency-tracking)
7. [Global Module Registration](#global-module-registration)
8. [Performance Control Patterns](#performance-control-patterns)

---

## Infinite Scroll with Pagination

Use `ZenInfiniteQuery` for paginated data with automatic next-page loading.

**Controller with Query:**

```dart
class PostFeedController extends ZenController {
  late final postsQuery = ZenInfiniteQuery<PostPage>(
    queryKey: ['posts', 'feed'],
    infiniteFetcher: (cursor, token) => api.getPosts(cursor: cursor),
    getNextPageParam: (lastPage) => lastPage.nextCursor,
    config: ZenQueryConfig(
      staleTime: Duration(minutes: 5),
      cacheTime: Duration(minutes: 30),
    ),
  );

  @override
  void onInit() {
    super.onInit();
    postsQuery.fetch(); // Initial fetch
  }
}
```

**Basic UI:**

```dart
class PostFeedPage extends ZenView<PostFeedController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Posts')),
      body: ZenQueryBuilder<List<PostPage>>(
        query: controller.postsQuery,
        keepPreviousData: true, // Show old data while loading next page
        builder: (context, pages) {
          // Flatten pages into posts
          final allPosts = pages.expand((page) => page.posts).toList();

          return ListView.builder(
            itemCount: allPosts.length + 1,
            itemBuilder: (context, index) {
              // Load more when reaching end
              if (index == allPosts.length) {
                if (controller.postsQuery.hasNextPage.value) {
                  controller.postsQuery.fetchNextPage();
                  return Center(child: CircularProgressIndicator());
                }
                return SizedBox.shrink();
              }

              return PostCard(allPosts[index]);
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, retry) => ErrorView(error, onRetry: retry),
      ),
    );
  }
}
```

**Advanced: With Pull-to-Refresh**

```dart
class PostFeedPage extends ZenView<PostFeedController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Posts')),
      body: ZenQueryBuilder<List<PostPage>>(
        query: controller.postsQuery,
        keepPreviousData: true,
        builder: (context, pages) {
          final allPosts = pages.expand((page) => page.posts).toList();

          return RefreshIndicator(
            onRefresh: () => controller.postsQuery.refetch(),
            child: ListView.builder(
              itemCount: allPosts.length + 1,
              itemBuilder: (context, index) {
                if (index == allPosts.length) {
                  return Obx(() {
                    if (controller.postsQuery.hasNextPage.value) {
                      controller.postsQuery.fetchNextPage();
                      return controller.postsQuery.isFetchingNextPage.value
                        ? Center(child: CircularProgressIndicator())
                        : SizedBox.shrink();
                    }
                    return SizedBox.shrink();
                  });
                }

                return PostCard(allPosts[index]);
              },
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, retry) => Center(
          child: ErrorView(error, onRetry: retry),
        ),
      ),
    );
  }
}
```

---

## Mutations with Optimistic Updates

Update UI immediately, rollback on error.

**Controller with Query and Mutation:**

```dart
class UserProfileController extends ZenController {
  late final userQuery = ZenQuery<User>(
    queryKey: ['user', userId],
    fetcher: (_) => api.getUser(userId),
  );

  late final updateUserMutation = ZenMutation<User, UpdateUserArgs>(
    mutationFn: (args) => api.updateUser(args),
    onMutate: (args) {
      // Save current state for rollback
      final oldUser = userQuery.data.value;

      // Optimistically update UI
      userQuery.data.value = args.toUser();

      // Return context for rollback
      return oldUser;
    },
    onError: (error, args, context) {
      // Rollback on error
      userQuery.data.value = context as User;
      showSnackbar('Update failed: $error');
    },
    onSuccess: (user, args, context) {
      showSnackbar('Profile updated!');
    },
    onSettled: () {
      // Always refetch to ensure consistency
      userQuery.refetch();
    },
  );

  @override
  void onInit() {
    super.onInit();
    userQuery.fetch();
  }

  void updateProfile(UpdateUserArgs args) {
    updateUserMutation.mutate(args);
  }
}
```

**UI:**

```dart
class UserProfilePage extends ZenView<UserProfileController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: ZenQueryBuilder<User>(
        query: controller.userQuery,
        builder: (context, user) => Column(
          children: [
            Text(user.name),
            Text(user.email),
            ElevatedButton(
              onPressed: () => controller.updateProfile(
                UpdateUserArgs(name: 'New Name'),
              ),
              child: Text('Update Name'),
            ),
          ],
        ),
        loading: () => CircularProgressIndicator(),
        error: (error, retry) => ErrorView(error, onRetry: retry),
      ),
    );
  }
}
```

**Advanced: Multiple Query Invalidation**

```dart
class PostListController extends ZenController {
  final String userId;

  PostListController({required this.userId});

  late final deletePostMutation = ZenMutation<void, String>(
    mutationFn: (postId) => api.deletePost(postId),
    onMutate: (postId) {
      // Optimistically remove from all affected queries
      final feedQuery = Zen.findQuery<List<Post>>(['posts', 'feed']);
      final userPostsQuery = Zen.findQuery<List<Post>>(['posts', 'user', userId]);

      final oldFeed = feedQuery?.data.value;
      final oldUserPosts = userPostsQuery?.data.value;

      feedQuery?.data.value = oldFeed?.where((p) => p.id != postId).toList();
      userPostsQuery?.data.value = oldUserPosts?.where((p) => p.id != postId).toList();

      return {'feed': oldFeed, 'userPosts': oldUserPosts};
    },
    onError: (error, postId, context) {
      // Rollback all queries
      final ctx = context as Map<String, dynamic>;
      Zen.findQuery<List<Post>>(['posts', 'feed'])?.data.value = ctx['feed'];
      Zen.findQuery<List<Post>>(['posts', 'user', userId])?.data.value = ctx['userPosts'];
      showError('Failed to delete post');
    },
    onSettled: () {
      // Refetch all affected queries
      Zen.invalidateQueries(['posts']);
    },
  );

  void deletePost(String postId) {
    deletePostMutation.mutate(postId);
  }
}
```

---

## Real-Time Data Streams

Handle WebSocket or Firebase streams with `ZenStreamQuery`.

**Controller with Stream Query:**

```dart
class ChatController extends ZenController {
  final String roomId;

  ChatController({required this.roomId});

  late final chatQuery = ZenStreamQuery<List<Message>>(
    queryKey: ['chat', roomId],
    streamFn: () => chatService.getMessagesStream(roomId),
    config: ZenQueryConfig(
      refetchOnReconnect: true,
    ),
  );

  @override
  void onInit() {
    super.onInit();
    chatQuery.fetch(); // Start listening to stream
  }
}
```

**UI:**

```dart
class ChatPage extends ZenView<ChatController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: ZenStreamQueryBuilder<List<Message>>(
        query: controller.chatQuery,
        builder: (context, messages) => ChatList(messages),
        loading: () => LoadingSpinner(),
        error: (error) => ErrorView(error),
      ),
    );
  }
}
```

**Advanced: Real-Time with Optimistic Updates**

```dart
class ChatController extends ZenController {
  final chatQuery = ZenStreamQuery<List<Message>>(
    queryKey: ['chat', roomId],
    streamFn: () => chatService.getMessagesStream(roomId),
  );

  final sendMessageMutation = ZenMutation<Message, String>(
    mutationFn: (text) => chatService.sendMessage(roomId, text),
    onMutate: (text) {
      // Optimistically add message
      final tempMessage = Message(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        userId: currentUserId,
        timestamp: DateTime.now(),
        isPending: true,
      );

      final currentMessages = chatQuery.data.value ?? [];
      chatQuery.data.value = [...currentMessages, tempMessage];

      return tempMessage;
    },
    onSuccess: (sentMessage, text, tempMessage) {
      // Replace temp message with real one
      final messages = chatQuery.data.value ?? [];
      final index = messages.indexWhere((m) => m.id == (tempMessage as Message).id);
      if (index != -1) {
        messages[index] = sentMessage;
        chatQuery.data.value = [...messages];
      }
    },
    onError: (error, text, tempMessage) {
      // Remove temp message on error
      final messages = chatQuery.data.value ?? [];
      chatQuery.data.value = messages.where((m) => m.id != (tempMessage as Message).id).toList();
      showError('Failed to send message');
    },
  );

  void sendMessage(String text) {
    sendMessageMutation.mutate(text);
  }
}
```

---

## Global Access with .to Pattern

Clean, type-safe access to global services from anywhere - no context, no builders!

### Basic Pattern

```dart
// Define services with static accessor
class CartService {
  static CartService get to => Zen.find<CartService>();

  final items = <CartItem>[].obs();
  final totalPrice = 0.0.obs();

  Future<void> addToCart(Product product) async {
    items.add(CartItem.fromProduct(product));
    _updateTotals();
  }

  void _updateTotals() {
    totalPrice.value = items.fold(0.0, (sum, item) => sum + item.price);
  }
}

class AuthService {
  static AuthService get to => Zen.find<AuthService>();

  final currentUser = Rx<User?>(null);
  final isAuthenticated = false.obs();

  Future<void> login(String email, String password) async {
    final user = await api.login(email, password);
    currentUser.value = user;
    isAuthenticated.value = true;
  }

  Future<void> logout() async {
    await api.logout();
    currentUser.value = null;
    isAuthenticated.value = false;
  }
}

// Register globally
void main() {
  Zen.init();
  Zen.put<CartService>(CartService(), isPermanent: true);
  Zen.put<AuthService>(AuthService(), isPermanent: true);
  runApp(MyApp());
}
```

### Access from Widgets

```dart
// Access from ANYWHERE - no injection needed!
class ProductCard extends StatelessWidget {
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(product.name),
          Text('\$${product.price}'),
          ElevatedButton(
            onPressed: () => CartService.to.addToCart(product),
            child: Text('Add to Cart'),
          ),
          // Works in reactive widgets too!
          Obx(() => Text('Cart: ${CartService.to.items.length} items')),
        ],
      ),
    );
  }
}

// Even in nested widgets
class CartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() => Badge(
      label: Text('${CartService.to.items.length}'),
      child: Icon(Icons.shopping_cart),
    ));
  }
}
```

### Access from Controllers

```dart
// Works in controllers without injection
class CheckoutController extends ZenController {
  Future<void> processOrder() async {
    // Check auth state
    if (!AuthService.to.isAuthenticated.value) {
      showLoginDialog();
      return;
    }

    // Get cart items
    final items = CartService.to.items.value;
    if (items.isEmpty) {
      showError('Cart is empty');
      return;
    }

    // Process payment
    final total = CartService.to.totalPrice.value;
    await paymentService.process(items, total);

    // Clear cart
    await CartService.to.clearCart();

    showSuccess('Order placed!');
  }
}
```

### Access from Helper Classes

```dart
// Even works in helper classes!
class AnalyticsHelper {
  static void trackCartEvent() {
    analytics.log('cart_items', {
      'count': CartService.to.items.length,
      'total': CartService.to.totalPrice.value,
    });
  }

  static void trackUserEvent(String event) {
    final user = AuthService.to.currentUser.value;
    analytics.log(event, {
      'userId': user?.id,
      'userName': user?.name,
    });
  }
}
```

### When to Use .to Pattern

**Use `.to` pattern for:**
- ✅ Global services (auth, cart, theme, settings)
- ✅ Services accessed from many places
- ✅ Avoid prop drilling
- ✅ Familiar to GetX users

**Use constructor injection for:**
- ✅ Page-specific controllers
- ✅ Services you want to mock in tests
- ✅ Optional dependencies

### Pro Tip: Hybrid Approach

Mix `.to` for global services with constructor injection for testable dependencies:

```dart
class ProductDetailController extends ZenController {
  // Inject testable services
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

**This gives you:**
- Testability for repositories/APIs (injected)
- Convenience for global services (`.to`)
- Clear separation of concerns

---

## Effects for Async Operations

Automatic state management for loading/error/success states.

```dart
class UserController extends ZenController {
  late final userEffect = createEffect<User>(name: 'loadUser');
  late final updateEffect = createEffect<void>(name: 'updateUser');

  Future<void> loadUser(String id) async {
    await userEffect.run(() => api.getUser(id));
  }

  Future<void> updateProfile(UpdateUserArgs args) async {
    await updateEffect.run(() async {
      await api.updateUser(args);
      // Reload user after update
      await loadUser(args.userId);
    });
  }
}

// In UI - automatic state handling
ZenEffectBuilder<User>(
  effect: controller.userEffect,
  onLoading: () => LoadingSpinner(),
  onSuccess: (user) => UserProfile(user),
  onError: (error) => ErrorMessage(error),
)
```

**Advanced: Multiple Effects in One Widget**

```dart
class ProfilePage extends ZenView<ProfileController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Column(
        children: [
          // Load effect
          ZenEffectBuilder<User>(
            effect: controller.loadEffect,
            onLoading: () => LoadingSpinner(),
            onSuccess: (user) => Column(
              children: [
                Text(user.name),
                Text(user.email),

                // Update effect
                ZenEffectBuilder<void>(
                  effect: controller.updateEffect,
                  onLoading: () => LinearProgressIndicator(),
                  onSuccess: (_) => SuccessMessage('Updated!'),
                  onError: (error) => ErrorBanner(error),
                  onIdle: () => EditButton(
                    onPressed: () => controller.updateProfile(newData),
                  ),
                ),
              ],
            ),
            onError: (error) => ErrorView(error),
          ),
        ],
      ),
    );
  }
}
```

[See complete Effects Guide →](effects_usage_guide.md)

---

## Computed Values with Dependency Tracking

Automatic recalculation when dependencies change.

```dart
class ShoppingController extends ZenController {
  final items = <CartItem>[].obs();
  final discount = 0.0.obs();
  final taxRate = 0.08.obs();

  // Computed getters - recalculate on access
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.price);
  double get discountAmount => subtotal * discount.value;
  double get taxableAmount => subtotal - discountAmount;
  double get taxAmount => taxableAmount * taxRate.value;
  double get total => taxableAmount + taxAmount;

  // Or use RxComputed for cached computed values
  late final subtotalComputed = computed(() =>
    items.fold(0.0, (sum, item) => sum + item.price)
  );

  late final totalComputed = computed(() {
    final sub = subtotalComputed.value;
    final disc = sub * discount.value;
    final taxable = sub - disc;
    final tax = taxable * taxRate.value;
    return taxable + tax;
  });
}

// In UI - automatic updates when items, discount, or taxRate change
Obx(() => Column(
  children: [
    Text('Subtotal: \$${controller.subtotal.toStringAsFixed(2)}'),
    Text('Discount: \$${controller.discountAmount.toStringAsFixed(2)}'),
    Text('Tax: \$${controller.taxAmount.toStringAsFixed(2)}'),
    Text('Total: \$${controller.total.toStringAsFixed(2)}',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
  ],
))
```

---

## Global Module Registration

Set up your entire app architecture at startup.

```dart
// Core services module
class CoreModule extends ZenModule {
  @override
  String get name => 'Core';

  @override
  void register(ZenScope scope) {
    scope.put<DatabaseService>(DatabaseService(), isPermanent: true);
    scope.put<LoggingService>(LoggingService(), isPermanent: true);
    scope.put<StorageService>(StorageService(), isPermanent: true);
  }
}

// Network module
class NetworkModule extends ZenModule {
  @override
  String get name => 'Network';

  @override
  void register(ZenScope scope) {
    final logging = scope.find<LoggingService>()!;

    scope.put<ApiClient>(ApiClient(logger: logging), isPermanent: true);
    scope.put<ConnectivityService>(ConnectivityService(), isPermanent: true);
  }
}

// Auth module
class AuthModule extends ZenModule {
  @override
  String get name => 'Auth';

  @override
  void register(ZenScope scope) {
    final api = scope.find<ApiClient>()!;
    final storage = scope.find<StorageService>()!;

    scope.put<AuthService>(
      AuthService(api: api, storage: storage),
      isPermanent: true,
    );
  }
}

// Main app initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Zen.init();

  // Register app-wide modules in order
  await Zen.registerModules([
    CoreModule(),     // Database, logging, storage
    NetworkModule(),  // API clients, connectivity (depends on Core)
    AuthModule(),     // Authentication (depends on Network + Core)
  ]);

  runApp(MyApp());
}
```

---

## Performance Control Patterns

### Option 1: Reactive with Obx (Recommended - Simpler)

```dart
class DashboardController extends ZenController {
  final stats = <Stat>[].obs();
  final isLoading = false.obs();
  final selectedPeriod = Period.week.obs();

  void updateStats(List<Stat> newStats) {
    stats.value = newStats;  // Auto-updates Obx widgets
  }

  void changePeriod(Period period) {
    selectedPeriod.value = period;
    loadStats(period);
  }
}

// In UI - automatic rebuilds
class DashboardView extends ZenView<DashboardController> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Obx(() => PeriodSelector(
          selected: controller.selectedPeriod.value,
          onChanged: controller.changePeriod,
        )),
        Obx(() => controller.isLoading.value
          ? LoadingSpinner()
          : StatsChart(controller.stats),
        ),
      ],
    );
  }
}
```

### Option 2: Manual with ZenBuilder (Fine Control)

```dart
class DashboardController extends ZenController {
  List<Stat> stats = [];
  bool isLoading = false;
  Period selectedPeriod = Period.week;

  void updateStats(List<Stat> newStats) {
    stats = newStats;
    update(['stats-chart']);  // Only rebuild chart
  }

  void changePeriod(Period period) {
    selectedPeriod = period;
    update(['period-selector']);  // Only rebuild selector
    loadStats(period);
  }

  void setLoading(bool loading) {
    isLoading = loading;
    update(['loading-state']);  // Only rebuild loading indicator
  }
}

// In UI - targeted rebuilds
class DashboardView extends ZenView<DashboardController> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ZenBuilder<DashboardController>(
          id: 'period-selector',
          builder: (context, ctrl) => PeriodSelector(
            selected: ctrl.selectedPeriod,
            onChanged: ctrl.changePeriod,
          ),
        ),
        ZenBuilder<DashboardController>(
          id: 'loading-state',
          builder: (context, ctrl) => ctrl.isLoading
            ? LoadingSpinner()
            : ZenBuilder<DashboardController>(
                id: 'stats-chart',
                builder: (context, ctrl) => StatsChart(ctrl.stats),
              ),
        ),
      ],
    );
  }
}
```

### Option 3: Mixed Pattern (Optimize Where Needed)

```dart
class DashboardController extends ZenController {
  // Reactive for simple state
  final isLoading = false.obs();
  final selectedPeriod = Period.week.obs();

  // Non-reactive for complex objects
  List<Stat> stats = [];

  void updateStats(List<Stat> newStats) {
    stats = newStats;
    update(['stats-chart']);  // Manual update for complex list
  }

  void changePeriod(Period period) {
    selectedPeriod.value = period;  // Auto-updates Obx
    loadStats(period);
  }
}

// In UI - mix both approaches
class DashboardView extends ZenView<DashboardController> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Obx for reactive period
        Obx(() => PeriodSelector(
          selected: controller.selectedPeriod.value,
          onChanged: controller.changePeriod,
        )),

        // Obx for reactive loading
        Obx(() => controller.isLoading.value
          ? LoadingSpinner()
          // ZenBuilder for manual stats
          : ZenBuilder<DashboardController>(
              id: 'stats-chart',
              builder: (context, ctrl) => StatsChart(ctrl.stats),
            ),
        ),
      ],
    );
  }
}
```

**When to use each:**
- 🟢 **Obx + .obs()**: Most cases (simpler, less code)
- 🔵 **ZenBuilder + update()**: Complex objects, precise rebuild control
- 🟡 **Mixed**: Large apps, optimize hot paths only

---

## Summary

These patterns cover the most common use cases in production apps:

- **Infinite scroll** - Pagination with smart loading
- **Optimistic updates** - Instant UI, rollback on error
- **Real-time streams** - WebSocket/Firebase integration
- **Global access** - `.to` pattern for convenience
- **Effects** - Async state management
- **Computed values** - Derived state
- **Module registration** - App initialization
- **Performance** - Control when and what rebuilds

For more patterns, see:
- [State Management Patterns Guide](state_management_patterns.md)
- [ZenQuery Guide](zen_query_guide.md)
- [E-commerce Example](../example/ecommerce)