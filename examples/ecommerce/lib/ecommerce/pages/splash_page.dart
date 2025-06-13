
import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../routes/app_routes.dart';

/// Splash page for the e-commerce app
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    if (_isNavigating) return;

    try {
      // Wait for the initial build to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Ensure Zenify is properly initialized
      // This helps with browser refresh scenarios
      if (!mounted) return;

      // Wait a minimum time for splash visibility
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted || _isNavigating) return;

      _isNavigating = true;

      // Navigate to home
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    } catch (e) {
      ZenLogger.logError('Splash navigation error: $e');

      // Fallback - still navigate after a delay
      if (mounted && !_isNavigating) {
        _isNavigating = true;
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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