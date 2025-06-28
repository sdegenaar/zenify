import 'package:zenify/zenify.dart';
import '../../shared/models/cart_item_model.dart';
import '../../shared/models/product_model.dart';
import '../../shared/services/cart_service.dart';
import '../../shared/services/product_service.dart';

/// Controller for the cart page
class CartController extends ZenController {
  final CartService cartService;
  final ProductService productService;

  // Observable state
  final isProcessingCheckout = false.obs();

  // Access to cart effect
  ZenEffect<List<CartItem>> get cartEffect => cartService.cartEffect;

  /// Constructor
  CartController({
    required this.cartService,
    required this.productService,
  });

  /// Get cart items from service
  List<CartItem> get cartItems => cartService.cartItems.value;

  /// Get total price from service
  double get totalPrice => cartService.totalPrice.value;

  /// Get item count from service
  int get itemCount => cartService.itemCount.value;

  /// Check if cart is empty
  bool get isEmpty => cartItems.isEmpty;

  /// Update quantity of an item
  Future<void> updateQuantity(String itemId, int newQuantity) async {
    try {
      await cartService.updateQuantity(itemId, newQuantity);
    } catch (e) {
      ZenLogger.logError('Error updating quantity: $e');
    }
  }

  /// Remove an item from the cart
  Future<void> removeItem(String itemId) async {
    try {
      await cartService.removeFromCart(itemId);
    } catch (e) {
      ZenLogger.logError('Error removing item: $e');
    }
  }

  /// Clear the cart
  Future<void> clearCart() async {
    try {
      await cartService.clearCart();
    } catch (e) {
      ZenLogger.logError('Error clearing cart: $e');
    }
  }

  /// Process checkout
  Future<bool> checkout() async {
    if (isEmpty) {
      return false;
    }

    isProcessingCheckout.value = true;

    try {
      // Simulate checkout process
      await Future.delayed(const Duration(seconds: 2));

      // Clear cart after successful checkout
      await cartService.clearCart();

      return true;
    } catch (e) {
      ZenLogger.logError('Error during checkout: $e');
      return false;
    } finally {
      isProcessingCheckout.value = false;
    }
  }

  /// Get recommended products
  Future<List<Product>> getRecommendedProducts() async {
    try {
      // Get all products
      final allProducts = await productService.getProducts();

      // Filter out products already in cart
      final cartProductIds = cartItems.map((item) => item.product.id).toSet();
      final recommendations = allProducts
          .where((product) => !cartProductIds.contains(product.id))
          .take(4)
          .toList();

      return recommendations;
    } catch (e) {
      ZenLogger.logError('Error getting recommended products: $e');
      return [];
    }
  }
}
