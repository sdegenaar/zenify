import 'package:zenify/zenify.dart';

/// Controller specifically for demonstrating ZenBuilder functionality
/// Uses plain values + update() instead of reactive observables
class ZenBuilderDemoController extends ZenController {
  // Plain values (no .obs())
  int _counter = 0;
  String _message = 'Hello ZenBuilder!';
  final List<String> _items = [];
  bool _featureA = false;
  bool _featureB = false;

  // Getters for accessing values
  int get counter => _counter;
  String get message => _message;
  List<String> get items => List.unmodifiable(_items);
  bool get featureA => _featureA;
  bool get featureB => _featureB;

  // Computed properties
  bool get bothFeaturesEnabled => _featureA && _featureB;
  int get itemCount => _items.length;

  final List<String> _messages = [
    'Hello ZenBuilder!',
    'Manual State Management!',
    'Flutter + Zenify = ❤️',
    'Building with update() calls',
    'ZenBuilder rocks!',
  ];

  @override
  void onInit() {
    super.onInit();

    // Initialize with some items
    _items.addAll(['Initial Item 1', 'Initial Item 2']);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('ZenBuilderDemoController initialized');
    }
  }

  // Counter methods
  void increment() {
    _counter++;
    update(); // Manual UI update trigger

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Counter incremented to: $_counter');
    }
  }

  void decrement() {
    _counter--;
    update(); // Manual UI update trigger

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Counter decremented to: $_counter');
    }
  }

  void reset() {
    _counter = 0;
    update(); // Manual UI update trigger

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Counter reset to: $_counter');
    }
  }

  // Message methods
  void updateMessage() {
    final currentIndex = _messages.indexOf(_message);
    final nextIndex = (currentIndex + 1) % _messages.length;
    _message = _messages[nextIndex];
    update(); // Manual UI update trigger

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Message updated to: $_message');
    }
  }

  void setMessage(String newMessage) {
    _message = newMessage;
    update(); // Manual UI update trigger
  }

  // List methods
  void addItem() {
    final itemNumber = _items.length + 1;
    final newItem = 'Item $itemNumber - ${DateTime.now().millisecond}';
    _items.add(newItem);
    update(); // Manual UI update trigger

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Item added: $newItem, total items: ${_items.length}');
    }
  }

  void removeItem(String item) {
    final removed = _items.remove(item);
    if (removed) {
      update(); // Manual UI update trigger

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Item removed: $item, remaining items: ${_items.length}');
      }
    }
  }

  void clearItems() {
    _items.clear();
    update(); // Manual UI update trigger

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('All items cleared');
    }
  }

  // Feature toggle methods
  void toggleFeatureA() {
    _featureA = !_featureA;
    update(); // Manual UI update trigger

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Feature A toggled to: $_featureA');
    }
  }

  void toggleFeatureB() {
    _featureB = !_featureB;
    update(); // Manual UI update trigger

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Feature B toggled to: $_featureB');
    }
  }

  void setBothFeatures(bool value) {
    _featureA = value;
    _featureB = value;
    update(); // Manual UI update trigger

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Both features set to: $value');
    }
  }

  // Demonstration of selective updates
  void updateOnlyCounter() {
    _counter++;
    update(['counter']); // Only update widgets listening to 'counter' ID

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Counter updated selectively to: $_counter');
    }
  }

  void updateOnlyMessage() {
    updateMessage();
    // We can override the update call in updateMessage for selective updates
    // But for simplicity, we'll use the general update() call
  }

  // Batch update example
  void incrementAndUpdateMessage() {
    _counter++;
    final currentIndex = _messages.indexOf(_message);
    final nextIndex = (currentIndex + 1) % _messages.length;
    _message = _messages[nextIndex];

    // Single update call for multiple state changes
    update();

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Batch update: counter=$_counter, message=$_message');
    }
  }

  // Reset all state
  void resetAll() {
    _counter = 0;
    _message = _messages.first;
    _items.clear();
    _featureA = false;
    _featureB = false;

    update(); // Single update for all changes

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('All state reset');
    }
  }

  @override
  void onDispose() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('ZenBuilderDemoController disposed');
    }
    super.onDispose();
  }
}