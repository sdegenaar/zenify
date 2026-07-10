import 'package:flutter/material.dart';
import 'package:zenify/widgets/widgets.dart';
import '../../controllers/zen_controller.dart';
import '../../core/zen_exception.dart';
import '../../core/zen_scope.dart';
import '../../di/zen_di.dart';

/// Base class for screens and pages that own a [ZenController].
///
/// ## Controller Resolution
///
/// When the widget mounts, [ZenView] resolves its controller in this order:
/// 1. **Nearest [ZenScope]** in the widget tree (scope-isolated; safe for
///    multiple simultaneous instances).
/// 2. **Global [Zen] DI** — for singleton screens registered at the app root.
///
/// If neither source has the controller and [createController] is provided,
/// the controller is created and registered automatically into the nearest
/// scope (or global DI if no scope ancestor is present).
///
/// ## Usage
///
/// Override [build] and use the [controller] getter to access the resolved
/// controller — always non-nullable inside [build].
///
/// ```dart
/// class CounterPage extends ZenView<CounterController> {
///   const CounterPage({super.key});
///
///   @override
///   CounterController Function()? get createController =>
///       () => CounterController();
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       body: ZenObserver(() => Text('${controller.count.value}')),
///       floatingActionButton: FloatingActionButton(
///         onPressed: controller.increment,
///         child: const Icon(Icons.add),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Multi-Instance Safety
///
/// [ZenView] uses a per-instance stack registry. When two widgets of the same
/// type are active simultaneously (e.g., nested navigation, split-screen), each
/// pushes its own controller onto the stack. The [controller] getter always
/// returns the innermost (most recently mounted) instance — mirroring how
/// Flutter's `InheritedWidget` lookup works.
///
/// For components that need guaranteed per-widget isolation, use a plain
/// [StatelessWidget] and `context.controller<T>()` directly — this resolves
/// purely from [ZenScope], with no global registry involved.
///
/// See also:
/// - [ZenScopeWidget] — to provide an isolated [ZenScope] to a subtree.
/// - [ZenBuilder] — for precise, builder-pattern reactive rebuilds.
/// - [ZenObserver] — for automatic reactive dependency tracking.
abstract class ZenView<T extends ZenController> extends StatefulWidget {
  const ZenView({super.key});

  /// Optional tag for disambiguating multiple registrations of the same type.
  String? get tag => null;

  /// Optional factory to create the controller if it is not already registered.
  ///
  /// The created controller is placed into the nearest [ZenScope] (or global
  /// DI if no scope ancestor is present).
  T Function()? get createController => null;

  /// Optional explicit scope override.
  ///
  /// When set, controller resolution uses this scope rather than the nearest
  /// ancestor scope from the widget tree.
  ZenScope? get scope => null;

  /// Build the widget.
  ///
  /// Use the [controller] getter to access the resolved controller.
  /// It is always non-nullable inside [build].
  Widget build(BuildContext context);

  @override
  State<ZenView<T>> createState() => _ZenViewState<T>();
}

class _ZenViewState<T extends ZenController> extends State<ZenView<T>> {
  T? _controller;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeController();
      _isInitialized = true;
    }
  }

  void _initializeController() {
    T? instance = _findController();

    if (instance == null && widget.createController != null) {
      instance = widget.createController!();
      _registerController(instance);
    }

    if (instance == null) {
      throw ZenControllerNotFoundException(typeName: T.toString());
    }

    _controller = instance;

    // Push onto the instance stack so the `controller` getter finds the
    // correct instance even when multiple ZenViews of the same type are
    // simultaneously active in the widget tree.
    _ZenViewRegistry.push<T>(_controller!);
  }

  T? _findController() {
    final targetScope =
        widget.scope ?? (context.mounted ? context.zenScope : null);

    if (targetScope != null) {
      final found = targetScope.find<T>(tag: widget.tag);
      if (found != null) return found;
    }

    return Zen.findOrNull<T>(tag: widget.tag);
  }

  void _registerController(T controller) {
    final targetScope =
        widget.scope ?? (context.mounted ? context.zenScope : null);
    if (targetScope != null) {
      targetScope.put<T>(controller, tag: widget.tag);
    } else {
      Zen.put<T>(controller, tag: widget.tag);
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      _ZenViewRegistry.pop<T>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return widget.build(context);
  }
}

/// Per-type stack registry for [ZenView] controller instances.
///
/// Uses a stack (rather than a flat map) so that when multiple [ZenView]s of
/// the same type are simultaneously active, [peek] always returns the innermost
/// (most recently mounted) controller — analogous to nearest-ancestor semantics.
///
/// Lifecycle:
/// - [push]: called when a [ZenView] mounts and its controller is resolved.
/// - [pop]: called when the [ZenView] disposes.
/// - [peek]: returns the current top-of-stack controller for type [T].
class _ZenViewRegistry {
  static final Map<Type, List<ZenController>> _stack = {};

  static void push<T extends ZenController>(T controller) {
    _stack.putIfAbsent(T, () => []).add(controller);
  }

  static void pop<T extends ZenController>() {
    final list = _stack[T];
    if (list != null && list.isNotEmpty) {
      list.removeLast();
      if (list.isEmpty) _stack.remove(T);
    }
  }

  static T? peek<T extends ZenController>() {
    return _stack[T]?.lastOrNull as T?;
  }
}

/// Provides access to the [ZenController] resolved by this [ZenView].
///
/// The [controller] getter always returns the innermost active instance
/// for type [T] — correct even when multiple [ZenView]s of the same type
/// are simultaneously mounted.
///
/// Use this getter inside [ZenView.build] and any helper methods on the
/// [ZenView] subclass.
extension ZenViewExtension<T extends ZenController> on ZenView<T> {
  T get controller {
    // 1. Stack peek — innermost active ZenView instance for this type
    final stacked = _ZenViewRegistry.peek<T>();
    if (stacked != null) return stacked;

    // 2. Explicit scope override
    final s = scope;
    if (s != null) {
      final found = s.find<T>(tag: tag);
      if (found != null) return found;
    }

    // 3. Global DI fallback (e.g., controller registered before navigation)
    final global = Zen.findOrNull<T>(tag: tag);
    if (global != null) return global;

    throw ZenControllerNotFoundException(typeName: T.toString());
  }
}

/// Context extension for resolving a [ZenController] from within any widget.
///
/// Resolves strictly from the widget tree — no global registry involved.
/// This makes it safe for any number of simultaneous instances.
///
/// Resolution order (most-specific first):
/// 1. **Nearest [ZenScope]** in the widget tree.
/// 2. **Global [Zen.findOrNull]** — root-scope / singleton registrations.
///
/// Prefer this over [ZenViewExtension.controller] for:
/// - Plain [StatelessWidget] components inside a [ZenScopeWidget].
/// - Any widget that needs guaranteed per-widget-tree-position isolation.
///
/// ```dart
/// final ctrl = context.controller<MyController>();
/// ```
extension ZenViewContextExtensions on BuildContext {
  T controller<T extends ZenController>({String? tag}) {
    // 1. Scope-based lookup — pure widget-tree resolution, fully isolated
    final scope = mounted ? zenScope : null;
    if (scope != null) {
      final found = scope.find<T>(tag: tag);
      if (found != null) return found;
    }

    // 2. Global DI fallback
    final global = Zen.findOrNull<T>(tag: tag);
    if (global != null) return global;

    throw ZenControllerNotFoundException(typeName: T.toString());
  }
}
