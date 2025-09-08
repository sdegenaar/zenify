import 'package:zenify/zenify.dart';
import '../../shared/services/product_service.dart';
import '../controllers/home_controller.dart';

/// Module for product-related features
class ProductModule extends ZenModule {
  @override
  String get name => 'ProductModule';

  @override
  void register(ZenScope scope) {
    ZenLogger.logDebug(
        'ProductModule.register() called with scope: ${scope.name}');

    // Check if ProductService is available
    final productService = Zen.find<ProductService>();
    ZenLogger.logDebug('ProductService found: $productService');

    // Register controllers directly (not as factories for now)
    try {
      final homeController = HomeController(productService: productService);
      scope.put<HomeController>(homeController);
      ZenLogger.logDebug('HomeController registered successfully');
    } catch (e) {
      ZenLogger.logError('Error registering controllers: $e');
      rethrow;
    }
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('ProductModule initialized');

      // Verify controllers are accessible
      final homeController = scope.find<HomeController>();
      ZenLogger.logDebug(
          'HomeController accessible in scope: ${homeController != null}');
    }
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('ProductModule disposed');
    }
  }
}
