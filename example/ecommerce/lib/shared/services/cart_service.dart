import 'package:zenify/zenify.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

/// Service for managing the shopping cart in the e-commerce app
class CartService {
  // Observable list of cart items
  final cartItems = <CartItem>[].obs();

  // Observable total price
  final totalPrice = 0.0.obs();

  // Observable item count
  final itemCount = 0.obs();

  // ZenEffect for cart operations
  late final ZenEffect<List<CartItem>> cartEffect;

  /// Constructor
  CartService() {
    // Initialize with empty cart
    _updateCartStats();

    // Set up worker to update cart stats when items change
    ZenWorkers.ever(cartItems, (_) => _updateCartStats());

    // Initialize effect
    cartEffect = createEffect<List<CartItem>>(name: 'cart');
  }

  /// Add a product to the cart
  Future<void> addToCart(Product product, {int quantity = 1}) async {
    // Set effect to loading state
    cartEffect.loading();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Check if product already exists in cart
    final existingIndex =
        cartItems.value.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      // Update quantity if product already in cart
      final existingItem = cartItems[existingIndex];
      final newQuantity = existingItem.quantity + quantity;
      cartItems[existingIndex] = existingItem.updateQuantity(newQuantity);
    } else {
      // Add new item if product not in cart
      final newItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        product: product,
        quantity: quantity,
      );
      cartItems.add(newItem);
    }

    // Set effect to success state
    cartEffect.success(cartItems.value);
  }

  /// Remove an item from the cart
  Future<void> removeFromCart(String itemId) async {
    // Set effect to loading state
    cartEffect.loading();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 200));

    cartItems.value.removeWhere((item) => item.id == itemId);

    // Set effect to success state
    cartEffect.success(cartItems.value);
  }

  /// Update the quantity of an item in the cart
  Future<void> updateQuantity(String itemId, int newQuantity) async {
    // Set effect to loading state
    cartEffect.loading();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 200));

    if (newQuantity <= 0) {
      // Remove item if quantity is zero or negative
      await removeFromCart(itemId);
      return;
    }

    final index = cartItems.value.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      final item = cartItems[index];
      cartItems[index] = item.updateQuantity(newQuantity);

      // Set effect to success state
      cartEffect.success(cartItems.value);
    }
  }

  /// Clear the cart
  Future<void> clearCart() async {
    // Set effect to loading state
    cartEffect.loading();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    cartItems.clear();

    // Set effect to success state
    cartEffect.success(cartItems.value);
  }

  /// Update cart statistics (total price and item count)
  void _updateCartStats() {
    double total = 0;
    int count = 0;

    for (final item in cartItems.value) {
      total += item.totalPrice;
      count += item.quantity;
    }

    totalPrice.value = total;
    itemCount.value = count;
  }
}
