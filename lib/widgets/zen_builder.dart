import 'package:flutter/material.dart';
import '../controllers/zen_controller.dart';

/// A widget that rebuilds only when [ZenController.update] is called with the specified ID
class ZenBuilder<T extends ZenController> extends StatefulWidget {
  /// The builder function that creates the widget
  final Widget Function(T controller) builder;

  /// Optional tag for the controller
  final String? tag;

  /// Optional ID for targeted updates
  final String? id;

  /// Whether to find or create the controller if not found
  final bool autoCreate;

  /// Optional factory to create the controller if not found and autoCreate is true
  final T Function()? create;

  /// Whether the controller should be disposed when this widget is disposed
  final bool disposeController;

  const ZenBuilder({
    required this.builder,
    this.tag,
    this.id,
    this.autoCreate = false,
    this.create,
    this.disposeController = false,
    super.key,
  });

  @override
  State<ZenBuilder<T>> createState() => _ZenBuilderState<T>();
}

class _ZenBuilderState<T extends ZenController> extends State<ZenBuilder<T>> {
  late T controller;
  bool _initialized = false;
  final String _builderId = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.autoCreate) {
      try {
        controller = Zen.find<T>(tag: widget.tag) ??
            (widget.create != null ? widget.create!() :
            Zen.get<T>(tag: widget.tag));
      } catch (e) {
        if (widget.create != null) {
          controller = Zen.put<T>(widget.create!(), tag: widget.tag);
        } else {
          rethrow;
        }
      }
    } else {
      controller = Zen.find<T>(tag: widget.tag) ??
          (throw Exception('Controller not found. Set autoCreate to true or provide a create function.'));
    }

    // Register for updates using the specified ID or a builder-specific one
    final updateId = widget.id ?? _builderId;
    controller.addUpdateListener(updateId, _onUpdate);
    _initialized = true;
  }

  void _onUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(ZenBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle tag changes
    if (oldWidget.tag != widget.tag) {
      // Unregister from old controller
      final oldUpdateId = oldWidget.id ?? _builderId;
      controller.removeUpdateListener(oldUpdateId, _onUpdate);

      // Get new controller and register
      _initController();
    }
    // Handle ID changes
    else if (oldWidget.id != widget.id && _initialized) {
      final oldUpdateId = oldWidget.id ?? _builderId;
      final newUpdateId = widget.id ?? _builderId;

      controller.removeUpdateListener(oldUpdateId, _onUpdate);
      controller.addUpdateListener(newUpdateId, _onUpdate);
    }
  }

  @override
  void dispose() {
    final updateId = widget.id ?? _builderId;
    controller.removeUpdateListener(updateId, _onUpdate);

    if (widget.disposeController) {
      Zen.delete<T>(tag: widget.tag);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(controller);
  }
}