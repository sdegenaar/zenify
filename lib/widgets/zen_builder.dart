import 'package:flutter/material.dart';
import 'package:zenify/widgets/widgets.dart';
import '../controllers/zen_controller.dart';
import '../core/zen_scope.dart' show ZenScope;
import '../di/zen_di.dart';

/// A widget that automatically rebuilds when a [ZenController] calls update().
///
/// This widget is specifically designed to work with controllers that extend [ZenController].
/// For regular services, use [`context.service<T>()`] instead.
///
/// Example:
/// ```dart
/// ZenBuilder<MyController>(
///   builder: (context, controller) => Text('${controller.value}'),
///   tag: 'optional-tag',
///   create: () => MyController(), // Optional factory
/// )
/// ```
class ZenBuilder<T extends ZenController> extends StatefulWidget {
  /// Creates a widget that rebuilds when the controller updates.
  ///
  /// The [builder] function is called with the current [BuildContext] and controller instance.
  /// The [tag] parameter can be used to identify specific controller instances.
  /// The [id] parameter can be used to listen to specific update events.
  /// The [scope] parameter explicitly defines which scope to use for controller lookup.
  /// The [create] parameter provides a factory function for controller creation if not found.
  /// The [init] parameter allows initialization of newly created controllers.
  /// The [disposeOnRemove] parameter controls whether locally created controllers should be disposed.
  const ZenBuilder({
    required this.builder,
    this.tag,
    this.id,
    this.scope,
    this.create,
    this.init,
    this.disposeOnRemove = false,
    this.onError,
    super.key,
  }) : assert(disposeOnRemove == false || create != null,
            'disposeOnRemove requires create function');

  final Widget Function(BuildContext context, T controller) builder;
  final String? tag;
  final String? id;
  final ZenScope? scope;
  final T Function()? create;
  final void Function(T controller)? init;
  final bool disposeOnRemove;
  final Widget Function(Object error)? onError;

  @override
  State<ZenBuilder<T>> createState() => _ZenBuilderState<T>();
}

class _ZenBuilderState<T extends ZenController> extends State<ZenBuilder<T>> {
  late T _controller;
  bool _initialized = false;
  bool _locallyCreated = false;
  ZenScope? _effectiveScope;
  Object? _error;
  String? _instanceTag;

  @override
  void initState() {
    super.initState();

    // For disposeOnRemove, create a unique instance tag per widget instance
    if (widget.disposeOnRemove && widget.create != null) {
      _instanceTag = _generateInstanceTag();
    }
  }

  String _generateInstanceTag() {
    return '${widget.tag ?? T.toString()}_instance_${DateTime.now().microsecondsSinceEpoch}_$hashCode';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initializeController();
      _initialized = true;
    }
  }

  void _initializeController() {
    try {
      if (widget.disposeOnRemove && widget.create != null) {
        // Always create new instance for disposeOnRemove
        _createNewController();
      } else {
        // Try to find existing controller first
        final existingController = _findExistingController();
        if (existingController != null) {
          _controller = existingController;
          _registerUpdateListener();
        } else if (widget.create != null) {
          _createNewController();
        } else {
          throw StateError(
              'Controller of type $T not found and no create function provided');
        }
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  T? _findExistingController() {
    final lookupTag = widget.tag;
    return widget.scope?.find<T>(tag: lookupTag) ??
        context.zenScope?.find<T>(tag: lookupTag) ??
        Zen.findOrNull<T>(tag: lookupTag);
  }

  void _createNewController() {
    _controller = widget.create!();
    _locallyCreated = true;
    _registerController();
    _registerUpdateListener();

    if (widget.init != null) {
      widget.init!(_controller);
    }
  }

  void _registerController() {
    final scope = widget.scope ?? context.zenScope;
    final regTag = widget.disposeOnRemove ? _instanceTag : widget.tag;

    if (scope != null) {
      scope.put<T>(_controller, tag: regTag);
      _effectiveScope = scope;
    } else {
      Zen.put<T>(_controller, tag: regTag);
    }
  }

  void _registerUpdateListener() {
    final id = widget.id ?? '_all_';
    _controller.addUpdateListener(id, _onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _handleError(Object error, StackTrace? stack) {
    if (widget.onError != null) {
      _error = error;
      if (mounted) setState(() {});
    } else {
      throw error;
    }
  }

  @override
  void didUpdateWidget(ZenBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_shouldReinitialize(oldWidget)) {
      _cleanup();
      _initialized = false;

      if (widget.disposeOnRemove && widget.create != null) {
        _instanceTag = _generateInstanceTag();
      }

      _initializeController();
    }
  }

  bool _shouldReinitialize(ZenBuilder<T> oldWidget) {
    return oldWidget.tag != widget.tag ||
        oldWidget.scope != widget.scope ||
        oldWidget.create != widget.create ||
        oldWidget.disposeOnRemove != widget.disposeOnRemove;
  }

  void _cleanup() {
    if (_error != null || !_initialized) return;

    try {
      final id = widget.id ?? '_all_';
      _controller.removeUpdateListener(id, _onControllerUpdate);

      if (_locallyCreated && widget.disposeOnRemove) {
        _disposeController();
      }
    } catch (e) {
      // Log but don't throw in cleanup
      debugPrint('ZenBuilder: Error during cleanup: $e');
    }
  }

  void _disposeController() {
    final disposeTag = widget.disposeOnRemove ? _instanceTag : widget.tag;

    if (_effectiveScope != null) {
      _effectiveScope!.delete<T>(tag: disposeTag, force: true);
    } else {
      Zen.delete<T>(tag: disposeTag, force: true);
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.onError?.call(_error!) ?? _buildErrorWidget(_error!);
    }

    try {
      return widget.builder(context, _controller);
    } catch (e) {
      return widget.onError?.call(e) ?? _buildErrorWidget(e);
    }
  }

  Widget _buildErrorWidget(Object error) {
    return Material(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(height: 8),
            const Text('Controller Error',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              error.toString(),
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
