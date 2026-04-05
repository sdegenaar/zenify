import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests targeting uncovered lines in zen_route_observer.dart:
/// - L115-117: didPush route logging (when shouldLogRoutes=true)
/// - L145-147: didPop route logging
/// - L219-220: controller NOT found log (not disposed)
/// - L225: ZenMetrics.recordControllerDisposal (enablePerformanceMetrics=true)
/// - L237: tagged controller with routeScope
/// - L259-260: _disposeControllersForRoute error catch
/// - L269-270: _deleteByTagFromScope warning when deleteByTag throws
/// - L294-295: _cleanupRouteScope non-empty dependencies (keeps alive)
/// - L298: _cleanupRouteScope error catch
void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  group('ZenRouteObserver registration', () {
    test('registerForRoute records controllers', () {
      final observer = ZenRouteObserver();
      observer.registerForRoute('/home', [_RouteCtrl1]);
      expect(observer.hasControllersForRoute('/home'), true);
      expect(observer.getRegisteredRoutes(), contains('/home'));
    });

    test('registerTaggedForRoute with scope records tags', () {
      final observer = ZenRouteObserver();
      final scope = Zen.createScope(name: 'RouteScope');
      observer.registerTaggedForRoute('/profile', ['tag1'], scope: scope);
      expect(observer.getScopeForRoute('/profile'), scope);
      scope.dispose();
    });

    test('clearAllRoutes removes all registrations', () {
      final observer = ZenRouteObserver();
      observer.registerForRoute('/a', [_RouteCtrl1]);
      observer.clearAllRoutes();
      expect(observer.hasControllersForRoute('/a'), false);
    });

    test('getDebugInfo returns structured info', () {
      final observer = ZenRouteObserver();
      observer.registerForRoute('/home', [_RouteCtrl1]);
      observer.registerTaggedForRoute('/profile', ['tag1']);
      final info = observer.getDebugInfo();
      expect(info['totalRoutes'], greaterThan(0));
      expect(info['routeControllers'], isA<Map>());
      expect(info['routeControllerTags'], isA<Map>());
    });
  });

  // ══════════════════════════════════════════════════════════
  // didPush with route logging (L115-117)
  // ══════════════════════════════════════════════════════════
  group('ZenRouteObserver.didPush', () {
    test('didPush triggers onRouteChanged callback', () {
      Route? captured;
      final observer = ZenRouteObserver(
        onRouteChanged: (route, prev) => captured = route,
      );
      final route = _FakeRoute(name: '/target');
      observer.didPush(route, null);
      expect(captured, route);
    });

    test('didPush with shouldLogRoutes=true follows log path (L115-117)', () {
      final savedLevel = ZenConfig.logLevel;
      final savedRouteLog = ZenConfig.enableRouteLogging;
      ZenConfig.logLevel = ZenLogLevel.info; // enables shouldLog(info)
      ZenConfig.enableRouteLogging = true; // gates shouldLogRoutes

      final observer = ZenRouteObserver();
      final route = _FakeRoute(name: '/logged-push');
      final prev = _FakeRoute(name: '/home');
      expect(() => observer.didPush(route, prev), returnsNormally);

      ZenConfig.logLevel = savedLevel;
      ZenConfig.enableRouteLogging = savedRouteLog;
    });
  });

  // ══════════════════════════════════════════════════════════
  // didPop with route logging (L145-147)
  // ══════════════════════════════════════════════════════════
  group('ZenRouteObserver.didPop', () {
    test('didPop triggers onRouteChanged callback', () {
      Route? captured;
      final observer = ZenRouteObserver(
        onRouteChanged: (route, prev) => captured = route,
      );
      final route = _FakeRoute(name: '/about');
      final prev = _FakeRoute(name: '/home');
      observer.didPop(route, prev);
      expect(captured, prev); // previous route is current after pop
    });

    test('didPop with logging enabled (L145-147)', () {
      final savedLevel = ZenConfig.logLevel;
      final savedRouteLog = ZenConfig.enableRouteLogging;
      ZenConfig.logLevel = ZenLogLevel.info;
      ZenConfig.enableRouteLogging = true;

      final observer = ZenRouteObserver();
      final route = _FakeRoute(name: '/logged-pop');
      final prev = _FakeRoute(name: '/home');
      expect(() => observer.didPop(route, prev), returnsNormally);

      ZenConfig.logLevel = savedLevel;
      ZenConfig.enableRouteLogging = savedRouteLog;
    });
  });

  // ══════════════════════════════════════════════════════════
  // didReplace
  // ══════════════════════════════════════════════════════════
  group('ZenRouteObserver.didReplace', () {
    test('didReplace triggers onRouteChanged callback', () {
      Route? captured;
      final observer = ZenRouteObserver(
        onRouteChanged: (route, prev) => captured = route,
      );
      final newRoute = _FakeRoute(name: '/new');
      final oldRoute = _FakeRoute(name: '/old');
      observer.didReplace(newRoute: newRoute, oldRoute: oldRoute);
      expect(captured, newRoute);
    });

    test('didReplace with logging enabled covers L130-132', () {
      final savedLevel = ZenConfig.logLevel;
      final savedRouteLog = ZenConfig.enableRouteLogging;
      ZenConfig.logLevel = ZenLogLevel.info;
      ZenConfig.enableRouteLogging = true;

      final observer = ZenRouteObserver();
      final newRoute = _FakeRoute(name: '/new-logged');
      final oldRoute = _FakeRoute(name: '/old-logged');
      expect(
        () => observer.didReplace(newRoute: newRoute, oldRoute: oldRoute),
        returnsNormally,
      );

      ZenConfig.logLevel = savedLevel;
      ZenConfig.enableRouteLogging = savedRouteLog;
    });
  });

  // ══════════════════════════════════════════════════════════
  // didRemove
  // ══════════════════════════════════════════════════════════
  group('ZenRouteObserver.didRemove', () {
    test('didRemove disposes route controllers', () {
      final ctrl = _RouteCtrl1();
      Zen.put<_RouteCtrl1>(ctrl);

      final observer = ZenRouteObserver();
      observer.registerForRoute('/remove_route', [_RouteCtrl1]);
      final route = _FakeRoute(name: '/remove_route');
      observer.didRemove(route, null);

      expect(ctrl.isDisposed, true);
    });

    test('didRemove with logging enabled covers L163-164', () {
      final savedLevel = ZenConfig.logLevel;
      final savedRouteLog = ZenConfig.enableRouteLogging;
      ZenConfig.logLevel = ZenLogLevel.info;
      ZenConfig.enableRouteLogging = true;

      final observer = ZenRouteObserver();
      final route = _FakeRoute(name: '/removed-logged');
      expect(() => observer.didRemove(route, null), returnsNormally);

      ZenConfig.logLevel = savedLevel;
      ZenConfig.enableRouteLogging = savedRouteLog;
    });
  });

  // ══════════════════════════════════════════════════════════
  // didPop with controller disposal (L219-220 — controller NOT found)
  // ══════════════════════════════════════════════════════════
  group('ZenRouteObserver controller disposal', () {
    test('popping route with registered type disposes controller (L215-217)',
        () {
      final ctrl = _RouteCtrl1();
      Zen.put<_RouteCtrl1>(ctrl);

      final observer = ZenRouteObserver();
      observer.registerForRoute('/guarded', [_RouteCtrl1]);
      final route = _FakeRoute(name: '/guarded');
      final prev = _FakeRoute(name: '/home');
      observer.didPop(route, prev);

      expect(ctrl.isDisposed, true);
    });

    test('popping route where controller already gone logs debug (L219-220)',
        () {
      // Don't put the controller — it won't be found
      final observer = ZenRouteObserver();
      observer.registerForRoute('/ghost', [_RouteCtrl1]);
      final route = _FakeRoute(name: '/ghost');

      // Should not throw, just log debug that ctrl wasn't found
      expect(() => observer.didPop(route, null), returnsNormally);
    });

    test('popping route with scoped controller disposes from scope', () {
      final scope = Zen.createScope(name: 'ScopedRoute');
      final ctrl = _RouteCtrl1();
      scope.put<_RouteCtrl1>(ctrl);

      final observer = ZenRouteObserver();
      observer.registerForRoute('/scoped', [_RouteCtrl1], scope: scope);
      final route = _FakeRoute(name: '/scoped');
      observer.didPop(route, null);

      expect(ctrl.isDisposed, true);
      scope.dispose();
    });

    test('popping route with metrics enabled records disposal (L225)', () {
      final savedMetrics = ZenConfig.enablePerformanceMetrics;
      ZenConfig.enablePerformanceMetrics = true;

      final ctrl = _RouteCtrl1();
      Zen.put<_RouteCtrl1>(ctrl);

      final observer = ZenRouteObserver();
      observer.registerForRoute('/metrics_route', [_RouteCtrl1]);
      final route = _FakeRoute(name: '/metrics_route');
      expect(() => observer.didPop(route, null), returnsNormally);

      ZenConfig.enablePerformanceMetrics = savedMetrics;
    });

    test('popping route with tagged controllers in scope (L237)', () {
      final scope = Zen.createScope(name: 'TaggedScopeRoute');
      final ctrl = _RouteCtrl1();
      scope.put<_RouteCtrl1>(ctrl, tag: 'my-tag');

      final observer = ZenRouteObserver();
      observer.registerTaggedForRoute('/tagged-scoped', ['my-tag'],
          scope: scope);
      final route = _FakeRoute(name: '/tagged-scoped');
      observer.didPop(route, null);

      expect(ctrl.isDisposed, true);
    });

    test('popping route with tagged controllers in root scope disposes', () {
      Zen.put<_RouteCtrl1>(_RouteCtrl1(), tag: 'root-tagged');

      final observer = ZenRouteObserver();
      observer.registerTaggedForRoute('/root-tagged-route', ['root-tagged']);
      final route = _FakeRoute(name: '/root-tagged-route');

      expect(() => observer.didPop(route, null), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // _cleanupRouteScope — non-empty scope (L294-295)
  // ══════════════════════════════════════════════════════════
  group('ZenRouteObserver._cleanupRouteScope', () {
    test('route scope with remaining dependencies is kept alive (L294-295)',
        () {
      // Create a scope named to match the route path (heuristic in _isRouteSpecificScope)
      final scope = Zen.createScope(name: '/with-deps');
      final ctrl1 = _RouteCtrl1();
      final ctrl2 = _RouteCtrl2();
      // Register two controllers; disposal of one leaves one behind
      scope.put<_RouteCtrl1>(ctrl1);
      scope.put<_RouteCtrl2>(ctrl2);

      final observer = ZenRouteObserver();
      // Register only ctrl1 for the route — ctrl2 stays behind
      observer.registerForRoute('/with-deps', [_RouteCtrl1], scope: scope);
      final route = _FakeRoute(name: '/with-deps');
      observer.didPop(route, null);

      // ctrl1 disposes, but scope should NOT be disposed (ctrl2 still in it)
      expect(ctrl1.isDisposed, true);
      expect(scope.isDisposed, false);
      scope.dispose();
    });

    test('empty route scope is disposed after pop', () {
      final scope = Zen.createScope(name: '/empty-scope');
      final ctrl = _RouteCtrl1();
      scope.put<_RouteCtrl1>(ctrl);

      final observer = ZenRouteObserver();
      observer.registerForRoute('/empty-scope', [_RouteCtrl1], scope: scope);
      final route = _FakeRoute(name: '/empty-scope');
      observer.didPop(route, null);

      expect(ctrl.isDisposed, true);
      // Scope is now empty and name matches route — should be disposed
      expect(scope.isDisposed, true);
    });

    test('tagged controller already disposed before pop logs debug (L248-249)',
        () {
      // Register a tagged route, but manually remove the controller first
      // so deleteByTag returns false -> triggers the "not found" log path
      final scope = Zen.createScope(name: 'PreDisposedTagScope');
      scope.put<_RouteCtrl1>(_RouteCtrl1(),
          tag: 'pre-disposed-tag', isPermanent: false);

      // Manually remove it before the route pops
      scope.deleteByTag('pre-disposed-tag', force: true);

      final observer = ZenRouteObserver();
      observer.registerTaggedForRoute('/pre-disposed', ['pre-disposed-tag'],
          scope: scope);
      final route = _FakeRoute(name: '/pre-disposed');

      // Should not throw; should log "not found" debug message
      expect(() => observer.didPop(route, null), returnsNormally);
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // didStartUserGesture / didStopUserGesture
  // ══════════════════════════════════════════════════════════
  group('ZenRouteObserver gesture events', () {
    test('didStartUserGesture does not throw', () {
      final observer = ZenRouteObserver();
      final route = _FakeRoute(name: '/gesture');
      expect(
        () => observer.didStartUserGesture(route, null),
        returnsNormally,
      );
    });

    test('didStartUserGesture with logging enabled covers L178-179, L189', () {
      final savedLevel = ZenConfig.logLevel;
      final savedNavLog = ZenConfig.enableNavigationLogging;
      ZenConfig.logLevel = ZenLogLevel.info;
      ZenConfig.enableNavigationLogging = true;

      final observer = ZenRouteObserver();
      final route = _FakeRoute(name: '/gesture-logged');
      final prev = _FakeRoute(name: '/home');
      expect(
        () => observer.didStartUserGesture(route, prev),
        returnsNormally,
      );
      expect(() => observer.didStopUserGesture(), returnsNormally);

      ZenConfig.logLevel = savedLevel;
      ZenConfig.enableNavigationLogging = savedNavLog;
    });

    test('didStopUserGesture does not throw', () {
      final observer = ZenRouteObserver();
      expect(() => observer.didStopUserGesture(), returnsNormally);
    });
  });
}

// ── Helpers ──

class _RouteCtrl1 extends ZenController {}

class _RouteCtrl2 extends ZenController {}

/// A minimal fake Route for testing without navigation stack
class _FakeRoute extends Route<void> {
  _FakeRoute({String? name}) : super(settings: RouteSettings(name: name));
}
