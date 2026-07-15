import 'package:flutter/material.dart';
import '../../controllers/zen_controller.dart';
import '../../core/zen_exception.dart';
import '../scope/zen_provider.dart';

/// Base class for screens, pages, and widgets that consume a [ZenController].
///
/// ## The Three-Step Pattern
///
/// ```
/// 1. Register  →  ZenProvider.create<T>(create: ...)   // route-level
///                  ZenProvider(moduleBuilder: ...)      // feature module
///                  Zen.put<T>(...)                      // app-level singleton
///
/// 2. Consume   →  class MyPage extends ZenView<MyController>
///                   → controller injected into build() automatically
///
/// 3. React     →  ZenObserver / ZenUpdater / ZenQuery.when()
/// ```
///
/// ## Controller Resolution
///
/// [ZenView] resolves its controller from the **nearest [ZenProvider] ancestor**
/// in the widget tree. There is no global fallback — if no scope is found, a
/// [ZenControllerNotFoundException] is thrown with a clear message telling you
/// exactly what to add.
///
/// ## Standard Usage — Route-level controller
///
/// Wrap the view in [ZenProvider.create] at the router / navigation callsite:
///
/// ```dart
/// // In your router:
/// ZenProvider.create<CartController>(
///   create: () => CartController(),
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
/// ## Module Usage — Feature module with dependencies
///
/// ```dart
/// ZenProvider(
///   moduleBuilder: () => CartModule(),
///   child: const CartPage(),
/// )
/// ```
///
/// ## Which pattern to use?
///
/// | Situation | Pattern |
/// |---|---|
/// | App-level services (auth, analytics) | `Zen.registerModules([AppModule()])` at startup |
/// | Route/feature-level controllers | `ZenProvider.create<T>(create: ...)` in router |
/// | Feature with dependencies | `ZenProvider(moduleBuilder: () => FeatureModule())` |
/// | App-level singleton (prototyping) | `Zen.put<T>(...)` at startup |
abstract class ZenView<T extends ZenController> extends Widget {
  const ZenView({super.key});

  /// Optional tag for disambiguating multiple registrations of the same type.
  String? get tag => null;

  /// Build the widget with the injected controller.
  ///
  /// The controller is resolved from the nearest [ZenProvider] ancestor.
  /// This method is called by the framework — do not call it directly.
  @protected
  Widget build(BuildContext context, T controller);

  @override
  Element createElement() => _ZenViewElement<T>(this);
}

class _ZenViewElement<T extends ZenController> extends ComponentElement {
  _ZenViewElement(ZenView<T> super.widget);

  @override
  Widget build() {
    final zenWidget = widget as ZenView<T>;

    // Tree-bound resolution. Wrap in Builder for consistent BuildContext
    // semantics — context.controller<T>() inside build() resolves correctly.
    final controller = _resolveFromTree(zenWidget);
    return Builder(builder: (ctx) => zenWidget.build(ctx, controller));
  }

  /// Resolves the controller strictly from the nearest [ZenProvider] in the tree.
  ///
  /// Throws [ZenControllerNotFoundException] with a helpful message if not found.
  T _resolveFromTree(ZenView<T> zenWidget) {
    final scope = mounted ? zenScope : null;
    if (scope != null) {
      final found = scope.find<T>(tag: zenWidget.tag);
      if (found != null) return found;
    }

    throw ZenControllerNotFoundException(
      typeName: T.toString(),
      customMessage: 'No $T found in the widget tree.',
    );
  }
}

/// Context extension for resolving a [ZenController] from within any widget.
///
/// Resolves strictly from the **nearest [ZenProvider] ancestor** in the widget
/// tree. There is no global fallback — if no scope is found the call throws a
/// [ZenControllerNotFoundException] with a clear, actionable message.
///
/// ```dart
/// final ctrl = context.controller<MyController>();
/// ```
///
/// For typed shorthand, define your own extension:
///
/// ```dart
/// extension CartContextExt on BuildContext {
///   CartController get cart => controller<CartController>();
/// }
///
/// // Then in any widget:
/// context.cart.checkout();
/// ```
extension ZenViewContextExtensions on BuildContext {
  T controller<T extends ZenController>({String? tag}) {
    // Scope-based lookup — pure widget-tree resolution, fully isolated.
    final scope = mounted ? zenScope : null;
    if (scope != null) {
      final found = scope.find<T>(tag: tag);
      if (found != null) return found;
    }

    throw ZenControllerNotFoundException(
      typeName: T.toString(),
      customMessage: 'No $T found in the widget tree.',
    );
  }
}
