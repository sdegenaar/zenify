// lib/zen_state/zen_dependency.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'zen_controller.dart';

/// Dependency injection container similar to Get.put/find
class Zen {
  Zen._(); // Private constructor

  static final ProviderContainer _container = ProviderContainer();
  static final Map<Type, ZenController> _controllers = {};

  // Similar to Get.put
  static T put<T extends ZenController>(T controller) {
    _controllers[T] = controller;
    return controller;
  }

  // Similar to Get.find
  static T find<T extends ZenController>() {
    if (!_controllers.containsKey(T)) {
      throw Exception('Controller of type $T not found. Call Zen.put() first.');
    }
    return _controllers[T] as T;
  }

  // Access the ProviderContainer for raw Riverpod usage
  static ProviderContainer get container => _container;
}