import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:zenify/zenify.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Zen with enhanced configuration
  Zen.init();

  // Configure for development with detailed logging
  ZenConfig.applyEnvironment('dev');
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

  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenify Counter Demo - Complete Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: ZenControllerScope<CounterController>(
        create: () => CounterController(),
        child: const CounterPage(),
      ),
    );
  }
}

/// Counter controller demonstrating ALL Zenify features:
/// - Reactive state (.obs)
/// - Async effects (ZenEffect)
/// - Reactive workers (ever, debounce, condition, interval)
/// - Manual updates (update())
/// - Lifecycle management (onReady, onDispose)
/// - Logging and metrics integration
/// - Error handling patterns
/// - Device persistence (SharedPreferences)
/// - Performance metrics tracking
class CounterController extends ZenController {
  // Reactive state (similar to GetX .obs)
  final RxInt counter = 0.obs();
  final RxString status = "Ready".obs();
  final RxBool isAutoSaveEnabled = false.obs();
  final Rx<DateTime> lastSaved = DateTime.now().obs();

  // New: Performance metrics
  final RxInt stateUpdateCount = 0.obs();
  final RxInt effectExecutionCount = 0.obs();
  final RxDouble averageEffectDuration = 0.0.obs();
  final RxString deviceStorageStatus = "Not loaded".obs();

  // Effects for async operations - fully reactive!
  late final ZenEffect<String> saveEffect;
  late final ZenEffect<String> loadEffect;
  late final ZenEffect<String> deviceSaveEffect;
  late final ZenEffect<String> deviceLoadEffect;

  // Manual update counter (GetBuilder style)
  int manualCounter = 0;

  // Worker handles for cleanup
  late final ZenWorkerGroup workerGroup;

  // Performance tracking
  final List<Duration> _effectDurations = [];
  final Random _random = Random();

  CounterController() {
    // Initialize effects with descriptive names
    saveEffect = createEffect<String>(name: 'saveCounter');
    loadEffect = createEffect<String>(name: 'loadCounter');
    deviceSaveEffect = createEffect<String>(name: 'deviceSave');
    deviceLoadEffect = createEffect<String>(name: 'deviceLoad');

    // Create worker group for organized cleanup
    workerGroup = createWorkerGroup();

    // Set up all reactive workers
    setupWorkers();

    // Load from device storage on startup
    loadFromDevice();

    ZenLogger.logInfo('CounterController created with enhanced features');
  }

  void setupWorkers() {
    // Ever worker - executes on every change (like GetX ever)
    workerGroup.add(ever(counter, (value) {
      ZenLogger.logDebug('Counter changed to: $value');
      _incrementStateUpdateCount();

      // Enhanced status updates with more personality
      if (value == 0) {
        status.value = "🏁 Ready to count!";
      } else if (value < 5) {
        status.value = "🔢 Counting up...";
      } else if (value < 10) {
        status.value = "📈 Getting higher!";
      } else if (value < 15) {
        status.value = "🚀 Reaching for the stars!";
      } else if (value < 20) {
        status.value = "💫 Astronomical numbers!";
      } else {
        status.value = "🌟 Infinite possibilities!";
      }
    }));

    // Debounce worker - waits for user to stop clicking (auto-save trigger)
    workerGroup.add(debounce(
      counter,
      (value) {
        ZenLogger.logDebug('Counter stabilized at: $value');
        if (isAutoSaveEnabled.value && value > 0) {
          saveCounter();
        }
      },
      const Duration(milliseconds: 800),
    ));

    // Condition worker - milestone celebrations
    workerGroup.add(condition(
      counter,
      (value) => value % 5 == 0 && value > 0, // Every 5th count
      (value) {
        ZenLogger.logInfo('Milestone reached: $value');
        status.value = "🎉 Milestone: $value! Amazing!";

        // Brief celebration, then return to normal status
        Future.delayed(const Duration(seconds: 3), () {
          if (!isDisposed && counter.value == value) {
            // Only update if counter hasn't changed
            _updateNormalStatus(value);
          }
        });
      },
    ));

    // Interval worker - periodic backup (when enabled)
    workerGroup.add(interval(
      isAutoSaveEnabled,
      (enabled) {
        if (enabled && counter.value > 0) {
          ZenLogger.logDebug('Periodic backup check: ${counter.value}');
          // Auto-save to device storage
          saveToDevice();
        }
      },
      const Duration(seconds: 30),
    ));

    // Watch save effect for status updates
    saveEffect.watch(
      this,
      onData: (result) {
        if (result != null) {
          lastSaved.value = DateTime.now();
          status.value = "✅ Saved successfully!";
          Future.delayed(const Duration(seconds: 2), () {
            if (!isDisposed) {
              _updateNormalStatus(counter.value);
            }
          });
        }
      },
      onError: (error) {
        if (error != null) {
          status.value = "❌ Save failed! ${error.toString()}";
          Future.delayed(const Duration(seconds: 3), () {
            if (!isDisposed) {
              _updateNormalStatus(counter.value);
            }
          });
        }
      },
    );

    // Watch load effect
    loadEffect.watch(
      this,
      onData: (result) {
        if (result != null) {
          status.value = "📥 Data loaded successfully!";
          Future.delayed(const Duration(seconds: 2), () {
            if (!isDisposed) {
              _updateNormalStatus(counter.value);
            }
          });
        }
      },
      onError: (error) {
        if (error != null) {
          status.value = "❌ Load failed!";
          Future.delayed(const Duration(seconds: 2), () {
            if (!isDisposed) {
              _updateNormalStatus(counter.value);
            }
          });
        }
      },
    );

    // Watch device storage effects
    deviceSaveEffect.watch(
      this,
      onData: (result) {
        if (result != null) {
          deviceStorageStatus.value = "✅ Saved to device";
          Future.delayed(const Duration(seconds: 3), () {
            if (!isDisposed) {
              deviceStorageStatus.value = "Ready";
            }
          });
        }
      },
      onError: (error) {
        if (error != null) {
          deviceStorageStatus.value = "❌ Device save failed";
        }
      },
    );

    deviceLoadEffect.watch(
      this,
      onData: (result) {
        if (result != null) {
          deviceStorageStatus.value = "📱 Loaded from device";
          Future.delayed(const Duration(seconds: 3), () {
            if (!isDisposed) {
              deviceStorageStatus.value = "Ready";
            }
          });
        }
      },
      onError: (error) {
        if (error != null) {
          deviceStorageStatus.value = "❌ Device load failed";
        }
      },
    );
  }

  void _updateNormalStatus(int value) {
    if (value == 0) {
      status.value = "🏁 Ready to count!";
    } else if (value < 5) {
      status.value = "🔢 Counting up...";
    } else if (value < 10) {
      status.value = "📈 Getting higher!";
    } else if (value < 15) {
      status.value = "🚀 Reaching for the stars!";
    } else if (value < 20) {
      status.value = "💫 Astronomical numbers!";
    } else {
      status.value = "🌟 Infinite possibilities!";
    }
  }

  // Performance metrics tracking
  void _incrementStateUpdateCount() {
    stateUpdateCount.value++;
    ZenMetrics.recordStateUpdate();
  }

  void _recordEffectExecution(Duration duration) {
    effectExecutionCount.value++;
    _effectDurations.add(duration);

    // Keep only last 10 executions for average calculation
    if (_effectDurations.length > 10) {
      _effectDurations.removeAt(0);
    }

    // Calculate average duration
    final totalMs = _effectDurations.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );
    averageEffectDuration.value = totalMs / _effectDurations.length;
  }

  // Reactive increment with enhanced metrics
  void increment() {
    counter.value++;
    ZenLogger.logDebug('Incremented to: ${counter.value}');
  }

  void decrement() {
    if (counter.value > 0) {
      counter.value--;
      ZenLogger.logDebug('Decremented to: ${counter.value}');
    }
  }

  void reset() {
    final oldValue = counter.value;
    counter.value = 0;
    status.value = "🔄 Reset complete!";
    manualCounter = 0;
    saveEffect.reset();
    loadEffect.reset();
    deviceSaveEffect.reset();
    deviceLoadEffect.reset();
    update(); // Update GetBuilder-style widgets

    ZenLogger.logInfo('Counter reset from $oldValue to 0');
  }

  void toggleAutoSave() {
    isAutoSaveEnabled.value = !isAutoSaveEnabled.value;
    ZenLogger.logInfo(
        'Auto-save ${isAutoSaveEnabled.value ? "enabled" : "disabled"}');
  }

  // Manual update increment (GetBuilder style)
  void incrementManual() {
    manualCounter++;
    update(); // Triggers ZenBuilder widgets to rebuild
    ZenLogger.logDebug('Manual counter incremented to: $manualCounter');
  }

  // Enhanced async save operation with realistic delays
  Future<void> saveCounter() async {
    final stopwatch = Stopwatch()..start();
    try {
      await saveEffect.run(() async {
        // Simulate network request with realistic random delay
        final delay =
            Duration(milliseconds: 1000 + _random.nextInt(2000)); // 1-3 seconds
        await Future.delayed(delay);

        // Enhanced error simulation - more discoverable
        if (counter.value > 15) {
          throw Exception(
              'Demo Error: Counter too high! (Try keeping it ≤ 15)');
        }

        final timestamp = DateTime.now().toLocal().toString().substring(11, 19);
        return 'Counter value ${counter.value} saved successfully at $timestamp';
      });
    } catch (e) {
      ZenLogger.logError('Save operation failed', e);
    } finally {
      stopwatch.stop();
      _recordEffectExecution(stopwatch.elapsed);
    }
  }

  // Load operation demo with realistic delays
  Future<void> loadCounter() async {
    final stopwatch = Stopwatch()..start();
    try {
      await loadEffect.run(() async {
        final delay = Duration(
            milliseconds: 800 + _random.nextInt(1500)); // 0.8-2.3 seconds
        await Future.delayed(delay);

        // Simulate loading a random saved value
        final loadedValue = _random.nextInt(20);
        counter.value = loadedValue;

        return 'Loaded counter value: $loadedValue';
      });
    } catch (e) {
      ZenLogger.logError('Load operation failed', e);
    } finally {
      stopwatch.stop();
      _recordEffectExecution(stopwatch.elapsed);
    }
  }

  // NEW: Device persistence with SharedPreferences
  Future<void> saveToDevice() async {
    final stopwatch = Stopwatch()..start();
    try {
      await deviceSaveEffect.run(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('zenify_counter', counter.value);
        await prefs.setInt('zenify_manual_counter', manualCounter);
        await prefs.setBool('zenify_auto_save', isAutoSaveEnabled.value);

        // Small delay to show the effect
        await Future.delayed(const Duration(milliseconds: 300));

        return 'Counter saved to device storage: ${counter.value}';
      });
    } catch (e) {
      ZenLogger.logError('Device save failed', e);
    } finally {
      stopwatch.stop();
      _recordEffectExecution(stopwatch.elapsed);
    }
  }

  Future<void> loadFromDevice() async {
    final stopwatch = Stopwatch()..start();
    try {
      await deviceLoadEffect.run(() async {
        final prefs = await SharedPreferences.getInstance();

        // Small delay to show the effect
        await Future.delayed(const Duration(milliseconds: 200));

        final savedCounter = prefs.getInt('zenify_counter') ?? 0;
        final savedManualCounter = prefs.getInt('zenify_manual_counter') ?? 0;
        final savedAutoSave = prefs.getBool('zenify_auto_save') ?? false;

        // Only update if we found saved data
        if (savedCounter > 0 || savedManualCounter > 0) {
          counter.value = savedCounter;
          manualCounter = savedManualCounter;
          isAutoSaveEnabled.value = savedAutoSave;
          update(); // Update manual counter display

          return 'Restored: Counter=$savedCounter, Manual=$savedManualCounter';
        } else {
          return 'No saved data found - starting fresh';
        }
      });
    } catch (e) {
      ZenLogger.logError('Device load failed', e);
    } finally {
      stopwatch.stop();
      _recordEffectExecution(stopwatch.elapsed);
    }
  }

  @override
  void onReady() {
    super.onReady();
    ZenLogger.logInfo('CounterController is ready and fully initialized!');
  }

  @override
  void onClose() {
    ZenLogger.logInfo('CounterController disposing - cleaning up resources');
    workerGroup.dispose();
    super.onClose();
  }
}

class CounterPage extends ZenView<CounterController> {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zenify Complete Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Auto-save toggle
          Obx(() => IconButton(
                onPressed: controller.toggleAutoSave,
                icon: Icon(
                  controller.isAutoSaveEnabled.value
                      ? Icons.auto_awesome
                      : Icons.auto_awesome_outlined,
                ),
                tooltip: controller.isAutoSaveEnabled.value
                    ? 'Auto-save ON'
                    : 'Auto-save OFF',
              )),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header info card
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      '🧘‍♂️ Zenify State Management Demo',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Showcasing reactive state, async effects, workers, persistence & metrics!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Obx(() => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Chip(
                              label: Text(
                                  'Auto-save: ${controller.isAutoSaveEnabled.value ? "ON" : "OFF"}'),
                              backgroundColor:
                                  controller.isAutoSaveEnabled.value
                                      ? Colors.green.shade100
                                      : Colors.grey.shade100,
                            ),
                            Obx(() => Chip(
                                  label: Text(
                                      'Device: ${controller.deviceStorageStatus.value}'),
                                  backgroundColor: controller
                                          .deviceStorageStatus.value
                                          .contains('✅')
                                      ? Colors.green.shade100
                                      : controller.deviceStorageStatus.value
                                              .contains('❌')
                                          ? Colors.red.shade100
                                          : Colors.blue.shade100,
                                )),
                          ],
                        )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // NEW: Performance Metrics Section (Debug mode only)
            if (kDebugMode) ...[
              Card(
                color: Colors.purple.shade50,
                child: ExpansionTile(
                  leading: Icon(Icons.analytics, color: Colors.purple.shade700),
                  title: Text(
                    'Performance Metrics (Debug)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  subtitle: const Text('Real-time performance monitoring'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Obx(() => Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('State Updates:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  Text('${controller.stateUpdateCount.value}',
                                      style: const TextStyle(fontSize: 16)),
                                ],
                              )),
                          const SizedBox(height: 8),
                          Obx(() => Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Effect Executions:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  Text(
                                      '${controller.effectExecutionCount.value}',
                                      style: const TextStyle(fontSize: 16)),
                                ],
                              )),
                          const SizedBox(height: 8),
                          Obx(() => Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Avg Effect Duration:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  Text(
                                      '${controller.averageEffectDuration.value.toStringAsFixed(0)}ms',
                                      style: const TextStyle(fontSize: 16)),
                                ],
                              )),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'These metrics show real-time performance data from ZenMetrics',
                              style: TextStyle(
                                  fontSize: 12, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Reactive UI Section (Obx demonstration)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Reactive Counter (Obx Pattern)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Enhanced counter display with animation
                    Obx(() => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: controller.counter.value > 10
                                ? Colors.purple.shade50
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: controller.counter.value > 10
                                  ? Colors.purple.shade200
                                  : Colors.blue.shade200,
                            ),
                          ),
                          child: Text(
                            '${controller.counter.value}',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.bold,
                              color: controller.counter.value > 10
                                  ? Colors.purple.shade700
                                  : Colors.blue.shade700,
                            ),
                          ),
                        )),

                    const SizedBox(height: 12),

                    // Enhanced status display
                    Obx(() => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            controller.status.value,
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )),

                    const SizedBox(height: 20),

                    // Enhanced action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: controller.decrement,
                          icon: const Icon(Icons.remove),
                          label: const Text('Decrease'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade700,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: controller.increment,
                          icon: const Icon(Icons.add),
                          label: const Text('Increase'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade100,
                            foregroundColor: Colors.green.shade700,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: controller.reset,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade100,
                            foregroundColor: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Enhanced Async Operations Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_sync,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Async Operations (ZenEffectBuilder)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Demonstrates declarative async UI with loading, error, and success states',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    // Save Effect Builder
                    ZenEffectBuilder<String>(
                      effect: controller.saveEffect,
                      onLoading: () => Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              '💾 Saving to cloud...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Please wait while we sync your data',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      onError: (error) => Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade50, Colors.red.shade100],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'Oops! Something went wrong',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              error.toString(),
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      onSuccess: (data) => Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade50,
                              Colors.green.shade100
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.green, size: 40),
                            const SizedBox(height: 12),
                            const Text(
                              'Success! 🎉',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data,
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      onInitial: () => Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.cloud_upload_outlined,
                                size: 40, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'Ready to save your progress',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Click save to store your counter value',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action buttons for async operations
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Save button with state-aware styling
                        ZenEffectBuilder<String>(
                          effect: controller.saveEffect,
                          onLoading: () => ElevatedButton.icon(
                            onPressed: null,
                            icon: const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            label: const Text('Saving...'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                          onError: (error) => ElevatedButton.icon(
                            onPressed: controller.saveCounter,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                          onSuccess: (data) => ElevatedButton.icon(
                            onPressed: controller.saveCounter,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                          onInitial: () => ElevatedButton.icon(
                            onPressed: controller.saveCounter,
                            icon: const Icon(Icons.save),
                            label: const Text('Save'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                        ),

                        // Load button
                        ZenEffectBuilder<String>(
                          effect: controller.loadEffect,
                          onLoading: () => ElevatedButton.icon(
                            onPressed: null,
                            icon: const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            label: const Text('Loading...'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade100,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                          onError: (error) => ElevatedButton.icon(
                            onPressed: controller.loadCounter,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Load'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                          onSuccess: (data) => ElevatedButton.icon(
                            onPressed: controller.loadCounter,
                            icon: const Icon(Icons.download),
                            label: const Text('Load Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                          onInitial: () => ElevatedButton.icon(
                            onPressed: controller.loadCounter,
                            icon: const Icon(Icons.download),
                            label: const Text('Load'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade100,
                              foregroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // NEW: Device Persistence Section
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Device Persistence (SharedPreferences)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Demonstrates local device storage with automatic restoration on app restart',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    // Device storage status
                    Obx(() => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                controller.deviceStorageStatus.value
                                        .contains('✅')
                                    ? Icons.check_circle
                                    : controller.deviceStorageStatus.value
                                            .contains('❌')
                                        ? Icons.error
                                        : Icons.storage,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Status: ${controller.deviceStorageStatus.value}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),

                    const SizedBox(height: 20),

                    // Device storage buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ZenEffectBuilder<String>(
                          effect: controller.deviceSaveEffect,
                          onLoading: () => ElevatedButton.icon(
                            onPressed: null,
                            icon: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            label: const Text('Saving...'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade200,
                              foregroundColor: Colors.amber.shade800,
                            ),
                          ),
                          onError: (error) => ElevatedButton.icon(
                            onPressed: controller.saveToDevice,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Save'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade300,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          onSuccess: (data) => ElevatedButton.icon(
                            onPressed: controller.saveToDevice,
                            icon: const Icon(Icons.save_alt),
                            label: const Text('Save Device'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade300,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          onInitial: () => ElevatedButton.icon(
                            onPressed: controller.saveToDevice,
                            icon: const Icon(Icons.save_alt),
                            label: const Text('Save Device'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade300,
                              foregroundColor: Colors.amber.shade800,
                            ),
                          ),
                        ),
                        ZenEffectBuilder<String>(
                          effect: controller.deviceLoadEffect,
                          onLoading: () => ElevatedButton.icon(
                            onPressed: null,
                            icon: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            label: const Text('Loading...'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade200,
                              foregroundColor: Colors.amber.shade800,
                            ),
                          ),
                          onError: (error) => ElevatedButton.icon(
                            onPressed: controller.loadFromDevice,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Load'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade300,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          onSuccess: (data) => ElevatedButton.icon(
                            onPressed: controller.loadFromDevice,
                            icon: const Icon(Icons.phone_android),
                            label: const Text('Load Device'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade300,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          onInitial: () => ElevatedButton.icon(
                            onPressed: controller.loadFromDevice,
                            icon: const Icon(Icons.phone_android),
                            label: const Text('Load Device'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade300,
                              foregroundColor: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Your data persists across app restarts! Try closing and reopening the app.',
                        style: TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Manual Update Section (GetBuilder style demonstration)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.build,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Manual Updates (ZenBuilder Pattern)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Similar to GetX GetBuilder - updates only when explicitly called',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    // Manual counter display with enhanced styling
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: ZenBuilder<CounterController>(
                        builder: (context, controller) => Text(
                          '${controller.manualCounter}',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: controller.incrementManual,
                      icon: const Icon(Icons.touch_app),
                      label: const Text('Manual Increment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade100,
                        foregroundColor: Colors.amber.shade700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Enhanced info footer
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Complete Zenify Demo - All Features Included',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Try incrementing above 15 to see error handling\n'
                      '• Toggle auto-save to see debounced workers\n'
                      '• Watch performance metrics in debug mode\n'
                      '• Close and reopen app to test persistence',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Enhanced floating action button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.increment,
        tooltip: 'Quick Increment',
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
