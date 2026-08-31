import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../../shared/models/product_model.dart';

import '../controllers/product_detail_controller.dart';
import '../routes/app_routes.dart';
import '../widgets/cart_badge.dart';
import '../widgets/product_card.dart';

/// Product detail page for the e-commerce app
class ProductDetailPage extends ZenView<ProductDetailController> {
  final String productId;

  const ProductDetailPage({
    super.key,
    required this.productId,
  });

  @override
  Widget build(BuildContext context, ProductDetailController controller) {
    return Scaffold(
      appBar: AppBar(
        title: ZenEffectBuilder<Product>(
          effect: controller.productDetailEffect,
          onLoading: () => const Text('Loading...'),
          onError: (error) => const Text('Product Details'),
          onSuccess: (product) => Text(product.name),
        ),
        actions: [
          // Cart button
          CartBadge(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.cart),
          ),
        ],
      ),
      body: ZenEffectBuilder<Product>(
        effect: controller.productDetailEffect,
        onLoading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading product details...'),
            ],
          ),
        ),
        onError: (error) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Product not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => controller.loadProduct(productId),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
        onSuccess: (product) =>
            _buildProductContent(context, controller, product),
      ),
    );
  }

  Widget _buildProductContent(BuildContext context,
      ProductDetailController controller, Product product) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 680;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left column: Image Card
                          Expanded(
                            flex: 5,
                            child: _buildImageCard(
                              context,
                              controller,
                              product,
                              height: 400,
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Right column: Product Info & Actions
                          Expanded(
                            flex: 6,
                            child: _buildProductDetails(
                              context,
                              controller,
                              product,
                            ),
                          ),
                        ],
                      );
                    }

                    // Mobile Single Column
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImageCard(
                          context,
                          controller,
                          product,
                          height: 280,
                        ),
                        const SizedBox(height: 20),
                        _buildProductDetails(
                          context,
                          controller,
                          product,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 36),
                const Divider(),
                const SizedBox(height: 20),

                // Related products
                _buildRelatedProducts(context, controller, product),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(
      BuildContext context, ProductDetailController controller, Product product,
      {required double height}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              product.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                    size: 48,
                  ),
                );
              },
            ),
          ),
          // Floating Favorite button
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: IconButton(
                icon: ZenObserver(() => Icon(
                      controller.isFavorite.value
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: controller.isFavorite.value
                          ? Colors.red
                          : Colors.grey,
                    )),
                onPressed: () => controller.toggleFavorite(product),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetails(BuildContext context,
      ProductDetailController controller, Product product) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Categories
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: product.categories.map((category) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              child: Text(
                category.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        // Product Name
        Text(
          product.name,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 8),

        // Rating and reviews
        Row(
          children: [
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < product.rating.floor()
                      ? Icons.star_rounded
                      : (index < product.rating
                          ? Icons.star_half_rounded
                          : Icons.star_border_rounded),
                  color: Colors.amber,
                  size: 20,
                );
              }),
            ),
            const SizedBox(width: 8),
            Text(
              product.rating.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${product.reviewCount} reviews)',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Price
        Text(
          '\$${product.price.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),

        const SizedBox(height: 16),

        // Description
        Text(
          'About this item',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          product.description,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: isDark ? Colors.white70 : Colors.grey.shade800,
          ),
        ),

        const SizedBox(height: 24),

        // Quantity Selector + Add to Cart Row
        Row(
          children: [
            // Modern Quantity Stepper
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: controller.decrementQuantity,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ZenObserver(() => Text(
                          controller.quantity.value.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        )),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: controller.incrementQuantity,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Add to Cart Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await controller.addToCart(product);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.name} added to cart'),
                        action: SnackBarAction(
                          label: 'View Cart',
                          onPressed: () {
                            Navigator.of(context).pushNamed(AppRoutes.cart);
                          },
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text(
                  'Add to Cart',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRelatedProducts(BuildContext context,
      ProductDetailController controller, Product product) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You may also like',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Product>>(
            future: controller.getRelatedProducts(product),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const Center(
                  child: Text('No related products found'),
                );
              }

              final relatedProducts = snapshot.data!;
              return SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: relatedProducts.length,
                  itemBuilder: (context, index) {
                    final relatedProduct = relatedProducts[index];
                    return SizedBox(
                      width: 160,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: ProductCard(
                          product: relatedProduct,
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.productDetail,
                              arguments: {'productId': relatedProduct.id},
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
