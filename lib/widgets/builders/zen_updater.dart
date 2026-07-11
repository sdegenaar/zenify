import 'package:flutter/widgets.dart';
import '../../controllers/zen_controller.dart';
import '../components/zen_view.dart'; // for context.controller<T>()

/// A widget that rebuilds when its controller calls [ZenController.update].
///
/// Resolves the controller via the widget tree (`context.controller<T>()` —
/// nearest [ZenScopeWidget] first, then global DI). Completely multi-instance
/// safe: each [ZenUpdater] independently resolves from its own tree position.
///
/// ## Fail-fast
///
/// If the controller is not found and no [onError] handler is provided, the
/// exception propagates through Flutter's error handling. Provide [onError]
/// to show a fallback widget instead.
///
/// ## Selective rebuilds
///
/// Use [id] to register for selective updates:
/// ```dart
/// // Controller side:
/// controller.update(['counter']); // Only notifies listeners with id='counter'
///
/// // Widget side:
/// ZenUpdater<CounterController>(
///   id: 'counter',
///   builder: (context, ctrl) => Text('${ctrl.count}'),
/// )
/// ```
class ZenUpdater<T extends ZenController> extends StatefulWidget {
  /// Builder function that receives the resolved controller.
  final Widget Function(BuildContext context, T controller) builder;

  /// Optional tag for finding the controller (disambiguates multiple instances).
  final String? tag;

  /// Optional update ID for selective rebuilds. When set, this widget only
  /// rebuilds when [ZenController.update] is called with a matching ID.
  final String? id;

  /// Optional error handler. When provided, renders this widget if the
  /// controller cannot be found or if the builder throws. When not provided,
  /// the error propagates to Flutter's error handling system.
  final Widget Function(Object error)? onError;

  const ZenUpdater({
    super.key,
    required this.builder,
    this.tag,
    this.id,
    this.onError,
  });

  @override
  State<ZenUpdater<T>> createState() => _ZenUpdaterState<T>();
}

class _ZenUpdaterState<T extends ZenController> extends State<ZenUpdater<T>> {
  T? _controller;
  Object? _resolutionError; // Captured when controller lookup fails
  String? _listenerId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always re-resolve — the nearest scope may have changed (e.g., after
    // navigation or a scope widget rebuild). Only re-subscribe if the
    // controller identity actually changed to avoid redundant listener churn.
    _resolveController();
  }

  // coverage:ignore-start
  @override
  void didUpdateWidget(ZenUpdater<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag || oldWidget.id != widget.id) {
      _detachListener();
      _resolveController();
    }
  }
  // coverage:ignore-end

  void _resolveController() {
    try {
      final newController = context.controller<T>(tag: widget.tag);
      if (identical(newController, _controller)) return; // Nothing changed.

      _detachListener();
      _controller = newController;
      _resolutionError = null;
      _listenerId = widget.id ?? '_zen_updater_$hashCode';
      _controller!.addUpdateListener(_listenerId!, _onControllerUpdate);
    } catch (e) {
      // Store the error so build() can route it to onError or rethrow.
      _controller = null;
      _resolutionError = e;
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _detachListener() {
    if (_controller != null && _listenerId != null) {
      _controller!.removeUpdateListener(_listenerId!, _onControllerUpdate);
      _controller = null;
      _listenerId = null;
    }
  }

  @override
  void dispose() {
    _detachListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Route any resolution error: onError handler wins; otherwise rethrow
    // so Flutter's error handling surfaces it. No silent blank widgets.
    if (_resolutionError != null) {
      if (widget.onError != null) return widget.onError!(_resolutionError!);
      throw _resolutionError!;
    }

    assert(_controller != null);

    try {
      return widget.builder(context, _controller!);
    } catch (e) {
      if (widget.onError != null) return widget.onError!(e);
      rethrow; // Let Flutter's error handling surface it — no silent failures.
    }
  }
}
