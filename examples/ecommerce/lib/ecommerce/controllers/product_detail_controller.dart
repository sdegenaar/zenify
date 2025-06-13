import 'package:zenify/zenify.dart';
import '../../shared/models/product_model.dart';
import '../../shared/services/product_service.dart';
import '../../shared/services/cart_service.dart';
import '../../shared/services/auth_service.dart';

/// Controller for the product detail page
class ProductDetailController extends ZenController {
  final ProductService productService;

  // Optional dependencies that will be lazily injected
  CartService? _cartService;
  AuthService? _authService;

  // Observable state
  final quantity = 1.obs();
  final isFavorite = false.obs();

  // Create a dedicated effect for loading product details
  late final ZenEffect<Product> productDetailEffect;

  /// Constructor
  ProductDetailController({required this.productService}) {
    // Initialize the effect
    productDetailEffect = createEffect<Product>(name: 'productDetail');
  }

  @override
  void onInit() {
    super.onInit();

    // Try to find optional dependencies
    _cartService = Zen.findOrNull<CartService>();
    _authService = Zen.findOrNull<AuthService>();
  }

  /// Initialize with product ID - called from the page
  void initialize(String productId) {
    loadProduct(productId);
  }

  /// Load product by ID
  Future<void> loadProduct(String productId) async {
    try {
      // Set effect to loading state
      productDetailEffect.loading();

      // Load the product
      final product = await productService.getProductById(productId);

      // Check if product is in favorites
      if (_authService != null) {
        isFavorite.value = _authService!.isFavorite(productId);
      }

      // Set effect to success state
      productDetailEffect.success(product);
    } catch (e) {
      ZenLogger.logError('Error loading product: $e');
      // Set effect to error state
      productDetailEffect.setError(e);
    }
  }

  /// Increment quantity
  void incrementQuantity() {
    quantity.value++;
  }

  /// Decrement quantity
  void decrementQuantity() {
    if (quantity.value > 1) {
      quantity.value--;
    }
  }

  /// Add to cart - now takes product as parameter
  Future<void> addToCart(Product product) async {
    if (_cartService == null) {
      ZenLogger.logError('CartService not available');
      return;
    }

    try {
      await _cartService!.addToCart(product, quantity: quantity.value);
      // Reset quantity after adding to cart
      quantity.value = 1;
    } catch (e) {
      ZenLogger.logError('Error adding to cart: $e');
    }
  }

  /// Toggle favorite status - now takes product as parameter
  Future<void> toggleFavorite(Product product) async {
    if (_authService == null) {
      ZenLogger.logError('AuthService not available');
      return;
    }

    try {
      if (!_authService!.isAuthenticated.value) {
        ZenLogger.logInfo('User must be logged in to add favorites');
        return;
      }

      await _authService!.toggleFavorite(product.id);
      isFavorite.value = !isFavorite.value;
    } catch (e) {
      ZenLogger.logError('Error toggling favorite: $e');
    }
  }

  /// Get related products - now takes product as parameter
  Future<List<Product>> getRelatedProducts(Product product) async {
    try {
      // Get products in the same category
      if (product.categories.isNotEmpty) {
        final category = product.categories.first;
        final relatedProducts = await productService.getProductsByCategory(category);

        // Filter out the current product
        return relatedProducts
            .where((p) => p.id != product.id)
            .take(4)
            .toList();
      }
    } catch (e) {
      ZenLogger.logError('Error getting related products: $e');
    }

    return [];
  }
}