import 'package:flutter/material.dart';
import '../controllers/zen_controller.dart';
import '../controllers/zen_di.dart';
import '../core/zen_scope.dart';

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

  /// Optional function to specify which scope to use for finding the controller
  final ZenScope Function()? findScopeFn;

  /// Whether the controller should be disposed when this widget is disposed
  final bool disposeController;

  const ZenBuilder({
    required this.builder,
    this.tag,
    this.id,
    this.autoCreate = false,
    this.create,
    this.findScopeFn,
    this.disposeController = false,
    super.key,
  });

  @override
  State<ZenBuilder<T>> createState() => _ZenBuilderState<T>();
}

class _ZenBuilderState<T extends ZenController> extends State<ZenBuilder<T>> {
  T? _controller;
  bool _initialized = false;
  final String _builderId = UniqueKey().toString();
  String? _currentId;

  @override
  void initState() {
    super.initState();
    try {
      _initController();
    } catch (e) {
      // We catch the exception here but rethrow to allow proper error propagation
      rethrow;
    }
  }

  void _initController() {
    // Determine which scope to use
    final scope = widget.findScopeFn?.call();

    // First, try to find an existing controller
    final foundController = Zen.find<T>(tag: widget.tag, scope: scope);

    if (foundController != null) {
      // If a controller is found, use it
      _controller = foundController;
      _initialized = true;
    } else if (widget.autoCreate) {
      // If autoCreate is true, create a new controller
      if (widget.create != null) {
        _controller = Zen.put<T>(widget.create!(), tag: widget.tag, scope: scope);
        _initialized = true;
      } else {
        // Try to get with Zen.get which might use a registered factory
        try {
          _controller = Zen.get<T>(tag: widget.tag, scope: scope);
          _initialized = true;
        } catch (e) {
          throw Exception('No controller found and no create function provided. Set autoCreate to true and provide a create function.');
        }
      }
    } else {
      // If controller not found and autoCreate is false, throw exception
      throw Exception('Controller not found. Set autoCreate to true or provide a create function.');
    }

    // Store the current ID for future reference
    _currentId = widget.id ?? _builderId;

    // Register for updates if we have a controller
    if (_controller != null) {
      _controller!.addUpdateListener(_currentId!, _onUpdate);
    }
  }

  void _onUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(ZenBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle tag changes or scope changes by reinitializing
    if (oldWidget.tag != widget.tag || oldWidget.findScopeFn != widget.findScopeFn) {
      // Unregister from old controller first
      if (_initialized && _currentId != null && _controller != null) {
        _controller!.removeUpdateListener(_currentId!, _onUpdate);
      }

      // Reset initialization flag
      _initialized = false;

      // Reinitialize controller
      try {
        _initController();
      } catch (e) {
        // Allow error to propagate
        rethrow;
      }
      return;
    }

    // Handle ID changes
    if (oldWidget.id != widget.id && _initialized && _controller != null) {
      final newId = widget.id ?? _builderId;

      // Important: First register with new ID, then remove old one to avoid missing updates
      _controller!.addUpdateListener(newId, _onUpdate);

      if (_currentId != null) {
        _controller!.removeUpdateListener(_currentId!, _onUpdate);
      }

      // Update current ID
      _currentId = newId;
    }
  }

  @override
  void dispose() {
    if (_initialized && _currentId != null && _controller != null) {
      _controller!.removeUpdateListener(_currentId!, _onUpdate);

      if (widget.disposeController) {
        // Get the scope to use
        final scope = widget.findScopeFn?.call();
        Zen.delete<T>(tag: widget.tag, scope: scope);
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return const SizedBox(); // Return empty widget if controller not initialized
    }
    return widget.builder(_controller!);
  }
}