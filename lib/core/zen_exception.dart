// lib/core/zen_exception.dart
import 'zen_config.dart';

/// Base exception for all Zenify errors with smart formatting
///
/// By default, exceptions use a compact single-line format.
/// Enable verbose mode with `ZenConfig.verboseErrors = true` for detailed box formatting.
abstract class ZenException implements Exception {
  /// Human-readable error message
  final String message;

  /// Optional context (e.g., type name, scope name)
  final Map<String, String>? context;

  /// Optional suggestion for fixing the error
  final String? suggestion;

  /// Optional documentation link
  final String? docLink;

  /// Original error that caused this exception (if any)
  final Object? cause;

  /// Stack trace of the original error
  final StackTrace? causeStackTrace;

  const ZenException(
    this.message, {
    this.context,
    this.suggestion,
    this.docLink,
    this.cause,
    this.causeStackTrace,
  });

  /// Icon/emoji for this error type
  String get icon;

  /// Error category (for filtering/grouping)
  String get category;

  @override
  String toString() {
    // Use verbose formatting if enabled in config
    return ZenConfig.verboseErrors ? _toStringVerbose() : _toStringCompact();
  }

  /// Compact single-line format (default)
  ///
  /// Example:
  /// ```
  /// ❌ ZenDependencyNotFoundException: Dependency not found (Type=UserService, Scope=RootScope)
  ///    💡 Zen.put(UserService());
  /// ```
  String _toStringCompact() {
    final buffer = StringBuffer();

    // Main error line
    buffer.write('$icon $runtimeType: $message');

    // Context in parentheses
    if (context != null && context!.isNotEmpty) {
      final contextStr =
          context!.entries.map((e) => '${e.key}=${e.value}').join(', ');
      buffer.write(' ($contextStr)');
    }

    // Suggestion on new line with indent
    if (suggestion != null) {
      buffer.write('\n   💡 $suggestion');
    }

    // Doc link on new line
    if (docLink != null) {
      buffer.write('\n   📚 $docLink');
    }

    // Cause (if present)
    if (cause != null) {
      buffer.write('\n   Caused by: ${cause.runtimeType}: $cause');
    }

    return buffer.toString();
  }

  /// Verbose boxed format (opt-in via ZenConfig.verboseErrors)
  ///
  /// Example:
  /// ```
  /// ╔══════════════════════════════════════════════════════════╗
  /// ║ ❌ ZenDependencyNotFoundException                         ║
  /// ╠══════════════════════════════════════════════════════════╣
  /// ║ Dependency not found                                     ║
  /// ║ Type: UserService                                        ║
  /// ║ Scope: RootScope                                         ║
  /// ║ 💡 Suggestion: Zen.put(UserService());                    ║
  /// ╚══════════════════════════════════════════════════════════╝
  /// ```
  String _toStringVerbose() {
    final buffer = StringBuffer();
    const width = 58;

    // Header
    buffer.writeln('╔${'═' * width}╗');
    buffer.writeln('║ $icon ${runtimeType.toString().padRight(width - 4)}║');
    buffer.writeln('╠${'═' * width}╣');

    // Message
    _writeWrappedText(buffer, message, width);

    // Context
    if (context != null && context!.isNotEmpty) {
      buffer.writeln('║${' ' * width}║');
      for (final entry in context!.entries) {
        final line = '${entry.key}: ${entry.value}';
        buffer.writeln('║ ${line.padRight(width - 2)}║');
      }
    }

    // Suggestion
    if (suggestion != null) {
      buffer.writeln('║${' ' * width}║');
      buffer.writeln('║ 💡 Suggestion:${' ' * (width - 14)}║');
      _writeWrappedText(buffer, '   $suggestion', width);
    }

    // Documentation link
    if (docLink != null) {
      buffer.writeln('║${' ' * width}║');
      final linkLine = '📚 Learn more: $docLink';
      buffer.writeln('║ ${linkLine.padRight(width - 2)}║');
    }

    // Cause
    if (cause != null) {
      buffer.writeln('║${' ' * width}║');
      final causeLine = 'Caused by: ${cause.runtimeType}';
      buffer.writeln('║ ${causeLine.padRight(width - 2)}║');
      _writeWrappedText(buffer, '   ${cause.toString()}', width);
    }

    buffer.writeln('╚${'═' * width}╝');

    return buffer.toString();
  }

  /// Helper to write wrapped text within box
  void _writeWrappedText(StringBuffer buffer, String text, int width) {
    final lines = _wrapText(text, width - 4);
    for (final line in lines) {
      buffer.writeln('║ ${line.padRight(width - 2)}║');
    }
  }

  /// Wrap text to fit within width
  List<String> _wrapText(String text, int width) {
    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if ((currentLine.length + word.length + 1) <= width) {
        currentLine += ' $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }
}

// ============================================================================
// SPECIFIC EXCEPTION TYPES
// ============================================================================

/// Dependency not found in DI container
class ZenDependencyNotFoundException extends ZenException {
  ZenDependencyNotFoundException({
    required String typeName,
    required String scopeName,
    String? tag,
  }) : super(
          'Dependency not found',
          context: {
            'Type': typeName,
            'Scope': scopeName,
            if (tag != null) 'Tag': tag,
          },
          suggestion: tag != null
              ? 'Zen.put($typeName(), tag: \'$tag\');'
              : 'Zen.put($typeName());',
          docLink: 'https://github.com/sdegenaar/zenify#dependency-injection',
        );

  @override
  String get icon => '❌';

  @override
  String get category => 'DI';
}

/// Scope-related errors
class ZenScopeException extends ZenException {
  ZenScopeException(
    super.message, {
    super.context,
    super.suggestion,
    super.docLink,
  });

  @override
  String get icon => '🔒';

  @override
  String get category => 'Scope';
}

/// Controller not found
class ZenControllerNotFoundException extends ZenException {
  ZenControllerNotFoundException({
    required String typeName,
    String? customMessage,
    String? customSuggestion,
  }) : super(
          customMessage ?? '$typeName not found in the widget tree',
          context: {'Type': typeName},
          suggestion: customSuggestion ??
              'Two common causes:\n'
              '   1. Forgot ZenProvider? Wrap your route:\n'
              '      ZenProvider.create<$typeName>(create: () => $typeName(), child: const YourPage())\n'
              '   2. Used Zen.put<$typeName>() for a controller? That registers it globally but\n'
              '      ZenView only resolves from the widget tree — not the global scope.\n'
              '      • For page controllers: use ZenProvider.create<$typeName>() at your route.\n'
              '      • For global reactive state: use Zen.put + .to + ZenObserver instead of ZenView.',
          docLink:
              'https://github.com/sdegenaar/zenify/blob/main/doc/hierarchical_scopes_guide.md',
        );

  @override
  String get icon => '🎮';

  @override
  String get category => 'Controller';
}

/// Query-related errors
class ZenQueryException extends ZenException {
  ZenQueryException(
    super.message, {
    super.context,
    super.suggestion,
    super.cause,
    super.causeStackTrace,
  });

  @override
  String get icon => '🔍';

  @override
  String get category => 'Query';
}

/// Mutation-related errors
class ZenMutationException extends ZenException {
  ZenMutationException(
    super.message, {
    super.context,
    super.suggestion,
    super.cause,
    super.causeStackTrace,
  });

  @override
  String get icon => '✏️';

  @override
  String get category => 'Mutation';
}

/// Circular dependency detected
class ZenCircularDependencyException extends ZenException {
  ZenCircularDependencyException({
    required String typeName,
    required List<String> dependencyChain,
  }) : super(
          'Circular dependency detected',
          context: {
            'Type': typeName,
            'Chain': dependencyChain.join(' → '),
          },
          suggestion:
              'Break the circular dependency by using lazy initialization or restructuring your dependencies',
          docLink: 'https://github.com/sdegenaar/zenify#dependency-injection',
        );

  @override
  String get icon => '🔄';

  @override
  String get category => 'DI';
}

/// Scope has been disposed
class ZenDisposedScopeException extends ZenException {
  ZenDisposedScopeException({
    required String scopeName,
    required String operation,
  }) : super(
          'Cannot perform operation on disposed scope',
          context: {
            'Scope': scopeName,
            'Operation': operation,
          },
          suggestion: 'Check if the scope is still active before accessing it',
          docLink: 'https://github.com/sdegenaar/zenify#scopes',
        );

  @override
  String get icon => '🔒';

  @override
  String get category => 'Scope';
}

/// Scope not found in widget tree
class ZenScopeNotFoundException extends ZenException {
  ZenScopeNotFoundException({
    String? widgetType,
  }) : super(
          'No ZenScope found in widget tree',
          context: widgetType != null ? {'Widget': widgetType} : null,
          suggestion: 'Wrap your widget tree with ZenScope or use ZenRoute',
          docLink: 'https://github.com/sdegenaar/zenify#scopes',
        );

  @override
  String get icon => '🔍';

  @override
  String get category => 'Scope';
}

/// Controller has been disposed
class ZenControllerDisposedException extends ZenException {
  ZenControllerDisposedException({
    required String typeName,
  }) : super(
          'Controller has been disposed',
          context: {'Type': typeName},
          suggestion: 'Do not access controller after it has been disposed',
          docLink: 'https://github.com/sdegenaar/zenify#controllers',
        );

  @override
  String get icon => '🎮';

  @override
  String get category => 'Controller';
}

/// Module-related errors
class ZenModuleException extends ZenException {
  ZenModuleException(
    super.message, {
    super.context,
    super.suggestion,
  });

  @override
  String get icon => '📦';

  @override
  String get category => 'Module';
}

/// Lifecycle-related errors
class ZenLifecycleException extends ZenException {
  ZenLifecycleException(
    super.message, {
    super.context,
    super.suggestion,
  });

  @override
  String get icon => '♻️';

  @override
  String get category => 'Lifecycle';
}

/// Route-related errors
class ZenRouteException extends ZenException {
  ZenRouteException(
    super.message, {
    super.context,
    super.suggestion,
  });

  @override
  String get icon => '🛣️';

  @override
  String get category => 'Route';
}
