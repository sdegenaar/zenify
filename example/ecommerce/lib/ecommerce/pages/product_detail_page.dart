import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../../shared/models/product_model.dart';
import '../../shared/services/product_service.dart';
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
        onSuccess: (product) => _buildProductContent(context, product),
      ),
    );
  }

  Widget _buildProductContent(BuildContext context, Product product) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Favorite button
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Obx(() => Icon(
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

          // Product info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name and price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Price
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Rating and reviews
                Row(
                  children: [
                    // Rating stars
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < product.rating.floor()
                              ? Icons.star
                              : (index < product.rating
                                  ? Icons.star_half
                                  : Icons.star_border),
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    // Rating value
                    Text(
                      product.rating.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Review count
                    Text(
                      '(${product.reviewCount} reviews)',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Categories
                Wrap(
                  spacing: 8,
                  children: product.categories.map((category) {
                    return Chip(
                      label: Text(category),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Description
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                // Quantity selector
                Row(
                  children: [
                    const Text(
                      'Quantity:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // Decrement button
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: controller.decrementQuantity,
                          ),
                          // Quantity
                          Obx(() => Text(
                                controller.quantity.value.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                          // Increment button
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: controller.incrementQuantity,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Add to cart button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text(
                      'Add to Cart',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Related products
          _buildRelatedProducts(context, product),
        ],
      ),
    );
  }

  Widget _buildRelatedProducts(BuildContext context, Product product) {
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
