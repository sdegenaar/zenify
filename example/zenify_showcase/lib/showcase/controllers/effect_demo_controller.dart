import 'package:zenify/zenify.dart';
import '../../shared/services/demo_service.dart';

class EffectDemoController extends ZenController {
  // Use nullable for safe initialization
  late DemoService _demoService;

  // Different effects for various demonstrations
  late final basicEffect = createEffect<String>(name: 'basic');
  late final dataEffect = createEffect<List<String>>(name: 'data');
  late final effect1 = createEffect<String>(name: 'effect1');
  late final effect2 = createEffect<String>(name: 'effect2');
  late final effect3 = createEffect<String>(name: 'effect3');

  @override
  void onInit() {
    super.onInit();

    // Now it's safe to access the service - module is fully initialized
    _demoService = Zen.find<DemoService>();

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('EffectDemoController initialized');
    }
  }

  // Updated methods to use the getter
  Future<void> runBasicEffect() async {
    await basicEffect.run(() async {
      final result =
          await _demoService.fetchData(delay: const Duration(seconds: 2));
      return result;
    });
  }

  Future<void> runBasicEffectWithError() async {
    await basicEffect.run(() async {
      await Future.delayed(const Duration(seconds: 1));
      throw Exception('Simulated error occurred');
    });
  }

  Future<void> fetchData() async {
    await dataEffect.run(() async {
      return await _demoService.fetchItems();
    });
  }

  Future<void> fetchDataWithError() async {
    await dataEffect.run(() async {
      return await _demoService.fetchItems(shouldFail: true);
    });
  }

  Future<void> runEffect1() async {
    await effect1.run(() async {
      await Future.delayed(const Duration(milliseconds: 1000));
      return 'Result 1';
    });
  }

  Future<void> runEffect2() async {
    await effect2.run(() async {
      await Future.delayed(const Duration(milliseconds: 1500));
      return 'Result 2';
    });
  }

  Future<void> runEffect3() async {
    await effect3.run(() async {
      await Future.delayed(const Duration(milliseconds: 800));
      return 'Result 3';
    });
  }

  Future<void> runAllEffects() async {
    // Run all effects concurrently
    await Future.wait([
      runEffect1(),
      runEffect2(),
      runEffect3(),
    ]);
  }

  void resetAllEffects() {
    basicEffect.reset();
    dataEffect.reset();
    effect1.reset();
    effect2.reset();
    effect3.reset();
  }

  @override
  void onClose() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('EffectDemoController disposed');
    }
    super.onClose();
  }
}
