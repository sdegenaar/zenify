import 'package:zenify/zenify.dart';

class ReactiveDemoController extends ZenController {
  // Basic reactive values
  final RxInt counter = 0.obs();
  final RxString message = 'Hello Zenify!'.obs();

  // Complex reactive state
  final RxList<String> items = <String>[].obs();
  final RxBool featureA = false.obs();
  final RxBool featureB = false.obs();

  // Computed properties
  bool get bothFeaturesEnabled => featureA.value && featureB.value;

  final List<String> _messages = [
    'Hello Zenify!',
    'Reactive State is Amazing!',
    'Flutter + Zenify = ❤️',
    'Building with reactive patterns',
    'State management made simple',
  ];

  @override
  void onInit() {
    super.onInit();

    // Initialize with some items
    items.addAll(['Initial Item 1', 'Initial Item 2']);

    // Set up some reactive workers for demonstration
    ever(counter, (value) {
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Counter changed to: $value');
      }
    });

    ever(items, (list) {
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Items list changed, now has ${list.length} items');
      }
    });
  }

  // Counter methods
  void increment() => counter.value++;
  void decrement() => counter.value--;
  void reset() => counter.value = 0;

  // Message methods
  void updateMessage() {
    final currentIndex = _messages.indexOf(message.value);
    final nextIndex = (currentIndex + 1) % _messages.length;
    message.value = _messages[nextIndex];
  }

  // List methods
  void addItem() {
    final itemNumber = items.length + 1;
    items.add('New Item $itemNumber - ${DateTime.now().millisecond}');
  }

  void removeItem(String item) {
    items.remove(item);
  }

  void clearItems() {
    items.clear();
  }

  @override
  void onClose() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('ReactiveDemoController disposed');
    }
    super.onClose();
  }
}
