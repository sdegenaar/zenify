import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../../shared/services/cart_service.dart';

/// Widget that displays a cart icon with a badge showing the item count
class CartBadge extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double iconSize;

  const CartBadge({
    super.key,
    this.onPressed,
    this.iconColor,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final cartService = Zen.findOrNull<CartService>();

    if (cartService == null) {
      // Fallback if cart service is not available
      return IconButton(
        icon: Icon(
          Icons.shopping_cart,
          color: iconColor,
          size: iconSize,
        ),
        onPressed: onPressed,
      );
    }

    return Obx(() {
      final itemCount = cartService.itemCount.value;

      return Stack(
        children: [
          IconButton(
            icon: Icon(
              Icons.shopping_cart,
              color: iconColor,
              size: iconSize,
            ),
            onPressed: onPressed,
          ),
          if (itemCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle, // This makes it perfectly round
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    itemCount > 99 ? '99+' : itemCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.0, // Removes extra line height
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}