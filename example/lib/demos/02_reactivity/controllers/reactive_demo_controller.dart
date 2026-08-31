import 'package:zenify/zenify.dart';

class ReactiveDemoController extends ZenController {
  // Basic reactive values
  final RxInt counter = 0.obs();
  final RxInt counterRebuilds = 0.obs();
  final RxString message = 'Hello Zenify!'.obs();
  final RxInt messageRebuilds = 0.obs();

  // Complex reactive state
  final RxList<String> items = <String>[].obs();
  final RxInt itemsRebuilds = 0.obs();
  final RxBool featureA = false.obs();
  final RxBool featureB = false.obs();
  final RxInt featuresRebuilds = 0.obs();

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

    // Set up reactive workers to track rebuild counts
    ever(counter, (value) {
      counterRebuilds.value++;
      ZenLogger.logDebug('Counter changed to: $value');
    });

    ever(message, (_) {
      messageRebuilds.value++;
    });

    ever(items, (list) {
      itemsRebuilds.value++;
      ZenLogger.logDebug('Items list changed, now has ${list.length} items');
    });

    ever(featureA, (_) => featuresRebuilds.value++);
    ever(featureB, (_) => featuresRebuilds.value++);
  }

  void resetRebuildCounters() {
    counterRebuilds.value = 0;
    messageRebuilds.value = 0;
    itemsRebuilds.value = 0;
    featuresRebuilds.value = 0;
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
    ZenLogger.logDebug('ReactiveDemoController disposed');
    super.onClose();
  }
}
