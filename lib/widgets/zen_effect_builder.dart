// lib/widgets/zen_effect_builder.dart
import 'package:flutter/material.dart';
import '../effects/zen_effects.dart';

/// A widget that responds to different states of a [ZenEffect].
///
/// This widget automatically rebuilds when the state of the provided effect changes,
/// showing the appropriate UI for each state (loading, success, error, or initial).
///
/// Optimized for production with reduced rebuilds and better performance.
class ZenEffectBuilder<T> extends StatefulWidget {
  /// The effect to observe
  final ZenEffect<T> effect;

  /// Builder for the loading state
  final Widget Function() onLoading;

  /// Builder for the success state, provides the data
  final Widget Function(T data) onSuccess;

  /// Builder for the error state, provides the error
  final Widget Function(Object error) onError;

  /// Builder for the initial state (optional)
  final Widget Function()? onInitial;

  /// Optional custom builder that wraps the state-specific widgets
  final Widget Function(BuildContext context, Widget child)? builder;

  const ZenEffectBuilder({
    super.key,
    required this.effect,
    required this.onLoading,
    required this.onSuccess,
    required this.onError,
    this.onInitial,
    this.builder,
  });

  @override
  State<ZenEffectBuilder<T>> createState() => _ZenEffectBuilderState<T>();
}

class _ZenEffectBuilderState<T> extends State<ZenEffectBuilder<T>> {
  // Cache the current state to avoid unnecessary rebuilds
  late bool _isLoading;
  late Object? _error;
  late T? _data;
  late bool _dataWasSet;

  @override
  void initState() {
    super.initState();
    _updateCachedState();
    _subscribeToEffect();
  }

  @override
  void didUpdateWidget(ZenEffectBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect != widget.effect) {
      _unsubscribeFromEffect(oldWidget.effect);
      _updateCachedState();
      _subscribeToEffect();
    }
  }

  @override
  void dispose() {
    _unsubscribeFromEffect(widget.effect);
    super.dispose();
  }

  void _updateCachedState() {
    _isLoading = widget.effect.isLoading.value;
    _error = widget.effect.error.value;
    _data = widget.effect.data.value;
    _dataWasSet = widget.effect.dataWasSet.value;
  }

  void _onEffectChange() {
    if (!mounted || widget.effect.isDisposed) return;

    // Check if state actually changed before triggering rebuild
    final newIsLoading = widget.effect.isLoading.value;
    final newError = widget.effect.error.value;
    final newData = widget.effect.data.value;
    final newDataWasSet = widget.effect.dataWasSet.value;

    if (_isLoading != newIsLoading ||
        _error != newError ||
        _data != newData ||
        _dataWasSet != newDataWasSet) {
      setState(() {
        _isLoading = newIsLoading;
        _error = newError;
        _data = newData;
        _dataWasSet = newDataWasSet;
      });
    }
  }

  void _subscribeToEffect() {
    if (widget.effect.isDisposed) return;

    // Subscribe to all the ValueNotifier properties directly
    widget.effect.isLoading.addListener(_onEffectChange);
    widget.effect.error.addListener(_onEffectChange);
    widget.effect.data.addListener(_onEffectChange);
    widget.effect.dataWasSet.addListener(_onEffectChange);
  }

  void _unsubscribeFromEffect(ZenEffect<T> effect) {
    if (effect.isDisposed) return;

    // Remove listeners from all ValueNotifier properties
    effect.isLoading.removeListener(_onEffectChange);
    effect.error.removeListener(_onEffectChange);
    effect.data.removeListener(_onEffectChange);
    effect.dataWasSet.removeListener(_onEffectChange);
  }

  @override
  Widget build(BuildContext context) {
    // Handle disposed effect case
    if (widget.effect.isDisposed) {
      return widget.onInitial?.call() ?? const SizedBox.shrink();
    }

    Widget child;

    // State logic with clear priority: loading > error > success > initial
    if (_isLoading) {
      child = widget.onLoading();
    } else if (_error != null) {
      child = widget.onError(_error!);
    } else if (_dataWasSet) {
      // Use dataWasSet flag to handle null data correctly
      child = widget.onSuccess(_data as T);
    } else {
      // Initial state
      child = widget.onInitial?.call() ?? const SizedBox.shrink();
    }

    // Apply custom builder if provided
    if (widget.builder != null) {
      return widget.builder!(context, child);
    }

    return child;
  }
}