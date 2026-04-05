import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() => Zen.init());
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // RxTester
  // ══════════════════════════════════════════════════════════
  group('RxTester', () {
    test('starts with empty changes', () {
      final rx = 0.obs();
      final tester = RxTester(rx);
      expect(tester.changes, isEmpty);
      expect(tester.hasChanged, false);
      expect(tester.lastValue, isNull);
      tester.dispose();
    });

    test('records changes on value update', () {
      final rx = 0.obs();
      final tester = RxTester(rx);
      rx.value = 1;
      rx.value = 2;
      expect(tester.changes, [1, 2]);
      tester.dispose();
    });

    test('hasChanged is true after first change', () {
      final rx = 0.obs();
      final tester = RxTester(rx);
      rx.value = 5;
      expect(tester.hasChanged, true);
      tester.dispose();
    });

    test('lastValue returns most recent change', () {
      final rx = 0.obs();
      final tester = RxTester(rx);
      rx.value = 1;
      rx.value = 99;
      expect(tester.lastValue, 99);
      tester.dispose();
    });

    test('reset clears changes', () {
      final rx = 0.obs();
      final tester = RxTester(rx);
      rx.value = 5;
      tester.reset();
      expect(tester.changes, isEmpty);
      tester.dispose();
    });

    test('expectChanges returns true for matching list', () {
      final rx = 0.obs();
      final tester = RxTester(rx);
      rx.value = 1;
      rx.value = 2;
      expect(tester.expectChanges([1, 2]), true);
      tester.dispose();
    });

    test('expectChanges returns false for wrong length', () {
      final rx = 0.obs();
      final tester = RxTester(rx);
      rx.value = 1;
      expect(tester.expectChanges([1, 2]), false);
      tester.dispose();
    });

    test('expectChanges returns false for wrong values', () {
      final rx = 0.obs();
      final tester = RxTester(rx);
      rx.value = 1;
      rx.value = 2;
      expect(tester.expectChanges([1, 99]), false);
      tester.dispose();
    });

    test('dispose stops recording further changes', () {
      final rx = 0.obs();
      final tester = RxTester(rx);
      rx.value = 1;
      tester.dispose();
      rx.value = 2; // not recorded
      expect(tester.changes, [1]);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenTestContainer
  // ══════════════════════════════════════════════════════════
  group('ZenTestContainer', () {
    late ZenTestContainer container;

    setUp(() => container = ZenTestContainer(name: 'UnitTest'));
    tearDown(() {
      if (!container.isDisposed) container.dispose();
    });

    test('put and find round-trip', () {
      container.put<_Service>(_Service('A'));
      final found = container.find<_Service>();
      expect(found?.label, 'A');
    });

    test('find returns null when not registered', () {
      expect(container.find<_Service>(), isNull);
    });

    test('get returns instance when registered', () {
      container.put<_Service>(_Service('B'));
      expect(container.get<_Service>().label, 'B');
    });

    test('get throws when not registered', () {
      expect(() => container.get<_Other>(), throwsException);
    });

    test('exists returns false before registration', () {
      expect(container.exists<_Service>(), false);
    });

    test('exists returns true after registration', () {
      container.put<_Service>(_Service('C'));
      expect(container.exists<_Service>(), true);
    });

    test('delete removes instance', () {
      container.put<_Service>(_Service('D'));
      expect(container.delete<_Service>(), true);
      expect(container.exists<_Service>(), false);
    });

    test('delete returns false when not registered', () {
      expect(container.delete<_Other>(), false);
    });

    test('putLazy registers factory', () {
      container.putLazy<_Service>(() => _Service('lazy'));
      expect(container.find<_Service>()?.label, 'lazy');
    });

    test('getAllDependencies returns registered instances', () {
      container.put<_Service>(_Service('X'));
      expect(container.getAllDependencies().length, greaterThan(0));
    });

    test('clear disposes controllers and removes dependencies', () {
      final ctrl = _TestCtrl();
      container.put<_TestCtrl>(ctrl);
      container.clear();
      // After clear, the dependencies list should be empty
      expect(container.getAllDependencies(), isEmpty);
    });

    test('isDisposed is false initially', () {
      expect(container.isDisposed, false);
    });

    test('dispose marks container as disposed', () {
      container.dispose();
      expect(container.isDisposed, true);
    });

    test('scope is accessible', () {
      expect(container.scope, isNotNull);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenTestUtils
  // ══════════════════════════════════════════════════════════
  group('ZenTestUtils', () {
    test('createTestEnvironment returns a container', () {
      final c = ZenTestUtils.createTestEnvironment(name: 'TestEnv');
      expect(c, isA<ZenTestContainer>());
      expect(c.isDisposed, false);
      c.dispose();
    });

    test('createTestEnvironment calls setup callback', () {
      var called = false;
      final c = ZenTestUtils.createTestEnvironment(
        setup: (_) => called = true,
      );
      expect(called, true);
      c.dispose();
    });

    test('runInTestEnvironment disposes container after test', () async {
      late ZenTestContainer captured;
      await ZenTestUtils.runInTestEnvironment((c) async {
        captured = c;
        return 42;
      });
      expect(captured.isDisposed, true);
    });

    test('runInTestEnvironment returns test result', () async {
      final result = await ZenTestUtils.runInTestEnvironment((c) async {
        return 'done';
      });
      expect(result, 'done');
    });

    test('pump completes without error', () async {
      await expectLater(ZenTestUtils.pump(), completes);
    });

    test('wait completes after duration', () async {
      final before = DateTime.now();
      await ZenTestUtils.wait(const Duration(milliseconds: 20));
      expect(DateTime.now().difference(before).inMilliseconds, greaterThan(15));
    });

    test('createMockController registers and returns controller', () async {
      final c = ZenTestUtils.createTestEnvironment(name: 'CtrlTest');
      final ctrl =
          ZenTestUtils.createMockController<_TestCtrl>(() => _TestCtrl(), c);
      expect(ctrl, isNotNull);
      expect(c.find<_TestCtrl>(), same(ctrl));
      c.dispose();
    });

    test('verifyReactiveChanges returns true when changes match', () async {
      final rx = 0.obs();
      final result = await ZenTestUtils.verifyReactiveChanges(
        rx,
        [1, 2],
        () async {
          rx.value = 1;
          rx.value = 2;
        },
      );
      expect(result, true);
    });

    test('verifyReactiveChanges returns false when changes dont match',
        () async {
      final rx = 0.obs();
      final result = await ZenTestUtils.verifyReactiveChanges(
        rx,
        [1, 99],
        () async {
          rx.value = 1;
          rx.value = 2;
        },
      );
      expect(result, false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenTestController
  // ══════════════════════════════════════════════════════════
  group('ZenTestController', () {
    late _TrackingCtrl ctrl;

    setUp(() => ctrl = _TrackingCtrl());
    tearDown(() {
      if (!ctrl.isDisposed) ctrl.dispose();
    });

    test('trackCall records method names', () {
      ctrl.trackCall('load');
      ctrl.trackCall('save');
      expect(ctrl.methodCalls, ['load', 'save']);
    });

    test('clearCallHistory empties method calls', () {
      ctrl.trackCall('load');
      ctrl.clearCallHistory();
      expect(ctrl.methodCalls, isEmpty);
    });

    test('wasMethodCalled returns true when method was called', () {
      ctrl.trackCall('doSomething');
      expect(ctrl.wasMethodCalled('doSomething'), true);
    });

    test('wasMethodCalled returns false when method was not called', () {
      expect(ctrl.wasMethodCalled('never'), false);
    });

    test('getCallCount returns correct count', () {
      ctrl.trackCall('fetch');
      ctrl.trackCall('fetch');
      ctrl.trackCall('save');
      expect(ctrl.getCallCount('fetch'), 2);
      expect(ctrl.getCallCount('save'), 1);
      expect(ctrl.getCallCount('never'), 0);
    });
  });
}

class _Service {
  final String label;
  _Service(this.label);
}

class _Other {}

class _TestCtrl extends ZenController {}

class _TrackingCtrl extends ZenTestController {}
