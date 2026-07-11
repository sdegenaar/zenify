import 'package:flutter/material.dart';
import '../../controllers/zen_controller.dart';
import '../components/zen_view.dart';

/// Widget that provides a [ZenController] to a subtree via composition.
///
/// Resolves the controller from the nearest [ZenScopeWidget] ancestor, with
/// a fallback to global DI (`Zen.put()`). Fails fast — throws a clear error
/// if the controller is not found, rather than rendering nothing silently.
///
/// ## Reactivity
///
/// [ZenConsumer] is NOT reactive by itself. It resolves the controller once
/// and provides it to the [builder]. For reactive rebuilds, use [ZenObserver]
/// (for `Rx<T>` values) or [ZenUpdater] (for `controller.update()` calls)
/// inside the builder:
///
/// ```dart
/// ZenConsumer<CartController>(
///   builder: (context, controller) => ZenObserver(
///     () => Text('\${controller.totalPrice.value}'),
///   ),
/// )
/// ```
///
/// ## Multi-Instance Safety
///
/// Because resolution uses [context.controller<T>()], this widget is fully
/// safe with multiple simultaneous instances — each resolves from its own
/// nearest scope.
class ZenConsumer<T extends ZenController> extends StatefulWidget {
  final Widget Function(BuildContext context, T dependency) builder;
  final String? tag;

  const ZenConsumer({
    super.key,
    required this.builder,
    this.tag,
  });

  @override
  State<ZenConsumer<T>> createState() => _ZenConsumerState<T>();
}

class _ZenConsumerState<T extends ZenController> extends State<ZenConsumer<T>> {
  T? _dependency;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolves via scope → global DI. Throws ZenControllerNotFoundException if not found.
    // This is intentional: fail fast with a clear error beats silent blank widget.
    _dependency = context.controller<T>(tag: widget.tag);
  }

  // coverage:ignore-start
  @override
  void didUpdateWidget(ZenConsumer<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) {
      _dependency = context.controller<T>(tag: widget.tag);
    }
  }
  // coverage:ignore-end

  @override
  Widget build(BuildContext context) {
    // If _dependency is null here, didChangeDependencies threw before we
    // could assign it. That error is already propagating through Flutter's
    // error handling — return a shrink so the framework can report it cleanly.
    // In normal operation this branch is never reached.
    assert(
      _dependency != null,
      'ZenConsumer<$T>: controller not found. '
      'Ensure ZenScopeWidget.create<$T>() or Zen.put<$T>() exists above this widget.',
    );
    if (_dependency == null) return const SizedBox.shrink();
    return widget.builder(context, _dependency!);
  }
}
