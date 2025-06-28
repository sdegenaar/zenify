import 'package:zenify/zenify.dart';
import '../../shared/models/product_model.dart';
import '../../shared/services/product_service.dart';

/// Controller for the home page
class HomeController extends ZenController {
  final ProductService productService;

  // Observable state
  final products = <Product>[].obs();
  final isLoading = true.obs();
  final searchQuery = ''.obs();
  final selectedCategory = ''.obs();
  final categories = <String>[].obs();

  /// Constructor
  HomeController({required this.productService});

  @override
  void onInit() {
    super.onInit();
    loadProducts();

    // Set up workers to react to search and category changes
    ZenWorkers.debounce(
      searchQuery,
          (_) => filterProducts(),
      const Duration(milliseconds: 300),
    );

    ZenWorkers.ever(selectedCategory, (_) => filterProducts());
  }

  /// Load all products
  Future<void> loadProducts() async {
    isLoading.value = true;

    try {
      final allProducts = await productService.getProducts();
      products.value = allProducts;

      // Extract unique categories
      final allCategories = <String>{};
      for (final product in allProducts) {
        allCategories.addAll(product.categories);
      }
      categories.value = ['All', ...allCategories.toList()..sort()];

      if (selectedCategory.isEmpty) {
        selectedCategory.value = 'All';
      }
    } catch (e) {
      ZenLogger.logError('Error loading products: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Filter products based on search query and selected category
  Future<void> filterProducts() async {
    isLoading.value = true;

    try {
      List<Product> filteredProducts;

      // Apply category filter
      if (selectedCategory.value == 'All' || selectedCategory.value.isEmpty) {
        filteredProducts = await productService.getProducts();
      } else {
        filteredProducts = await productService.getProductsByCategory(selectedCategory.value);
      }

      // Apply search filter
      if (searchQuery.value.isNotEmpty) {
        final query = searchQuery.value.toLowerCase();
        filteredProducts = filteredProducts.where((product) {
          return product.name.toLowerCase().contains(query) ||
              product.description.toLowerCase().contains(query);
        }).toList();
      }

      products.value = filteredProducts;
    } catch (e) {
      ZenLogger.logError('Error filtering products: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Set search query
  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  /// Set selected category
  void setCategory(String category) {
    selectedCategory.value = category;
  }

  /// Clear filters
  void clearFilters() {
    searchQuery.value = '';
    selectedCategory.value = 'All';
  }
}