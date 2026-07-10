import 'package:flutter/material.dart';
import '../../controllers/zen_controller.dart';
import '../../core/zen_exception.dart';
import '../../core/zen_scope.dart';
import '../../di/zen_di.dart';
import '../scope/zen_scope_widget.dart';

/// Base class for screens and pages that consume a [ZenController].
///
/// ## Controller Resolution
///
/// [ZenView] resolves its controller via the widget tree in this priority order:
/// 1. **[initController]** — if overridden, the element creates and owns the
///    controller directly (lifecycle: `mount` → `onInit` → `onReady`; then
///    `unmount` → `onClose`). Use this for per-instance widgets whose
///    controller parameters come from the widget itself.
/// 2. **Nearest [ZenScopeWidget]** ancestor — tree-bound, safe for multiple
///    simultaneous instances.
/// 3. **Global [Zen] DI** fallback — for singleton services registered at app root.
///
/// ## Usage — Scope-provided controller (recommended for pages/screens)
///
/// ```dart
/// // Provide via parent:
/// ZenScopeWidget.create<CartController>(
///   create: () => CartController(),
///   child: const CartPage(),
/// )
///
/// // Consume in the view:
/// class CartPage extends ZenView<CartController> {
///   const CartPage({super.key});
///
///   @override
///   Widget build(BuildContext context, CartController controller) {
///     return Text('${controller.totalItems}');
///   }
/// }
/// ```
///
/// ## Usage — Self-owned controller (for per-instance widgets)
///
/// Use [initController] when the controller needs constructor parameters
/// from the widget itself (e.g., a `messageId`), making a parent
/// [ZenScopeWidget] impractical:
///
/// ```dart
/// class VoiceMessageView extends ZenView<VoiceMessageController> {
///   final String messageId;
///   final String messagePath;
///   const VoiceMessageView({required this.messageId, required this.messagePath, super.key});
///
///   @override
///   VoiceMessageController Function() get initController => () =>
///       VoiceMessageController(messageId: messageId, messagePath: messagePath);
///
///   @override
///   Widget build(BuildContext context, VoiceMessageController controller) {
///     return Stack(...); // purely UI — controller is injected
///   }
/// }
/// ```
///
/// ## Owned vs Scope-provided — Which to use?
///
/// | Situation | Pattern |
/// |---|---|
/// | Page/screen, controller is app-wide or feature-scoped | `ZenScopeWidget` + tree resolution |
/// | List-item widget, controller params from widget fields | `initController` |
/// | Multiple identical views on screen simultaneously | Both patterns work — each gets its own |
///
/// ## Important: Owned controllers are automatically scoped
///
/// A controller created via [initController] is automatically wrapped in a
/// [ZenScopeWidget]. This means child widgets can safely find it via
/// `context.controller<T>()`.
abstract class ZenView<T extends ZenController> extends Widget {
  const ZenView({super.key});

  /// Optional tag for disambiguating multiple registrations of the same type
  /// when resolving from the widget tree or global DI.
  String? get tag => null;

  /// Optional factory that creates a controller owned by this element.
  ///
  /// Override this when the controller needs parameters from the widget
  /// itself. The factory runs in `mount()` (once), `onInit()` is called
  /// immediately, `onReady()` is scheduled after the first frame, and
  /// `onClose()` is called in `unmount()` when permanently removed.
  ///
  /// The created controller is automatically exposed to child widgets via an
  /// implicit [ZenScopeWidget].
  T Function()? get initController => null;

  /// Build the widget with the injected controller.
  @protected
  Widget build(BuildContext context, T controller);

  @override
  Element createElement() => _ZenViewElement<T>(this);
}

class _ZenViewElement<T extends ZenController> extends ComponentElement {
  _ZenViewElement(ZenView<T> super.widget);

  /// Controller owned by this element (created via [ZenView.initController]).
  /// Null when the view relies on tree-based resolution instead.
  T? _ownedController;

  /// Implicit scope created to expose the owned controller to child widgets.
  ZenScope? _ownedScope;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  /// Called exactly once when the element is inserted into the tree.
  /// Equivalent to [State.initState] in a StatefulWidget.
  @override
  void mount(Element? parent, Object? newSlot) {
    // IMPORTANT: Create the controller BEFORE super.mount().
    // ComponentElement.mount() calls _firstBuild() synchronously, which calls
    // our build() method. If super.mount() ran first, _ownedController would
    // be null when build() executes and resolution would fall through to the
    // tree lookup — throwing if no scope parent exists.
    final factory = (widget as ZenView<T>).initController;
    if (factory != null) {
      _ownedController = factory();
      _ownedController!.onInit();
      // Auto-scope: wrap the controller so children can find it via the widget
      // tree. Use ZenScope directly (no parent) — this is a widget-tree-bound
      // scope, not a global-hierarchy scope. Zen.createScope() would incorrectly
      // parent it to rootScope, causing debug noise and violating the API contract.
      _ownedScope = ZenScope(name: 'ZenView_${T.toString()}');
      _ownedScope!.put<T>(_ownedController!, tag: (widget as ZenView<T>).tag);
    }

    super.mount(parent, newSlot); // Triggers _firstBuild → build() — controller is ready.

    // Schedule onReady after the first frame — identical to V1 StatefulWidget timing.
    if (_ownedController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ownedController != null) _ownedController!.onReady();
      });
    }
  }

  /// Called exactly once when the element is permanently removed from the tree.
  /// Equivalent to [State.dispose] in a StatefulWidget.
  @override
  void unmount() {
    _ownedScope?.dispose();
    _ownedScope = null;
    _ownedController = null; // ZenScope dispose handles calling onClose
    super.unmount();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build() {
    final zenWidget = widget as ZenView<T>;
    if (_ownedScope != null) {
      // Auto-scope: children CAN find this via context.controller<T>()
      return ZenScopeWidget(
        scope: _ownedScope,
        child: Builder(
          builder: (ctx) => zenWidget.build(ctx, _ownedController!),
        ),
      );
    }

    // Tree-bound resolution.
    final controller = _resolveFromTree(zenWidget);
    return zenWidget.build(this, controller);
  }

  /// Resolves the controller from the widget tree (scope → global DI → throw).
  T _resolveFromTree(ZenView<T> zenWidget) {
    // 1. Nearest ZenScopeWidget ancestor — fully isolated per tree position.
    final scope = mounted ? zenScope : null;
    if (scope != null) {
      final found = scope.find<T>(tag: zenWidget.tag);
      if (found != null) return found;
    }

    // 2. Global DI fallback — for true singleton services.
    final global = Zen.findOrNull<T>(tag: zenWidget.tag);
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

