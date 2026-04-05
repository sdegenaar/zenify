import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests targeting remaining uncovered lines in zen_controller.dart:
/// - L321: _batchWorkerOperation groupOp(group) — pauseAll on worker group
/// - L333: _batchWorkerOperation groupOp(group) — resumeAll on worker group
/// - L631,632: _disposeReactiveObjects — reactive object tracked then ctrl disposed
/// - L659,660: _disposeChildControllers — child controller tracked then ctrl disposed
/// - L773,783: _batchWorkerOperation error paths
/// - L801: _cleanupAllWorkers worker dispose error
/// - L810: _cleanupAllWorkers group dispose error
/// - L822: _cleanupEffects effect dispose error
///
/// And zen_scope.dart:
/// - L120: replacing existing tagged ZenController disposes old instance
/// - L172-173: putLazy on disposed scope throws ZenDisposedScopeException
/// - L179: putLazy isPermanent+alwaysNew throws ArgumentError
/// - L592-599, L631-638: clearAll error tolerance during disposal
void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // Worker group pause/resume via createWorkerGroup() (L321, L333)
  // ══════════════════════════════════════════════════════════
  group('ZenController worker group pause/resume', () {
    test('pauseAllWorkers / resumeAllWorkers operate on worker group', () {
      final ctrl = _SimpleCtrl();
      Zen.put<_SimpleCtrl>(ctrl);

      // Create a group via the public API — it auto-registers with the controller
      final group = ctrl.createWorkerGroup();
      final rx = Rx<int>(0);
      int calls = 0;
      group.add(ZenWorkers.ever(rx, (_) => calls++));

      ctrl.pauseAllWorkers(); // should call group.pauseAll()
      rx.value = 1;
      expect(calls, 0); // group is paused

      ctrl.resumeAllWorkers(); // should call group.resumeAll()
      rx.value = 2;
      expect(calls, 1); // group is resumed
    });

    test('createWorkerGroup throws on disposed controller', () {
      final ctrl = _SimpleCtrl();
      ctrl.dispose();
      expect(() => ctrl.createWorkerGroup(), throwsA(isA<StateError>()));
    });
  });

  // ══════════════════════════════════════════════════════════
  // _disposeReactiveObjects via trackRx (L631,632)
  // ══════════════════════════════════════════════════════════
  group('ZenController._disposeReactiveObjects', () {
    test('tracked reactive values are disposed with the controller', () {
      final ctrl = _SimpleCtrl();
      Zen.put<_SimpleCtrl>(ctrl);
      final rx = Rx<int>(0);
      ctrl.trackReactive(rx);

      ctrl.dispose();
      expect(rx.isDisposed, true);
    });

    test('reactive object count is tracked', () {
      final ctrl = _SimpleCtrl();
      Zen.put<_SimpleCtrl>(ctrl);
      final rx = Rx<int>(0);
      ctrl.trackReactive(rx);
      expect(ctrl.reactiveObjectCount, 1);
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // _disposeChildControllers via trackController (L659,660)
  // ══════════════════════════════════════════════════════════
  group('ZenController._disposeChildControllers', () {
    test('tracked child controllers are disposed with the parent', () {
      final parent = _SimpleCtrl();
      Zen.put<_SimpleCtrl>(parent);
      final child = _SimpleCtrl();
      parent.trackController(child);

      parent.dispose();
      expect(child.isDisposed, true);
    });

    test('child controller count is tracked', () {
      final parent = _SimpleCtrl();
      Zen.put<_SimpleCtrl>(parent);
      final child = _SimpleCtrl();
      parent.trackController(child);
      expect(parent.childControllerCount, 1);
      parent.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenScope: replacing tagged controller disposes old (L120)
  // ══════════════════════════════════════════════════════════
  group('ZenScope.put replaces and disposes old tagged dependency', () {
    test('putting new tagged dependency disposes the old ZenController', () {
      final scope = Zen.createScope(name: 'ReplaceTagScope');
      final old = _SimpleCtrl();
      scope.put<_SimpleCtrl>(old, tag: 'slot');

      final replacement = _SimpleCtrl();
      scope.put<_SimpleCtrl>(replacement, tag: 'slot');

      expect(old.isDisposed, true);
      expect(replacement.isDisposed, false);

      scope.dispose();
    });

    test('putting new untagged dependency disposes the old ZenController', () {
      final scope = Zen.createScope(name: 'ReplaceTypeScope');
      final old = _SimpleCtrl();
      scope.put<_SimpleCtrl>(old);

      final replacement = _SimpleCtrl();
      scope.put<_SimpleCtrl>(replacement);

      expect(old.isDisposed, true);
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenScope.putLazy validation errors (L172-173, L179)
  // ══════════════════════════════════════════════════════════
  group('ZenScope.putLazy validation', () {
    test('putLazy on disposed scope throws ZenDisposedScopeException', () {
      final scope = Zen.createScope(name: 'DisposedForLazy');
      scope.dispose();
      expect(
        () => scope.putLazy<_SimpleCtrl>(() => _SimpleCtrl()),
        throwsA(isA<ZenDisposedScopeException>()),
      );
    });

    test('putLazy isPermanent+alwaysNew=true throws ArgumentError', () {
      final scope = Zen.createScope(name: 'ConflictLazy');
      expect(
        () => scope.putLazy<_SimpleCtrl>(
          () => _SimpleCtrl(),
          isPermanent: true,
          alwaysNew: true,
        ),
        throwsA(isA<ArgumentError>()),
      );
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenScope.clearAll with controller that throws on dispose
  // (L592-593, L599: error catch in clearAll)
  // ══════════════════════════════════════════════════════════
  group('ZenScope.clearAll error tolerance', () {
    test('clearAll tolerates controller that throws during dispose', () {
      final scope = Zen.createScope(name: 'ThrowingClear');
      scope.put<_ThrowingOnCloseCtrl>(_ThrowingOnCloseCtrl());

      // force=true is needed since ZenController is permanent by default
      expect(() => scope.clearAll(force: true), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenScope.put on disposed scope (L355-356)
  // ══════════════════════════════════════════════════════════
  group('ZenScope.put on disposed scope', () {
    test('put on disposed scope throws ZenDisposedScopeException', () {
      final scope = Zen.createScope(name: 'DisposedPutScope');
      scope.dispose();
      expect(
        () => scope.put<_SimpleCtrl>(_SimpleCtrl()),
        throwsA(isA<ZenDisposedScopeException>()),
      );
    });
  });
}

// ── Helpers ──

class _SimpleCtrl extends ZenController {}

class _ThrowingOnCloseCtrl extends ZenController {
  @override
  void onClose() {
    super.onClose();
    throw Exception('onClose error');
  }
}
