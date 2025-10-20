import 'package:zenify/zenify.dart';

class WorkerDemoController extends ZenController {
  // Observable values
  final RxInt counter = 0.obs();
  final RxString message = 'Hello Workers!'.obs();
  final RxList<String> items = <String>[].obs();

  // Worker counters
  final RxInt everCount = 0.obs();
  final RxInt debounceCount = 0.obs();
  final RxInt throttleCount = 0.obs();
  final RxInt onceCount = 0.obs();
  final RxInt conditionCount = 0.obs();
  final RxInt intervalCount = 0.obs();
  final RxInt stringWorkerCount = 0.obs();
  final RxInt listWorkerCount = 0.obs();

  // Worker handles for lifecycle management
  late final ZenWorkerHandle _everHandle;
  late final ZenWorkerHandle _debounceHandle;
  late final ZenWorkerHandle _throttleHandle;
  late final ZenWorkerHandle _onceHandle;
  late final ZenWorkerHandle _conditionHandle;
  late final ZenWorkerHandle _intervalHandle;
  late final ZenWorkerHandle _stringHandle;
  late final ZenWorkerHandle _listHandle;

  final List<String> _messageOptions = [
    'Hello Workers!',
    'Reactive Programming',
    'Zenify is Awesome',
    'Flutter State Management',
    'Observables in Action',
  ];

  @override
  void onInit() {
    super.onInit();
    _setupWorkers();

    // Initialize with some items
    items.addAll(['Initial Item 1', 'Initial Item 2']);

    ZenLogger.logDebug('WorkerDemoController initialized with workers');
  }

  void _setupWorkers() {
    // Ever worker - fires on every change
    _everHandle = ever(counter, (value) {
      everCount.value++;
      ZenLogger.logDebug('Ever worker fired: counter = $value');
    });

    // Debounce worker - waits for inactivity
    _debounceHandle = debounce(
      counter,
      (value) {
        debounceCount.value++;
        ZenLogger.logDebug('Debounce worker fired: counter = $value');
      },
      const Duration(milliseconds: 500),
    );

    // Throttle worker - limits frequency
    _throttleHandle = throttle(
      counter,
      (value) {
        throttleCount.value++;
        ZenLogger.logDebug('Throttle worker fired: counter = $value');
      },
      const Duration(milliseconds: 1000),
    );

    // Once worker - fires only once
    _onceHandle = once(counter, (value) {
      onceCount.value++;
      ZenLogger.logDebug(
          'Once worker fired: counter = $value (will not fire again)');
    });

    // Condition worker - fires only when condition is met
    _conditionHandle = condition(
      counter,
      (value) => value.isEven, // Only fire when counter is even
      (value) {
        conditionCount.value++;
        ZenLogger.logDebug(
            'Condition worker fired: counter = $value (even number)');
      },
    );

    // Interval worker - fires periodically
    _intervalHandle = interval(
      counter,
      (value) {
        intervalCount.value++;
        ZenLogger.logDebug('Interval worker fired: counter = $value');
      },
      const Duration(milliseconds: 2000),
    );

    // String worker
    _stringHandle = ever(message, (value) {
      stringWorkerCount.value++;
      ZenLogger.logDebug('String worker fired: message = "$value"');
    });

    // List worker
    _listHandle = ever(items, (list) {
      listWorkerCount.value++;
      ZenLogger.logDebug('List worker fired: ${list.length} items');
    });
  }

  // Counter operations
  void incrementCounter() {
    counter.value++;
  }

  void decrementCounter() {
    counter.value--;
  }

  void resetCounter() {
    counter.value = 0;
  }

  void rapidIncrement() {
    // Rapid fire increments to demonstrate worker differences
    for (int i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (!isDisposed) {
          incrementCounter();
        }
      });
    }
  }

  // Message operations
  void updateMessage() {
    final currentIndex = _messageOptions.indexOf(message.value);
    final nextIndex = (currentIndex + 1) % _messageOptions.length;
    message.value = _messageOptions[nextIndex];
  }

  void clearMessage() {
    message.value = '';
  }

  // List operations
  void addItem() {
    final itemNumber = items.length + 1;
    items.add('Item $itemNumber - ${DateTime.now().millisecond}');
  }

  void removeItem(String item) {
    items.remove(item);
  }

  void clearItems() {
    items.clear();
  }

  // Worker management
  void resetAllCounters() {
    everCount.value = 0;
    debounceCount.value = 0;
    throttleCount.value = 0;
    onceCount.value = 0;
    conditionCount.value = 0;
    intervalCount.value = 0;
    stringWorkerCount.value = 0;
    listWorkerCount.value = 0;
  }

  // Worker status information
  bool get hasActiveWorkers {
    return !_everHandle.isDisposed &&
        !_debounceHandle.isDisposed &&
        !_throttleHandle.isDisposed &&
        !_conditionHandle.isDisposed &&
        !_intervalHandle.isDisposed &&
        !_stringHandle.isDisposed &&
        !_listHandle.isDisposed;
  }

  // Demo actions
  void demonstrateWorkerTypes() {
    // This will trigger various workers
    rapidIncrement();
    updateMessage();
    addItem();
  }

  @override
  void onClose() {
    // Dispose all workers
    _everHandle.dispose();
    _debounceHandle.dispose();
    _throttleHandle.dispose();
    _onceHandle.dispose();
    _conditionHandle.dispose();
    _intervalHandle.dispose();
    _stringHandle.dispose();
    _listHandle.dispose();

    ZenLogger.logDebug('WorkerDemoController disposed with all workers');
    super.onClose();
  }
}
