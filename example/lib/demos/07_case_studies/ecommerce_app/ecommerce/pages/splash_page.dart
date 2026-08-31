import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../routes/app_routes.dart';

/// Controller handling splash screen lifecycle and startup routing
class SplashController extends ZenController {
  final isNavigating = false.obs();

  Future<void> initializeAndNavigate(BuildContext context) async {
    if (isNavigating.value) return;
    isNavigating.value = true;

    try {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    } catch (e) {
      ZenLogger.logError('Splash navigation error: $e');
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    }
  }
}

/// Splash page for the e-commerce app implemented with ZenProvider & ZenView
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ZenProvider.create(
      create: () => SplashController(),
      child: const _SplashView(),
    );
  }
}

class _SplashView extends ZenView<SplashController> {
  const _SplashView();

  @override
  Widget build(BuildContext context, SplashController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.initializeAndNavigate(context);
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade800,
              Colors.indigo.shade500,
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_bag,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              Text(
                'Zenify Shop',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Shopping made simple',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 48),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
