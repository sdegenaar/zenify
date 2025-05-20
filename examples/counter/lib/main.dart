// main.dart
import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import 'dart:developer' as developer;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure ZenState based on environment
  final bool isProduction = const bool.fromEnvironment('dart.vm.product');
  ZenConfig.applyEnvironment(isProduction ? 'prod' : 'dev');

  // Set up logging
  ZenLogger.init(
      logHandler: (message, level) {
        // In production, filter out debug logs
        if (isProduction && level == LogLevel.debug) return;
        developer.log('ZEN [${level.toString().split('.').last.toUpperCase()}]: $message', name: 'ZenState');
      },
      // Fix the errorHandler signature to match the expected type
      errorHandler: (String message, [dynamic error, StackTrace? stackTrace]) {
        developer.log('ZEN ERROR: $message', name: 'ZenState');
        if (error != null) developer.log('Error: $error', name: 'ZenState');
        if (stackTrace != null) developer.log('Stack: $stackTrace', name: 'ZenState');

        // In a real app, you could integrate with your preferred error tracking system
        // but we'll keep it simple here
      }
  );

  // Initialize Zen
  Zen.init();

  // Register all feature providers/controllers here if needed
  // AuthControllers.register();
  // CartControllers.register();

  // Start metrics tracking in development
  if (!isProduction) {
    ZenMetrics.startPeriodicLogging(const Duration(minutes: 1));
  }

  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create route observer for auto-disposing controllers
    final routeObserver = ZenRouteObserver();

    // Register controllers for routes
    routeObserver.registerForRoute('/home', [HomeController]);
    routeObserver.registerForRoute('/profile', [ProfileController, SettingsController]);

    return MaterialApp(
      title: 'ZenState Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      navigatorObservers: [routeObserver],
      home: ZenControllerScope<HomeController>(
        create: () => HomeController(),
        child: const HomePage(),
      ),
    );
  }
}

// Controller that uses enhanced architecture
class HomeController extends ZenController {
  // Level 1: Local state
  RxInt counter = 0.obs();

  // Local state with observations
  final Rx<int> counterNotifier = Rx<int>(0);

  // Local state and global state
  RxString localMessage = "Hello".obs();
  final Rx<String> globalMessage = Rx<String>("Hello");

  // Add an effect for async operations
  late final ZenEffect<String> fetchEffect;

  // Global state
  final Rx<int> globalCounter = Rx<int>(0);

  HomeController() {
    // Track performance of operations
    ZenMetrics.startTiming('HomeController.init');

    // Create an effect for async operations
    fetchEffect = createEffect<String>(
      name: 'fetchData',
      initialData: 'No data fetched yet',
    );

    // Set up workers with auto-disposal
    final disposer = ZenWorkers.debounce(
      globalCounter,
          (value) {
        ZenLogger.logDebug('Global counter debounced: $value');
      },
      duration: const Duration(milliseconds: 500),
    );

    // Add a worker to watch the counter changes
    final counterWorker = ZenWorkers.ever(
        counterNotifier,
            (value) {
          if (value > 5) {
            updateMessage("Counter is getting high!");
          } else {
            updateMessage("Hello World");
          }
        }
    );

    addDisposer(disposer);
    addDisposer(counterWorker);

    ZenMetrics.stopTiming('HomeController.init');
  }

  void incrementLocal() {
    ZenMetrics.startTiming('HomeController.incrementLocal');
    counter.value = counter.value + 1;

    // Also update the notifier to trigger workers
    counterNotifier.value = counter.value;

    ZenMetrics.recordStateUpdate();
    ZenMetrics.stopTiming('HomeController.incrementLocal');
  }

  void updateMessage(String message) {
    // Update both local and global message
    localMessage.value = message;
    globalMessage.value = message;
  }

  // Example of using the async effect
  Future<void> fetchData() async {
    await fetchEffect.run(() async {
      // Simulate network request
      await Future.delayed(const Duration(seconds: 1));
      return "Data fetched at ${DateTime.now().toIso8601String()}";
    });
  }

  void incrementGlobal() {
    globalCounter.value = globalCounter.value + 1;
  }

  // Level 4: Manual update state
  int manualCounter = 0;

  void incrementManual() {
    manualCounter++;
    update(); // Update all ZenBuilder instances
  }

  void incrementSection(String sectionId) {
    manualCounter++;
    update([sectionId]); // Update only specific section
  }
}

// main.dart - Modified HomePage build method
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ZenState Home')),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Local state (Level 1)
              Obx(() {
                final controller = Zen.find<HomeController>()!;
                return Text('Local Counter: ${controller.counter.value}');
              }),

              ElevatedButton(
                onPressed: () => Zen.find<HomeController>()!.incrementLocal(),
                child: const Text('Increment Local'),
              ),

              const SizedBox(height: 20),

              // Example of bridged state
              Obx(() {
                final controller = Zen.find<HomeController>()!;
                return Column(
                  children: [
                    Text('Local Message: ${controller.localMessage.value}'),
                    Text('(This is also synced to global state)'),
                  ],
                );
              }),

              // Global state using Obx
              Obx(() {
                final controller = Zen.find<HomeController>()!;
                return Text('Global Message: ${controller.globalMessage.value}');
              }),

              ElevatedButton(
                onPressed: () => Zen.find<HomeController>()!.updateMessage("Updated: ${DateTime.now().second}"),
                child: const Text('Update Message'),
              ),

              const SizedBox(height: 20),

              // Example of ZenEffect
              Obx(() {
                final controller = Zen.find<HomeController>()!;
                return Column(
                  children: [
                    Text('Effect State:'),
                    if (controller.fetchEffect.isLoading.value)
                      const CircularProgressIndicator()
                    else if (controller.fetchEffect.error.value != null)
                      Text('Error: ${controller.fetchEffect.error.value}',
                          style: const TextStyle(color: Colors.red))
                    else
                      Text('Data: ${controller.fetchEffect.data.value}'),
                  ],
                );
              }),

              ElevatedButton(
                onPressed: () => Zen.find<HomeController>()!.fetchData(),
                child: const Text('Fetch Data'),
              ),

              const SizedBox(height: 20),

              // Global state
              Obx(() {
                final controller = Zen.find<HomeController>()!;
                return Text('Global Counter: ${controller.globalCounter.value}');
              }),

              ElevatedButton(
                onPressed: () {
                  final controller = Zen.find<HomeController>()!;
                  controller.incrementGlobal();
                },
                child: const Text('Increment Global'),
              ),

              const SizedBox(height: 30),
              const Divider(),

              // Level 4: Manual updates with ZenBuilder (GetBuilder equivalent)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Manual Updates (GetBuilder style)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Global ZenBuilder that updates with any update() call
                    ZenBuilder<HomeController>(
                      builder: (controller) => Text(
                        'Manual Counter: ${controller.manualCounter}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Two sections with different update IDs
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Section A - only updates with 'section-a' ID
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text('Section A'),
                              ZenBuilder<HomeController>(
                                id: 'section-a',
                                builder: (controller) => Text(
                                  '${controller.manualCounter}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Zen.find<HomeController>()!
                                    .incrementSection('section-a'),
                                child: const Text('Update A'),
                              ),
                            ],
                          ),
                        ),

                        // Section B - only updates with 'section-b' ID
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text('Section B'),
                              ZenBuilder<HomeController>(
                                id: 'section-b',
                                builder: (controller) => Text(
                                  '${controller.manualCounter}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Zen.find<HomeController>()!
                                    .incrementSection('section-b'),
                                child: const Text('Update B'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Button to update all sections
                    ElevatedButton(
                      onPressed: () => Zen.find<HomeController>()!.incrementManual(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Update All Sections'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder classes for the examples
class ProfileController extends ZenController {}
class SettingsController extends ZenController {}