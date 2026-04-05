import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  tearDown(() {
    ZenConfig.verboseErrors = false;
    ZenConfig.reset();
  });

  // ══════════════════════════════════════════════════════════
  // ZenException compact format (_toStringCompact)
  // ══════════════════════════════════════════════════════════
  group('ZenException compact format', () {
    test('message only', () {
      final ex = _SimpleException('something went wrong');
      final str = ex.toString();
      expect(str, contains('something went wrong'));
      expect(str, contains('⭐'));
    });

    test('with context entries', () {
      final ex = _SimpleException(
        'not found',
        context: {'Type': 'MyService', 'Scope': 'Root'},
      );
      final str = ex.toString();
      expect(str, contains('Type=MyService'));
      expect(str, contains('Scope=Root'));
    });

    test('with suggestion on new line', () {
      final ex = _SimpleException('bad', suggestion: 'Do X instead');
      final str = ex.toString();
      expect(str, contains('💡'));
      expect(str, contains('Do X instead'));
    });

    test('with docLink on new line', () {
      final ex = _SimpleException('bad', docLink: 'https://example.com/docs');
      final str = ex.toString();
      expect(str, contains('📚'));
      expect(str, contains('https://example.com/docs'));
    });

    test('with cause shows runtimeType and message', () {
      final root = Exception('root cause');
      final ex = _SimpleException('wrapper', cause: root);
      final str = ex.toString();
      expect(str, contains('Caused by'));
      expect(str, contains('root cause'));
    });

    test('with all fields', () {
      final ex = _SimpleException(
        'full error',
        context: {'K': 'V'},
        suggestion: 'Fix it',
        docLink: 'https://docs.example.com',
        cause: Exception('inner'),
      );
      final str = ex.toString();
      expect(str, contains('full error'));
      expect(str, contains('K=V'));
      expect(str, contains('Fix it'));
      expect(str, contains('https://docs.example.com'));
      expect(str, contains('inner'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenException verbose format (_toStringVerbose)
  // ══════════════════════════════════════════════════════════
  group('ZenException verbose format', () {
    setUp(() => ZenConfig.verboseErrors = true);

    test('produces boxed output with box chars', () {
      final ex = _SimpleException('verbose error');
      final str = ex.toString();
      expect(str, contains('╔'));
      expect(str, contains('╚'));
      expect(str, contains('verbose error'));
    });

    test('includes icon and runtimeType in header', () {
      final ex = _SimpleException('msg');
      final str = ex.toString();
      expect(str, contains('⭐'));
      expect(str, contains('_SimpleException'));
    });

    test('verbose includes context block', () {
      final ex = _SimpleException(
        'no data',
        context: {'Type': 'FooService', 'Scope': 'ChildScope'},
      );
      final str = ex.toString();
      expect(str, contains('FooService'));
      expect(str, contains('ChildScope'));
    });

    test('verbose includes suggestion block', () {
      final ex = _SimpleException('broken', suggestion: 'Call init()');
      final str = ex.toString();
      expect(str, contains('Suggestion'));
      expect(str, contains('Call init()'));
    });

    test('verbose includes docLink block', () {
      final ex =
          _SimpleException('broken', docLink: 'https://example.com/guide');
      final str = ex.toString();
      expect(str, contains('📚'));
      expect(str, contains('https://example.com/guide'));
    });

    test('verbose includes cause block', () {
      final cause = Exception('underlying');
      final ex = _SimpleException('wrapper', cause: cause);
      final str = ex.toString();
      expect(str, contains('Caused by'));
    });

    test('wraps long message text across multiple lines', () {
      final longMsg =
          'This is a very long error message that should be wrapped across multiple lines when displayed in verbose mode to ensure it fits within the box';
      final ex = _SimpleException(longMsg);
      final str = ex.toString();
      expect(str, contains('║'));
      // Should contain the first part of the message
      expect(str, contains('This is a very long'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenDependencyNotFoundException
  // ══════════════════════════════════════════════════════════
  group('ZenDependencyNotFoundException', () {
    test('icon is ❌', () {
      final ex =
          ZenDependencyNotFoundException(typeName: 'T', scopeName: 'Root');
      expect(ex.icon, '❌');
    });

    test('category is DI', () {
      final ex =
          ZenDependencyNotFoundException(typeName: 'T', scopeName: 'Root');
      expect(ex.category, 'DI');
    });

    test('includes typeName and scopeName in toString', () {
      final ex = ZenDependencyNotFoundException(
          typeName: 'UserService', scopeName: 'AppScope');
      expect(ex.toString(), contains('UserService'));
      expect(ex.toString(), contains('AppScope'));
    });

    test('includes tag when provided', () {
      final ex = ZenDependencyNotFoundException(
          typeName: 'T', scopeName: 'Root', tag: 'premium');
      expect(ex.toString(), contains('premium'));
    });

    test('suggestion includes tag when provided', () {
      final ex = ZenDependencyNotFoundException(
          typeName: 'T', scopeName: 'Root', tag: 'premium');
      final str = ex.toString();
      expect(str, contains("tag: 'premium'"));
    });

    test('suggestion without tag', () {
      final ex = ZenDependencyNotFoundException(
          typeName: 'MyService', scopeName: 'Root');
      final str = ex.toString();
      expect(str, contains('Zen.put(MyService())'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // Other specific exception types — icon, category, toString
  // ══════════════════════════════════════════════════════════
  group('ZenScopeException', () {
    test('icon and category', () {
      final ex = ZenScopeException('scope problem');
      expect(ex.icon, '🔒');
      expect(ex.category, 'Scope');
      expect(ex.toString(), contains('scope problem'));
    });
  });

  group('ZenControllerNotFoundException', () {
    test('icon and category', () {
      final ex = ZenControllerNotFoundException(typeName: 'HomeController');
      expect(ex.icon, '🎮');
      expect(ex.category, 'Controller');
      expect(ex.toString(), contains('HomeController'));
    });
  });

  group('ZenQueryException', () {
    test('icon and category', () {
      final ex = ZenQueryException('query failed');
      expect(ex.icon, '🔍');
      expect(ex.category, 'Query');
    });

    test('with cause', () {
      final ex = ZenQueryException('fail', cause: Exception('network'));
      expect(ex.toString(), contains('network'));
    });
  });

  group('ZenMutationException', () {
    test('icon and category', () {
      final ex = ZenMutationException('mutation failed');
      expect(ex.icon, '✏️');
      expect(ex.category, 'Mutation');
    });
  });

  group('ZenCircularDependencyException', () {
    test('icon and category', () {
      final ex = ZenCircularDependencyException(
        typeName: 'A',
        dependencyChain: ['A', 'B', 'A'],
      );
      expect(ex.icon, '🔄');
      expect(ex.category, 'DI');
    });

    test('includes chain in toString', () {
      final ex = ZenCircularDependencyException(
        typeName: 'A',
        dependencyChain: ['A', 'B', 'C', 'A'],
      );
      expect(ex.toString(), contains('→'));
    });
  });

  group('ZenDisposedScopeException', () {
    test('icon and category', () {
      final ex =
          ZenDisposedScopeException(scopeName: 'MyScope', operation: 'put');
      expect(ex.icon, '🔒');
      expect(ex.category, 'Scope');
      expect(ex.toString(), contains('MyScope'));
      expect(ex.toString(), contains('put'));
    });
  });

  group('ZenScopeNotFoundException', () {
    test('icon and category', () {
      final ex = ZenScopeNotFoundException();
      expect(ex.icon, '🔍');
      expect(ex.category, 'Scope');
    });

    test('includes widget type when provided', () {
      final ex = ZenScopeNotFoundException(widgetType: 'LoginPage');
      expect(ex.toString(), contains('LoginPage'));
    });

    test('works without widget type', () {
      final ex = ZenScopeNotFoundException();
      expect(ex.toString(), isNotEmpty);
    });
  });

  group('ZenControllerDisposedException', () {
    test('icon and category', () {
      final ex = ZenControllerDisposedException(typeName: 'AuthController');
      expect(ex.icon, '🎮');
      expect(ex.category, 'Controller');
      expect(ex.toString(), contains('AuthController'));
    });
  });

  group('ZenModuleException', () {
    test('icon and category', () {
      final ex = ZenModuleException('module problem');
      expect(ex.icon, '📦');
      expect(ex.category, 'Module');
    });
  });

  group('ZenLifecycleException', () {
    test('icon and category', () {
      final ex = ZenLifecycleException('lifecycle problem');
      expect(ex.icon, '♻️');
      expect(ex.category, 'Lifecycle');
    });
  });

  group('ZenRouteException', () {
    test('icon and category', () {
      final ex = ZenRouteException('route error');
      expect(ex.icon, '🛣️');
      expect(ex.category, 'Route');
    });
  });
}

// ── Concrete subclass for testing abstract ZenException ──
class _SimpleException extends ZenException {
  const _SimpleException(
    super.message, {
    super.context,
    super.suggestion,
    super.docLink,
    super.cause,
  });

  @override
  String get icon => '⭐';

  @override
  String get category => 'Test';
}
