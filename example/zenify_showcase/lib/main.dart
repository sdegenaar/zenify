import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import 'showcase/modules/showcase_module.dart';
import 'showcase/pages/showcase_home_page.dart';

Future<void> main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Zenify with DevTools support
  await Zen.init(
    registerDevTools: true, // Enables DevTools extension
  );

  // Configure Zenify for showcase
  ZenConfig.applyEnvironment(ZenEnvironment.debug);

  // Register all modules globally at startup
  await Zen.registerModules([
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
