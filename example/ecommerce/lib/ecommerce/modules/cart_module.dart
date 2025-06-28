import 'package:zenify/zenify.dart';
import '../../shared/services/cart_service.dart';
import '../../shared/services/product_service.dart';
import '../controllers/cart_controller.dart';

/// Module for cart-related features
class CartModule extends ZenModule {
  @override
  String get name => 'CartModule';

  @override
  void register(ZenScope scope) {
    // Find services from the parent scope
    final cartService = Zen.find<CartService>();
    final productService = Zen.find<ProductService>();
    
    // Register controllers for this module
    scope.putLazy<CartController>(
      () => CartController(
        cartService: cartService,
        productService: productService,
      ),
    );
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('CartModule initialized');
    }
  }
  
  @override
  Future<void> onDispose(ZenScope scope) async {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('CartModule disposed');
    }
  }
}