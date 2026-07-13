import 'package:flutter/material.dart';
import '../../controllers/zen_controller.dart';
import '../../core/zen_exception.dart';
import '../../core/zen_scope.dart';
import '../../di/zen_di.dart';
import '../scope/zen_scope_widget.dart';

/// Base class for screens, pages, and widgets that consume a [ZenController].
///
/// ## The Three-Step Pattern
///
/// ```
/// 1. Register  →  Zen.registerModules([AppModule()])      // app-level
///                  ZenScopeWidget(moduleBuilder: ...)      // route-level
///                  Zen.put<T>(...)                         // quick singleton
///
/// 2. Consume   →  class MyPage extends ZenView<MyController>
///                   → controller injected into build() automatically
///
/// 3. React     →  ZenObserver / ZenUpdater / ZenQuery.when()
/// ```
///
/// ## Controller Resolution Order
///
/// [ZenView] resolves its controller automatically in this priority order:
/// 1. **[initController]** — if overridden, the element creates and owns the
///    controller directly. Use this for per-instance widgets (list items, cards)
///    whose controller parameters come from the widget's own fields.
/// 2. **Nearest [ZenScopeWidget]** ancestor — typical for route-level modules.
/// 3. **Global [Zen] DI** fallback — for singletons registered at app startup.
///
/// ## Standard Usage — Module-registered controller (pages and screens)
///
/// Register in your router or app module, then just consume:
///
/// ```dart
/// // In your router:
/// ZenScopeWidget(
///   moduleBuilder: () => CartModule(),
///   child: const CartPage(),
/// )
///
/// // The page — zero lookup code:
/// class CartPage extends ZenView<CartController> {
///   const CartPage({super.key});
///
///   @override
///   Widget build(BuildContext context, CartController controller) {
///     return ZenObserver(() => Text('${controller.itemCount.value} items'));
///   }
/// }
/// ```
///
/// ## Per-instance Usage — Self-owned controller (list items, cards)
///
/// Use [initController] when each widget instance needs its own isolated
/// controller, especially when the controller takes parameters from the widget:
///
/// ```dart
/// class VoiceMessageView extends ZenView<VoiceMessageController> {
///   final String messageId;
///   final String messagePath;
///   const VoiceMessageView({
///     required this.messageId,
///     required this.messagePath,
///     super.key,
///   });
///
///   @override
///   VoiceMessageController Function() get initController => () =>
///       VoiceMessageController(messageId: messageId, messagePath: messagePath);
///
///   @override
///   Widget build(BuildContext context, VoiceMessageController controller) {
///     return Slider(value: controller.progress.value, onChanged: (_) {});
///   }
/// }
/// ```
///
/// ## Which pattern to use?
///
/// | Situation | Pattern |
/// |---|---|
/// | App-level services (auth, analytics) | `Zen.registerModules([AppModule()])` at startup |
/// | Route/feature-level controllers | `ZenScopeWidget(moduleBuilder: () => FeatureModule())` in router |
/// | Per-instance widget (list item, card) | `initController` getter override |
/// | Quick singleton (prototyping) | `Zen.put<T>(...)` at startup |
///
/// ## Owned controllers and child access
///
/// A controller created via [initController] is automatically wrapped in an
/// implicit [ZenScopeWidget], so child widgets can safely resolve it via
/// `context.controller<T>()`.
abstract class ZenView<T extends ZenController> extends Widget {
  const ZenView({super.key});

  /// Optional tag for disambiguating multiple registrations of the same type.
  String? get tag => null;

  /// Optional factory that creates a controller owned by this element.
  ///
  /// Override this for per-instance widgets (list items, cards) where the
  /// controller needs parameters from the widget itself. The factory runs in
  /// `mount()` once — `onInit()` is called immediately, `onReady()` after the
  /// first frame, and `onClose()` when the element is permanently removed.
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
      // Include hashCode so DevTools shows unique names for each instance
      // (e.g. 200 PostCard items won't all show as "ZenView_PostCardController").
      _ownedScope = ZenScope(name: 'ZenView_${T}_$hashCode');
      _ownedScope!.put<T>(_ownedController!, tag: (widget as ZenView<T>).tag);
    }

    super.mount(parent,
        newSlot); // Triggers _firstBuild → build() — controller is ready.

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
      // Owned controller path: wrap in ZenScopeWidget so children can resolve
      // via context.controller<T>(). Use a Builder so the context passed to
      // zenWidget.build() is a fresh descendant context (same as tree-resolution
      // path below — both paths are now consistent).
      return ZenScopeWidget(
        scope: _ownedScope,
        child: Builder(
          builder: (ctx) => zenWidget.build(ctx, _ownedController!),
        ),
      );
    }

    // Tree-bound resolution. Wrap in Builder for consistent BuildContext
    // semantics — context.controller<T>() inside build() resolves correctly
    // regardless of which path was taken.
    final controller = _resolveFromTree(zenWidget);
    return Builder(builder: (ctx) => zenWidget.build(ctx, controller));
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
