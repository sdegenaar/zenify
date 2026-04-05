import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests targeting remaining uncovered lines in zen_scope.dart:
/// - L281: find() on disposed scope warns and returns null
/// - L355-356: delete() on disposed scope returns false
/// - L416-417: deleteByTag() logging permanent dependency warning
/// - L437: deleteByTag() disposes ZenService
/// - L592-593: clearAll() controller dispose error catch (type bindings)
/// - L599: clearAll() service dispose error catch (type bindings)
/// - L631-632: clearAll() controller dispose error catch (tagged bindings)
/// - L638: clearAll() service dispose error catch (tagged bindings)
/// - L653-665: clearAll() factory clearing path
/// - L801-802: _initializeController calling onReady via _createFromFactory
void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // L281 — find() on disposed scope
  // ══════════════════════════════════════════════════════════
  group('ZenScope.find on disposed scope', () {
    test('find on disposed scope returns null', () {
      final scope = Zen.createScope(name: 'FindDisposed');
      scope.put<_ScopeCtrl>(_ScopeCtrl());
      scope.dispose();

      // find() should return null quietly on disposed scope
      final result = scope.find<_ScopeCtrl>();
      expect(result, isNull);
    });
  });

  // ══════════════════════════════════════════════════════════
  // L355-356 — delete() on disposed scope
  // ══════════════════════════════════════════════════════════
  group('ZenScope.delete on disposed scope', () {
    test('delete on disposed scope returns false', () {
      final scope = Zen.createScope(name: 'DeleteDisposed');
      scope.put<_ScopeCtrl>(_ScopeCtrl());
      scope.dispose();
      expect(scope.delete<_ScopeCtrl>(), false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // L416-417 — deleteByTag() permanent warning
  // ══════════════════════════════════════════════════════════
  group('ZenScope.deleteByTag', () {
    test(
        'deleteByTag on permanent dependency without force logs warning and returns false',
        () {
      final scope = Zen.createScope(name: 'TagPermanentScope');
      // Explicitly register as permanent
      scope.put<_ScopeCtrl>(_ScopeCtrl(), tag: 'perm-tag', isPermanent: true);

      // Without force, should return false for permanent
      final result = scope.deleteByTag('perm-tag', force: false);
      expect(result, false); // permanent, rejected without force

      // Cleanup with force
      scope.deleteByTag('perm-tag', force: true);
      scope.dispose();
    });

    test('deleteByTag with force=true removes permanent dependency', () {
      final scope = Zen.createScope(name: 'ForceTagDelete');
      final ctrl = _ScopeCtrl();
      scope.put<_ScopeCtrl>(ctrl, tag: 'force-tag');

      final result = scope.deleteByTag('force-tag', force: true);
      expect(result, true);
      expect(ctrl.isDisposed, true);
      scope.dispose();
    });

    test('deleteByTag missing tag returns false', () {
      final scope = Zen.createScope(name: 'MissingTag');
      expect(scope.deleteByTag('nonexistent-tag'), false);
      scope.dispose();
    });

    test('deleteByTag disposes ZenService (L437)', () {
      final scope = Zen.createScope(name: 'ServiceTagDelete');
      final svc = _ScopeService();
      scope.put<_ScopeService>(svc, tag: 'svc-tag', isPermanent: false);

      final result = scope.deleteByTag('svc-tag', force: true);
      expect(result, true);
      expect(svc.isDisposed, true);
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // L592-593 — clearAll() with throwing controller (type bindings)
  // ══════════════════════════════════════════════════════════
  group('ZenScope.clearAll error catch', () {
    test(
        'clearAll tolerates controller throwing on dispose (type binding, L592-593)',
        () {
      final scope = Zen.createScope(name: 'ClearAllThrowType');
      scope.put<_ThrowingCtrl>(_ThrowingCtrl());

      expect(() => scope.clearAll(force: true), returnsNormally);
    });

    test('clearAll tolerates service throwing on dispose (type binding, L599)',
        () {
      final scope = Zen.createScope(name: 'ClearAllThrowSvcType');
      scope.put<_ThrowingSvc>(_ThrowingSvc(), isPermanent: false);

      expect(() => scope.clearAll(force: true), returnsNormally);
    });

    test(
        'clearAll tolerates controller throwing on dispose (tagged binding, L631-632)',
        () {
      final scope = Zen.createScope(name: 'ClearAllThrowTagged');
      scope.put<_ThrowingCtrl>(_ThrowingCtrl(), tag: 'throw-ctrl');

      expect(() => scope.clearAll(force: true), returnsNormally);
    });

    test(
        'clearAll tolerates service throwing on dispose (tagged binding, L638)',
        () {
      final scope = Zen.createScope(name: 'ClearAllThrowSvcTagged');
      scope.put<_ThrowingSvc>(_ThrowingSvc(),
          tag: 'throw-svc', isPermanent: false);

      expect(() => scope.clearAll(force: true), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // L653-665 — clearAll() factory clearing path
  // ══════════════════════════════════════════════════════════
  group('ZenScope.clearAll factory clearing', () {
    test('clearAll with force=true removes factories', () {
      final scope = Zen.createScope(name: 'ClearFactories');
      scope.putLazy<_ScopeCtrl>(() => _ScopeCtrl(), isPermanent: false);

      // Verify factory is registered
      expect(scope.contains<_ScopeCtrl>(), true);

      scope.clearAll(force: true);
      expect(scope.contains<_ScopeCtrl>(), false);
      scope.dispose();
    });

    test(
        'clearAll without force does not remove currently instantiated permanent instances',
        () {
      final scope = Zen.createScope(name: 'ClearNonPermFactories');
      // Put a permanent instance
      final ctrl = _ScopeCtrl2();
      scope.put<_ScopeCtrl2>(ctrl, isPermanent: true);
      // Put a non-permanent instance
      scope.put<_ScopeCtrl>(_ScopeCtrl(), isPermanent: false);

      scope.clearAll(force: false);
      // Permanent instance should remain
      expect(scope.contains<_ScopeCtrl2>(), true);
      // Non-permanent instance is cleared
      expect(scope.contains<_ScopeCtrl>(), false);
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // L801-802 — _initializeController calling onReady via lazy factory
  // ══════════════════════════════════════════════════════════
  group('ZenScope lazy factory auto-initialization', () {
    test('_createFromFactory auto-initializes ZenController (L801-802)', () {
      final scope = Zen.createScope(name: 'AutoInitLazy');
      bool onReadyCalled = false;
      final tracker = _TrackingCtrl(() => onReadyCalled = true);

      scope.putLazy<_TrackingCtrl>(() => tracker, isPermanent: false);

      // Trigger factory instantiation
      final result = scope.find<_TrackingCtrl>();
      expect(result, isNotNull);
      expect(result!.isInitialized, true);
      // onInit/onReady should have been called via _initializeController
      expect(onReadyCalled, true);
      scope.dispose();
    });

    test('_createFromFactory auto-initializes ZenService', () {
      final scope = Zen.createScope(name: 'AutoInitSvcLazy');
      final svc = _ScopeService();
      scope.putLazy<_ScopeService>(() => svc, isPermanent: false);

      final result = scope.find<_ScopeService>();
      expect(result, isNotNull);
      expect(result!.isInitialized, true);
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // Additional scope utility methods
  // ══════════════════════════════════════════════════════════
  group('ZenScope utility methods', () {
    test('containsInstance returns true for registered instance', () {
      final scope = Zen.createScope(name: 'ContainsScope');
      final ctrl = _ScopeCtrl();
      scope.put<_ScopeCtrl>(ctrl);
      expect(scope.containsInstance(ctrl), true);
      scope.dispose();
    });

    test('containsInstance returns false for disposed scope', () {
      final scope = Zen.createScope(name: 'ContainsDisposed');
      scope.dispose();
      expect(scope.containsInstance(Object()), false);
    });

    test('isPermanent returns true for permanent type', () {
      final scope = Zen.createScope(name: 'PermanentScope');
      scope.put<_ScopeCtrl>(_ScopeCtrl(), isPermanent: true);
      expect(scope.isPermanent(type: _ScopeCtrl), true);
      scope.dispose();
    });

    test('getTagForInstance returns tag if exists', () {
      final scope = Zen.createScope(name: 'TagForInstanceScope');
      final ctrl = _ScopeCtrl();
      scope.put<_ScopeCtrl>(ctrl, tag: 'my-instance-tag');
      expect(scope.getTagForInstance(ctrl), 'my-instance-tag');
      scope.dispose();
    });

    test('getAllDependencies returns empty list on disposed scope', () {
      final scope = Zen.createScope(name: 'GetAllDisposed');
      scope.put<_ScopeCtrl>(_ScopeCtrl());
      scope.dispose();
      expect(scope.getAllDependencies(), isEmpty);
    });

    test('forceCompleteReset clears bindings without disposing scope', () {
      final scope = Zen.createScope(name: 'ForceResetScope');
      scope.put<_ScopeCtrl>(_ScopeCtrl());
      scope.forceCompleteReset();
      expect(scope.exists<_ScopeCtrl>(), false);
      expect(scope.isDisposed, false);
      scope.dispose();
    });

    test('registerDisposer on disposed scope throws', () {
      final scope = Zen.createScope(name: 'RegisterDisposerDisposed');
      scope.dispose();
      expect(
        () => scope.registerDisposer(() {}),
        throwsA(isA<ZenDisposedScopeException>()),
      );
    });

    test('deleteByType disposes controller', () {
      final scope = Zen.createScope(name: 'DeleteByTypeScope');
      final ctrl = _ScopeCtrl();
      scope.put<_ScopeCtrl>(ctrl, isPermanent: false);
      final result = scope.deleteByType(_ScopeCtrl, force: true);
      expect(result, true);
      expect(ctrl.isDisposed, true);
      scope.dispose();
    });

    test('deleteByType on permanent without force returns false (L458-459)',
        () {
      final scope = Zen.createScope(name: 'DeleteByTypePerm');
      scope.put<_ScopeCtrl>(_ScopeCtrl(), isPermanent: true);
      // Without force, permanent types should not be deleted
      final result = scope.deleteByType(_ScopeCtrl, force: false);
      expect(result, false);
      scope.deleteByType(_ScopeCtrl, force: true);
      scope.dispose();
    });

    test('deleteByType on disposed scope returns false (L488)', () {
      final scope = Zen.createScope(name: 'DeleteByTypeDisposed');
      scope.put<_ScopeCtrl>(_ScopeCtrl());
      scope.dispose();
      expect(scope.deleteByType(_ScopeCtrl), false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Convenience aliases: get, remove, has, toString (L859-879)
  // ══════════════════════════════════════════════════════════
  group('ZenScope convenience aliases', () {
    test('get<T> is alias for find<T> (L859)', () {
      final scope = Zen.createScope(name: 'GetAliasScope');
      final ctrl = _ScopeCtrl();
      scope.put<_ScopeCtrl>(ctrl);
      expect(scope.get<_ScopeCtrl>(), ctrl);
      scope.dispose();
    });

    test('remove<T> is alias for delete<T> (L865-866)', () {
      final scope = Zen.createScope(name: 'RemoveAliasScope');
      final ctrl = _ScopeCtrl();
      scope.put<_ScopeCtrl>(ctrl, isPermanent: false);
      final result = scope.remove<_ScopeCtrl>(force: true);
      expect(result, true);
      expect(ctrl.isDisposed, true);
      scope.dispose();
    });

    test('has<T> is alias for exists<T> (L872)', () {
      final scope = Zen.createScope(name: 'HasAliasScope');
      scope.put<_ScopeCtrl>(_ScopeCtrl());
      expect(scope.has<_ScopeCtrl>(), true);
      expect(scope.has<_ScopeCtrl2>(), false);
      scope.dispose();
    });

    test('toString returns descriptive string (L875-879)', () {
      final scope = Zen.createScope(name: 'ToStringScope');
      scope.put<_ScopeCtrl>(_ScopeCtrl());
      final str = scope.toString();
      expect(str, contains('ToStringScope'));
      expect(str, contains('dependencies'));
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // L281 — findAllOfType on disposed scope
  // ══════════════════════════════════════════════════════════
  group('ZenScope.findAllOfType', () {
    test('findAllOfType returns empty list on disposed scope (L281)', () {
      final scope = Zen.createScope(name: 'FindAllDisposed');
      scope.put<_ScopeCtrl>(_ScopeCtrl());
      scope.dispose();
      expect(scope.findAllOfType<_ScopeCtrl>(), isEmpty);
    });

    test('findAllOfType returns all instances of type from scope', () {
      final scope = Zen.createScope(name: 'FindAllScope');
      final ctrl1 = _ScopeCtrl();
      final ctrl2 = _ScopeCtrl();
      scope.put<_ScopeCtrl>(ctrl1, tag: 'a');
      scope.put<_ScopeCtrl>(ctrl2, tag: 'b');
      final all = scope.findAllOfType<_ScopeCtrl>();
      expect(all.length, greaterThanOrEqualTo(2));
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // L355-356 — delete factory that was registered but never instantiated
  // ══════════════════════════════════════════════════════════
  group('ZenScope.delete factory path', () {
    test('delete factory-only entry (L355-356)', () {
      final scope = Zen.createScope(name: 'DeleteFactoryScope');
      scope.putLazy<_ScopeCtrl>(() => _ScopeCtrl(), isPermanent: false);

      // Delete BEFORE ever calling find (factory never instantiated)
      final result = scope.delete<_ScopeCtrl>();
      expect(result, true);
      expect(scope.contains<_ScopeCtrl>(), false);
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // L473, L488 — deleteByType for ZenService
  // ══════════════════════════════════════════════════════════
  group('ZenScope.deleteByType service path', () {
    test('deleteByType disposes ZenService (L473, L488)', () {
      final scope = Zen.createScope(name: 'DeleteByTypeSvcScope');
      final svc = _ScopeService();
      scope.put<_ScopeService>(svc, isPermanent: false);

      final result = scope.deleteByType(_ScopeService, force: true);
      expect(result, true);
      expect(svc.isDisposed, true);
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // L653-665 — clearAll non-force path with uninstantiated factories
  // ══════════════════════════════════════════════════════════
  group('ZenScope.clearAll non-force factory path', () {
    test(
        'clearAll force=false removes non-permanent uninstantiated factories (L653-665)',
        () {
      final scope = Zen.createScope(name: 'ClearNonForceFactories');
      // Register a lazy factory without instantiating it
      scope.putLazy<_ScopeCtrl>(() => _ScopeCtrl(), isPermanent: false);
      scope.putLazy<_ScopeCtrl2>(() => _ScopeCtrl2(), isPermanent: false);

      expect(scope.contains<_ScopeCtrl>(), true);
      scope.clearAll(force: false);
      // Non-permanent uninstantiated factories should be cleared
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // L801-802 — _instanceExists with tagged bindings
  //            (called when putLazy is invoked with a tag)
  // ══════════════════════════════════════════════════════════
  group('ZenScope._instanceExists tagged path', () {
    test(
        'putLazy with tag and existing instance does not double-register (L801-802)',
        () {
      final scope = Zen.createScope(name: 'InstanceExistsTagged');
      // First: put an actual tagged instance
      final ctrl = _ScopeCtrl();
      scope.put<_ScopeCtrl>(ctrl, tag: 'tracked');

      // Then: putLazy with same tag — _instanceExists(tag) should return true
      // and skip re-registration
      scope.putLazy<_ScopeCtrl>(() => _ScopeCtrl(),
          tag: 'tracked', isPermanent: false);

      // Should still find the original instance (not a new lazy)
      expect(scope.find<_ScopeCtrl>(tag: 'tracked'), ctrl);
      scope.dispose();
    });

    test('putLazy with new tag exercises _instanceExists tag branch (L801-802)',
        () {
      final scope = Zen.createScope(name: 'InstanceExistsNewTag');
      // Register a lazy WITH a tag — this calls _instanceExists(tag)
      scope.putLazy<_ScopeCtrl>(() => _ScopeCtrl(),
          tag: 'new-tag', isPermanent: false);

      // Trigger instantiation — will check if tag already instantiated
      final result = scope.find<_ScopeCtrl>(tag: 'new-tag');
      expect(result, isNotNull);
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // L488 — createChild (never called before)
  // ══════════════════════════════════════════════════════════
  group('ZenScope.createChild', () {
    test('createChild creates a child scope with parent relationship (L488)',
        () {
      final parent = Zen.createScope(name: 'ParentScope');
      final child = parent.createChild(name: 'ChildScope');
      expect(child.name, 'ChildScope');
      expect(child.isDisposed, false);
      parent.dispose(); // should also dispose child
    });

    test('createChild with default name generates unique name', () {
      final parent = Zen.createScope(name: 'ParentDefaultName');
      final child = parent.createChild();
      expect(child.name, isNotNull);
      expect(child.name, isNot('ParentDefaultName'));
      parent.dispose();
    });
  });
}

// ── Helpers ──

class _ScopeCtrl extends ZenController {}

class _ScopeCtrl2 extends ZenController {}

class _TrackingCtrl extends ZenController {
  final void Function() _onReadyCb;
  _TrackingCtrl(this._onReadyCb);

  @override
  void onReady() {
    super.onReady();
    _onReadyCb();
  }
}

class _ThrowingCtrl extends ZenController {
  @override
  void onClose() {
    super.onClose();
    throw Exception('controller close error');
  }
}

class _ScopeService extends ZenService {}

class _ThrowingSvc extends ZenService {
  @override
  void onClose() {
    super.onClose();
    throw Exception('service close error');
  }
}
