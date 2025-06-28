
import 'package:zenify/zenify.dart';
import '../models/product_model.dart';

/// Service for managing products in the e-commerce app
class ProductService {
  // Mock data for products
  final List<Product> _products = [
    Product(
      id: '1',
      name: 'Wireless Headphones',
      description: 'Premium wireless headphones with noise cancellation and long battery life.',
      price: 199.99,
      imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400&h=300&fit=crop',
      categories: ['Electronics', 'Audio'],
      rating: 4.5,
      reviewCount: 128,
    ),
    Product(
      id: '2',
      name: 'Smart Watch',
      description: 'Track your fitness, receive notifications, and more with this stylish smart watch.',
      price: 249.99,
      imageUrl: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400&h=300&fit=crop',
      categories: ['Electronics', 'Wearables'],
      rating: 4.2,
      reviewCount: 95,
    ),
    Product(
      id: '3',
      name: 'Bluetooth Speaker',
      description: 'Portable Bluetooth speaker with 360-degree sound and waterproof design.',
      price: 79.99,
      imageUrl: 'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=400&h=300&fit=crop',
      categories: ['Electronics', 'Audio'],
      rating: 4.0,
      reviewCount: 62,
    ),
    Product(
      id: '4',
      name: 'Laptop Backpack',
      description: 'Durable backpack with padded laptop compartment and multiple pockets.',
      price: 59.99,
      imageUrl: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400&h=300&fit=crop',
      categories: ['Accessories', 'Bags'],
      rating: 4.7,
      reviewCount: 214,
    ),
    Product(
      id: '5',
      name: 'Wireless Charger',
      description: 'Fast wireless charging pad compatible with all Qi-enabled devices.',
      price: 29.99,
      imageUrl: 'https://images.unsplash.com/photo-1586953208448-b95a79798f07?w=400&h=300&fit=crop',
      categories: ['Electronics', 'Accessories'],
      rating: 4.3,
      reviewCount: 78,
    ),
    Product(
      id: '6',
      name: 'Coffee Maker',
      description: 'Programmable coffee maker with thermal carafe to keep your coffee hot for hours.',
      price: 89.99,
      imageUrl: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400&h=300&fit=crop',
      categories: ['Home', 'Kitchen'],
      rating: 4.6,
      reviewCount: 156,
    ),
  ];

  /// ZenEffect for loading all products
  late final ZenEffect<List<Product>> loadProductsEffect;

  /// ZenEffect for loading a single product
  late final ZenEffect<Product> loadProductEffect;

  /// Constructor
  ProductService() {
    // Initialize effects
    loadProductsEffect = createEffect<List<Product>>(name: 'products');
    loadProductEffect = createEffect<Product>(name: 'product');
  }

  /// Load all products
  Future<List<Product>> getProducts() async {
    // Set effect to loading state
    loadProductsEffect.loading();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Set effect to success state
    loadProductsEffect.success(_products);

    return _products;
  }

  /// Get a product by ID
  Future<Product?> getProductById(String id) async {
    // Set effect to loading state
    loadProductEffect.loading();

    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      final product = _products.firstWhere(
            (product) => product.id == id,
        orElse: () => throw Exception('Product not found'),
      );

      // Set effect to success state
      loadProductEffect.success(product);

      return product;
    } catch (e) {
      // Set effect to error state
      loadProductEffect.setError(e);
      rethrow;
    }
  }

  /// Search products by query
  Future<List<Product>> searchProducts(String query) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    if (query.isEmpty) {
      return _products;
    }

    final lowercaseQuery = query.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(lowercaseQuery) ||
          product.description.toLowerCase().contains(lowercaseQuery) ||
          product.categories.any((category) => category.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  /// Get products by category
  Future<List<Product>> getProductsByCategory(String category) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    if (category.isEmpty) {
      return _products;
    }

    final lowercaseCategory = category.toLowerCase();
    return _products.where((product) {
      return product.categories.any((cat) => cat.toLowerCase() == lowercaseCategory);
    }).toList();
  }
}