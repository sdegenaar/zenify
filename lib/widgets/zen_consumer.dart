import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

/// Widget that efficiently accesses dependencies from the current scope
/// with automatic caching to avoid repeated lookups on rebuilds
class ZenConsumer<T> extends StatefulWidget {
  final Widget Function(T? dependency) builder;
  final String? tag;

  const ZenConsumer({
    super.key,
    required this.builder,
    this.tag,
  });

  @override
  State<ZenConsumer<T>> createState() => _ZenConsumerState<T>();
}

class _ZenConsumerState<T> extends State<ZenConsumer<T>> {
  T? dependency;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _findDependency();
  }

  @override
  void didUpdateWidget(ZenConsumer<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Re-search if tag changed
    if (oldWidget.tag != widget.tag) {
      _findDependency();
    }
  }

  void _findDependency() {
    try {
      // Use Zen.findOrNull for hierarchical search
      dependency = Zen.findOrNull<T>(tag: widget.tag);
    } catch (e) {
      // Log error but don't throw - allow graceful degradation
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logError('ZenConsumer failed to find dependency $T: $e');
      }
      dependency = null;
    }
    _hasSearched = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasSearched) {
      return const SizedBox.shrink(); // Or loading indicator
    }

    return widget.builder(dependency);
  }
}
