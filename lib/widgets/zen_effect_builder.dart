// lib/zenify/widgets/zen_effect_builder.dart
import 'package:flutter/material.dart';
import 'package:zenify/effects/zen_effects.dart';

/// A widget that responds to different states of a [ZenEffect].
///
/// This widget automatically rebuilds when the state of the provided effect changes,
/// showing the appropriate UI for each state (loading, success, error, or initial).
class ZenEffectBuilder<T> extends StatefulWidget {
  /// The effect to observe
  final ZenEffect<T> effect;

  /// Builder for the loading state
  final Widget Function() onLoading;

  /// Builder for the success state, provides the data
  final Widget Function(T data) onSuccess;

  /// Builder for the error state, provides the error
  final Widget Function(dynamic error) onError;

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
  @override
  void initState() {
    super.initState();
    // Subscribe to effect changes
    widget.effect.addListener(_onEffectChanged);
  }

  @override
  void didUpdateWidget(ZenEffectBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect != widget.effect) {
      oldWidget.effect.removeListener(_onEffectChanged);
      widget.effect.addListener(_onEffectChanged);
    }
  }

  @override
  void dispose() {
    widget.effect.removeListener(_onEffectChanged);
    super.dispose();
  }

  void _onEffectChanged() {
    if (mounted) {
      setState(() {
        // Force rebuild
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use local variables for clarity and to ensure proper invalidation
    final isLoading = widget.effect.isLoading.value;
    final hasError = widget.effect.hasError;
    final hasData = widget.effect.hasData;
    final data = widget.effect.data.value;

    Widget child;

    // Important: Use if-else pattern to ensure only one state is chosen
    if (isLoading) {
      child = widget.onLoading();
    } else if (hasError) {
      child = widget.onError(widget.effect.error.value);
    } else if (hasData) {
      // We need to cast to T, but handle the case where T is nullable
      child = widget.onSuccess(data as T);
    } else {
      // Initial state
      child = widget.onInitial != null
          ? widget.onInitial!()
          : const SizedBox.shrink(); // Empty widget if no initial builder
    }

    // Apply custom builder if provided
    if (widget.builder != null) {
      return widget.builder!(context, child);
    }

    return child;
  }
}