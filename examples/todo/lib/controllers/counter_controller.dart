import 'package:zenify/zenify.dart';

class CounterController extends ZenController {
  // Create an observable for the counter
  final counter = Rx<int>(0);

  void increment() {
    // Properly update the counter value
    counter.value++;
    _logCounterChange();
  }

  void decrement() {
    counter.value--;
    _logCounterChange();
  }

  void reset() {
    counter.value = 0;
    _logCounterChange('Counter reset to zero');
  }

  void _logCounterChange([String? customMessage]) {
    ZenLogger.logInfo('Counter changed to: ${counter.value}');

    if (customMessage != null) {
      ZenLogger.logInfo(customMessage);
    } else if (counter.value % 5 == 0 && counter.value != 0) {
      ZenLogger.logInfo('🎉 Hooray! You reached a multiple of 5!');
    }
  }

  @override
  void onDispose() {
    // Clean up any resources if needed
    super.onDispose();
  }
}