import 'package:zenify/zenify.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/cart_service.dart';
import '../../shared/services/product_service.dart';

/// Main application module that registers global services
class AppModule extends ZenModule {
  @override
  String get name => 'AppModule';

  @override
  void register(ZenScope scope) {
    // Register global services as singletons
    scope.put<AuthService>(
      AuthService(),
      isPermanent: true,
    );

    scope.put<CartService>(
      CartService(),
      isPermanent: true,
    );

    scope.put<ProductService>(
      ProductService(),
      isPermanent: true,
    );
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    ZenLogger.logInfo('AppModule initialized');

    // Pre-load products
    final productService = scope.find<ProductService>();
    await productService?.getProducts();
  }
}
