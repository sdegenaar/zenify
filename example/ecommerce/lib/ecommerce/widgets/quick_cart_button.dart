import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../../shared/models/product_model.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/cart_service.dart';

/// Example widget demonstrating the `.to` static accessor pattern
/// This widget can add products to cart without needing CartService injection!
class QuickCartButton extends StatelessWidget {
  final Product product;
  final VoidCallback? onAdded;

  const QuickCartButton({
    super.key,
    required this.product,
    this.onAdded,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add_shopping_cart),
      onPressed: () async {
        // ⭐ CLEAN ACCESS: No ZenConsumer, no ZenBuilder, no injection!
        // Just use CartService.to to access the global service
        await CartService.to.addToCart(product);

        onAdded?.call();

        // Show feedback
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} added to cart'),
              duration: const Duration(seconds: 1),
              // Can even access cart state directly in callbacks!
              action: SnackBarAction(
                label: 'Cart (${CartService.to.itemCount.value})',
                onPressed: () {
                  // Navigate to cart
                },
              ),
            ),
          );
        }
      },
      tooltip: 'Add to cart',
    );
  }
}

/// Example: Using the `.to` pattern in a helper function
class CartHelper {
  /// Add product and show notification - works anywhere!
  static Future<void> quickAdd(Product product) async {
    await CartService.to.addToCart(product, quantity: 1);
    debugPrint(
        'Added ${product.name}. Cart now has ${CartService.to.itemCount.value} items.');
  }

  /// Check if product is already in cart
  static bool isInCart(Product product) {
    return CartService.to.cartItems.value
        .any((item) => item.product.id == product.id);
  }

  /// Get total cart value - accessible anywhere!
  static double get cartTotal => CartService.to.totalPrice.value;
}

/// Example: Using in a controller without dependency injection
class QuickBuyController extends ZenController {
  Future<void> buyNow(Product product) async {
    // No need to inject CartService - just use .to!
    await CartService.to.addToCart(product);

    // Can also access other global services
    if (AuthService.to.isAuthenticated.value) {
      // Proceed to checkout
      await checkout();
    } else {
      // Show login dialog
      debugPrint('Please log in first');
    }
  }

  Future<void> checkout() async {
    final items = CartService.to.cartItems.value;
    final total = CartService.to.totalPrice.value;

    debugPrint(
        'Checking out ${items.length} items for \$${total.toStringAsFixed(2)}');

    // Process payment...
    await Future.delayed(const Duration(seconds: 2));

    // Clear cart
    await CartService.to.clearCart();
  }
}
