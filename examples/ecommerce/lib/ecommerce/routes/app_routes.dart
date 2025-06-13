import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../modules/auth_module.dart';
import '../modules/cart_module.dart';
import '../modules/product_module.dart';
import '../pages/cart_page.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/product_detail_page.dart';
import '../pages/register_page.dart';
import '../pages/splash_page.dart';

/// Routes for the e-commerce app
/// 
/// This class demonstrates how to use ZenModulePage for routing and automatic
/// scope creation and cleanup.
class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String productDetail = '/product/detail';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String profile = '/profile';

  /// Route generator that uses ZenModulePage for automatic scope creation and cleanup
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashPage(),
        );
        
      case home:
        return MaterialPageRoute(
          builder: (_) => ZenModulePage(
            moduleBuilder: () => ProductModule(),
            page: const HomePage(),
            scopeName: 'HomeScope',
          ),
        );
        
      case login:
        return MaterialPageRoute(
          builder: (_) => ZenModulePage(
            moduleBuilder: () => AuthModule(),
            page: const LoginPage(),
            scopeName: 'LoginScope',
          ),
        );
        
      case register:
        return MaterialPageRoute(
          builder: (_) => ZenModulePage(
            moduleBuilder: () => AuthModule(),
            page: const RegisterPage(),
            scopeName: 'RegisterScope',
          ),
        );
        
      case productDetail:
        // Extract product ID from arguments
        final args = settings.arguments as Map<String, dynamic>?;
        final productId = args?['productId'] as String? ?? '';
        
        return MaterialPageRoute(
          builder: (_) => ZenModulePage(
            moduleBuilder: () => ProductModule(),
            page: ProductDetailPage(productId: productId),
            scopeName: 'ProductDetailScope',
          ),
        );
        
      case cart:
        return MaterialPageRoute(
          builder: (_) => ZenModulePage(
            moduleBuilder: () => CartModule(),
            page: const CartPage(),
            scopeName: 'CartScope',
          ),
        );
        
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Page not found')),
          ),
        );
    }
  }
}