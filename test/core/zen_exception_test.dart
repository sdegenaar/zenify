import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  group('ZenException System', () {
    setUp(() {
      // Reset config before each test
      ZenConfig.verboseErrors = false;
    });

    group('Exception Types', () {
      test('ZenDependencyNotFoundException has correct properties', () {
        final exception = ZenDependencyNotFoundException(
          typeName: 'UserService',
          scopeName: 'RootScope',
          tag: 'auth',
        );

        expect(exception, isA<ZenException>());
        expect(exception, isA<Exception>());
        expect(exception.message, 'Dependency not found');
        expect(exception.context?['Type'], 'UserService');
        expect(exception.context?['Scope'], 'RootScope');
        expect(exception.context?['Tag'], 'auth');
        expect(exception.suggestion, contains('Zen.put'));
        expect(exception.icon, '❌');
        expect(exception.category, 'DI');
      });

      test('ZenControllerNotFoundException has correct properties', () {
        final exception = ZenControllerNotFoundException(
          typeName: 'LoginController',
        );

        expect(exception, isA<ZenException>());
        expect(exception.context?['Type'], 'LoginController');
        expect(exception.suggestion, contains('createController'));
        expect(exception.icon, '🎮');
        expect(exception.category, 'Controller');
      });

      test('ZenScopeNotFoundException has correct properties', () {
        final exception = ZenScopeNotFoundException(
          widgetType: 'ZenRoute',
        );

        expect(exception, isA<ZenException>());
        expect(exception.context?['Widget'], 'ZenRoute');
        expect(exception.suggestion, contains('ZenScope'));
        expect(exception.icon, '🔍');
        expect(exception.category, 'Scope');
      });

      test('ZenDisposedScopeException has correct properties', () {
        final exception = ZenDisposedScopeException(
          scopeName: 'TestScope',
          operation: 'put',
        );

        expect(exception, isA<ZenException>());
        expect(exception.context?['Scope'], 'TestScope');
        expect(exception.context?['Operation'], 'put');
        expect(exception.icon, '🔒');
        expect(exception.category, 'Scope');
      });

      test('ZenOfflineException has correct properties', () {
        const exception = ZenOfflineException();

        expect(exception, isA<ZenException>());
        expect(exception.message, 'No internet connection');
        expect(exception.suggestion, contains('network'));
        expect(exception.icon, '📶');
        expect(exception.category, 'Network');
      });

      test('ZenCircularDependencyException has correct properties', () {
        final exception = ZenCircularDependencyException(
          typeName: 'ServiceA',
          dependencyChain: ['ServiceA', 'ServiceB', 'ServiceC', 'ServiceA'],
        );

        expect(exception, isA<ZenException>());
        expect(exception.context?['Type'], 'ServiceA');
        expect(exception.context?['Chain'], contains('→'));
        expect(exception.icon, '🔄');
        expect(exception.category, 'DI');
      });
    });

    group('Formatting', () {
      test('Compact format is used by default', () {
        ZenConfig.verboseErrors = false;
        final exception = ZenDependencyNotFoundException(
          typeName: 'TestService',
          scopeName: 'TestScope',
        );

        final output = exception.toString();

        // Should be compact (few lines)
        expect(output, contains('❌'));
        expect(output, contains('TestService'));
        expect(output, contains('TestScope'));
        expect(output, contains('💡'));
        expect(output.split('\n').length, lessThan(5));

        // Should NOT contain box characters
        expect(output, isNot(contains('╔')));
        expect(output, isNot(contains('╚')));
      });

      test('Verbose format is used when enabled', () {
        ZenConfig.verboseErrors = true;
        final exception = ZenDependencyNotFoundException(
          typeName: 'TestService',
          scopeName: 'TestScope',
        );

        final output = exception.toString();

        // Should be verbose (many lines with box)
        expect(output, contains('╔'));
        expect(output, contains('╠'));
        expect(output, contains('╚'));
        expect(output, contains('TestService'));
        expect(output, contains('TestScope'));
        expect(output.split('\n').length, greaterThan(5));
      });

      test('Compact format includes suggestion on new line', () {
        ZenConfig.verboseErrors = false;
        final exception = ZenDependencyNotFoundException(
          typeName: 'UserService',
          scopeName: 'RootScope',
        );

        final output = exception.toString();
        final lines = output.split('\n');

        // First line: main error
        expect(lines[0], contains('❌'));
        expect(lines[0], contains('ZenDependencyNotFoundException'));

        // Second line: suggestion
        expect(lines[1], contains('💡'));
        expect(lines[1], contains('Zen.put'));
      });

      test('Verbose format includes all sections', () {
        ZenConfig.verboseErrors = true;
        final exception = ZenDependencyNotFoundException(
          typeName: 'UserService',
          scopeName: 'RootScope',
          tag: 'auth',
        );

        final output = exception.toString();

        // Should contain all sections
        expect(output, contains('Dependency not found'));
        expect(output, contains('Type: UserService'));
        expect(output, contains('Scope: RootScope'));
        expect(output, contains('Tag: auth'));
        expect(output, contains('💡 Suggestion:'));
        expect(output, contains('📚 Learn more:'));
      });
    });

    group('Context Fields', () {
      test('Exception with cause includes cause information', () {
        final cause = Exception('Network timeout');
        final exception = ZenQueryException(
          'Failed to fetch data',
          cause: cause,
        );

        expect(exception.cause, same(cause));

        final output = exception.toString();
        expect(output, contains('Network timeout'));
      });

      test('Exception with doc link includes link', () {
        final exception = ZenDependencyNotFoundException(
          typeName: 'TestService',
          scopeName: 'TestScope',
        );

        expect(exception.docLink, isNotNull);
        // Currently uses GitHub until zenify.dev is set up
        expect(exception.docLink, contains('github.com/sdegenaar/zenify'));
      });

      test('Exception without optional fields works correctly', () {
        final exception = ZenModuleException('Module failed to load');

        expect(exception.message, 'Module failed to load');
        expect(exception.context, isNull);
        expect(exception.suggestion, isNull);
        expect(exception.icon, '📦');
        expect(exception.category, 'Module');
      });
    });

    group('Integration', () {
      test('Zen.find throws ZenDependencyNotFoundException', () {
        Zen.reset();

        expect(
          () => Zen.find<_UnregisteredTestService>(),
          throwsA(isA<ZenDependencyNotFoundException>()),
        );
      });

      test('Exception from Zen.find has correct context', () {
        Zen.reset();

        try {
          Zen.find<_UnregisteredTestService>(tag: 'test');
          fail('Should have thrown');
        } on ZenDependencyNotFoundException catch (e) {
          expect(e.context?['Type'], contains('_UnregisteredTestService'));
          expect(e.context?['Scope'], 'RootScope');
          expect(e.context?['Tag'], 'test');
        }
      });

      test('ZenScope.findRequired throws ZenDependencyNotFoundException', () {
        final scope = ZenScope(name: 'TestScope');

        expect(
          () => scope.findRequired<_UnregisteredTestService>(),
          throwsA(isA<ZenDependencyNotFoundException>()),
        );

        scope.dispose();
      });

      test('Disposed scope throws ZenDisposedScopeException', () {
        final scope = ZenScope(name: 'TestScope');
        scope.dispose();

        expect(
          () => scope.put(_UnregisteredTestService()),
          throwsA(isA<ZenDisposedScopeException>()),
        );
      });
    });

    group('Logger Integration', () {
      test('ZenLogger.logException accepts ZenException', () {
        final exception = ZenDependencyNotFoundException(
          typeName: 'TestService',
          scopeName: 'TestScope',
        );

        // Should not throw
        expect(
          () => ZenLogger.logException(exception),
          returnsNormally,
        );
      });

      test('ZenLogger.logException accepts generic Exception', () {
        final exception = Exception('Generic error');

        // Should not throw
        expect(
          () => ZenLogger.logException(exception),
          returnsNormally,
        );
      });
    });
  });
}

// Test service for integration tests
class _UnregisteredTestService {}
