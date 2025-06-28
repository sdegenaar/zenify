import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import 'app/modules/app_module.dart';
import 'app/routes/app_routes.dart';
import 'app/services/navigation_service.dart';

Future<void> main() async {
  // Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Zen with enhanced configuration
  Zen.init();

  // Configure for development with detailed logging
  ZenConfig.applyEnvironment('dev');
  ZenConfig.enableDebugLogs = true;
  ZenConfig.enablePerformanceMetrics = true;

  // Set up logger
  ZenLogger.init(
    logHandler: (message, level) {
      if (kDebugMode) {
        developer.log(
          'ZEN [${level.toString().split('.').last.toUpperCase()}]: $message',
          name: 'Zenify',
        );
      }
    },
  );

  // Register the app module which contains shared services
  await Zen.registerModules([
    AppModule(), // Global module containing shared services
  ]);

  // Run the app
  runApp(const CompanyApp());
}


/// Main application widget
class CompanyApp extends StatelessWidget {
  const CompanyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenify Hierarchical Scope Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5), // Indigo
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // 🔥 ADD THIS: Better chip theme for readability
        chipTheme: ChipThemeData(
          backgroundColor: Colors.blue.shade100,
          labelStyle: TextStyle(
            color: Colors.blue.shade800,
            fontWeight: FontWeight.w500,
          ),
          iconTheme: IconThemeData(
            color: Colors.blue.shade700,
          ),
          side: BorderSide(
            color: Colors.blue.shade300,
            width: 1,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        // 🔥 ADD THIS: Dark theme chip support
        chipTheme: ChipThemeData(
          backgroundColor: Colors.blue.shade800,
          labelStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          iconTheme: const IconThemeData(
            color: Colors.white,
          ),
          side: BorderSide(
            color: Colors.blue.shade600,
            width: 1,
          ),
        ),
      ),
      // Set the navigator key for the NavigationService
      navigatorKey: NavigationService.navigatorKey,

      // Use onGenerateRoute instead of static routes for hierarchical scoping
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.onGenerateRoute,

      // Register ZenRouteObserver to automatically clean up scopes on navigation
      // navigatorObservers: [ZenRouteObserver()],
      debugShowCheckedModeBanner: false,
    );
  }
}