import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import 'showcase/modules/showcase_module.dart';
import 'showcase/pages/showcase_home_page.dart';

void main() {
  // Configure Zenify for showcase
  ZenConfig.enableDebugLogs = true;
  ZenConfig.enablePerformanceMetrics = true;

  // Register all modules globally at startup
  Zen.registerModules([
    ShowcaseModule(),
    // Add other modules here as your app grows
  ]);

  runApp(const ZenifyShowcaseApp());
}

class ZenifyShowcaseApp extends StatelessWidget {
  const ZenifyShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenify Features Showcase',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.light,
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
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ShowcaseHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}