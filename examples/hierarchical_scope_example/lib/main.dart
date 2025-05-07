import 'package:flutter/material.dart';
import 'package:zen_state/zen_state.dart';
import 'modules/auth_module.dart';
import 'modules/network_module.dart';
import 'pages/login_page.dart';

void main() {
  // Enable debug logs to help with troubleshooting
  ZenConfig.enableDebugLogs = true;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Root scope for the entire app
    return ZenScopeWidget(
      isRoot: true,
      name: 'AppScope',
      child: MaterialApp(
        title: 'ZenState Hierarchical Scopes',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AppInitializer(),
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize after the first frame when context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Get the app scope
    final appScope = ZenScopeWidget.of(context);

    // Register modules
    ZenModuleRegistry.register(NetworkModule(), scope: appScope);
    ZenModuleRegistry.register(AuthModule(), scope: appScope);

    // Set initialized state
    setState(() {
      isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return const LoginPage();
  }
}