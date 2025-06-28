
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    // Clear the stack before each test
    ZenScopeStackTracker.clear();
    // Initialize Zen for scope manager tests
    Zen.init();
  });

  tearDown(() {
    // Clean up after each test
    ZenScopeStackTracker.clear();
    Zen.reset();
  });

  group('ZenScopeStackTracker', () {
    group('Basic Stack Operations', () {
      test('should start with empty stack', () {
        expect(ZenScopeStackTracker.getCurrentStack(), isEmpty);
        expect(ZenScopeStackTracker.getCurrentScope(), isNull);
      });

      test('should push scope to stack', () {
        ZenScopeStackTracker.pushScope('scope1');

        expect(ZenScopeStackTracker.getCurrentStack(), equals(['scope1']));
        expect(ZenScopeStackTracker.getCurrentScope(), equals('scope1'));
        expect(ZenScopeStackTracker.isActive('scope1'), isTrue);
      });

      test('should push multiple scopes in order', () {
        ZenScopeStackTracker.pushScope('scope1');
        ZenScopeStackTracker.pushScope('scope2');
        ZenScopeStackTracker.pushScope('scope3');

        expect(ZenScopeStackTracker.getCurrentStack(), equals(['scope1', 'scope2', 'scope3']));
        expect(ZenScopeStackTracker.getCurrentScope(), equals('scope3'));
      });

      test('should pop scope from stack', () {
        ZenScopeStackTracker.pushScope('scope1');
        ZenScopeStackTracker.pushScope('scope2');

        ZenScopeStackTracker.popScope('scope1');

        expect(ZenScopeStackTracker.getCurrentStack(), equals(['scope2']));
        expect(ZenScopeStackTracker.isActive('scope1'), isFalse);
        expect(ZenScopeStackTracker.isActive('scope2'), isTrue);
      });

      test('should handle popping non-existent scope gracefully', () {
        ZenScopeStackTracker.pushScope('scope1');

        ZenScopeStackTracker.popScope('nonexistent');

        expect(ZenScopeStackTracker.getCurrentStack(), equals(['scope1']));
      });

      test('should clear entire stack', () {
        ZenScopeStackTracker.pushScope('scope1');
        ZenScopeStackTracker.pushScope('scope2');
        ZenScopeStackTracker.pushScope('scope3');

        ZenScopeStackTracker.clear();

        expect(ZenScopeStackTracker.getCurrentStack(), isEmpty);
        expect(ZenScopeStackTracker.getCurrentScope(), isNull);
      });
    });

    group('Parent Resolution', () {
      test('should return null parent for first scope', () {
        ZenScopeStackTracker.pushScope('scope1');

        expect(ZenScopeStackTracker.getParentScope('scope1'), isNull);
      });

      test('should return correct parent for nested scopes', () {
        ZenScopeStackTracker.pushScope('root');
        ZenScopeStackTracker.pushScope('parent');
        ZenScopeStackTracker.pushScope('child');

        expect(ZenScopeStackTracker.getParentScope('root'), isNull);
        expect(ZenScopeStackTracker.getParentScope('parent'), equals('root'));
        expect(ZenScopeStackTracker.getParentScope('child'), equals('parent'));
      });

      test('should return null for non-existent scope', () {
        ZenScopeStackTracker.pushScope('scope1');

        expect(ZenScopeStackTracker.getParentScope('nonexistent'), isNull);
      });

      test('should handle complex hierarchy correctly', () {
        ZenScopeStackTracker.pushScope('app');
        ZenScopeStackTracker.pushScope('feature');
        ZenScopeStackTracker.pushScope('page');
        ZenScopeStackTracker.pushScope('dialog');

        expect(ZenScopeStackTracker.getParentScope('app'), isNull);
        expect(ZenScopeStackTracker.getParentScope('feature'), equals('app'));
        expect(ZenScopeStackTracker.getParentScope('page'), equals('feature'));
        expect(ZenScopeStackTracker.getParentScope('dialog'), equals('page'));
      });
    });

    group('Creation Time Tracking', () {
      test('should track creation times', () {
        final beforePush = DateTime.now();
        ZenScopeStackTracker.pushScope('scope1');
        final afterPush = DateTime.now();

        final creationTime = ZenScopeStackTracker.getCreationTime('scope1');

        expect(creationTime, isNotNull);
        expect(creationTime!.isAfter(beforePush.subtract(const Duration(milliseconds: 1))), isTrue);
        expect(creationTime.isBefore(afterPush.add(const Duration(milliseconds: 1))), isTrue);
      });

      test('should remove creation time when scope is popped', () {
        ZenScopeStackTracker.pushScope('scope1');
        expect(ZenScopeStackTracker.getCreationTime('scope1'), isNotNull);

        ZenScopeStackTracker.popScope('scope1');
        expect(ZenScopeStackTracker.getCreationTime('scope1'), isNull);
      });

      test('should clear creation times when stack is cleared', () {
        ZenScopeStackTracker.pushScope('scope1');
        ZenScopeStackTracker.pushScope('scope2');

        ZenScopeStackTracker.clear();

        expect(ZenScopeStackTracker.getCreationTime('scope1'), isNull);
        expect(ZenScopeStackTracker.getCreationTime('scope2'), isNull);
      });
    });

    group('Stack Management Edge Cases', () {
      test('should handle duplicate scope names by moving to top', () {
        ZenScopeStackTracker.pushScope('scope1');
        ZenScopeStackTracker.pushScope('scope2');
        ZenScopeStackTracker.pushScope('scope1'); // Duplicate

        expect(ZenScopeStackTracker.getCurrentStack(), equals(['scope2', 'scope1']));
        expect(ZenScopeStackTracker.getCurrentScope(), equals('scope1'));
      });

      test('should handle rapid push/pop operations', () {
        for (int i = 0; i < 100; i++) {
          ZenScopeStackTracker.pushScope('scope$i');
        }

        expect(ZenScopeStackTracker.getCurrentStack().length, equals(100));

        for (int i = 99; i >= 0; i--) {
          ZenScopeStackTracker.popScope('scope$i');
        }

        expect(ZenScopeStackTracker.getCurrentStack(), isEmpty);
      });

      test('should handle empty scope names', () {
        ZenScopeStackTracker.pushScope('');

        expect(ZenScopeStackTracker.getCurrentStack(), equals(['']));
        expect(ZenScopeStackTracker.isActive(''), isTrue);
      });
    });

    group('Integration with ZenScopeManager', () {
      test('should return actual scope instance for parent', () {
        // Create scopes in the manager
        final parentScope = ZenScopeManager.getOrCreateScope(name: 'parent');
        final childScope = ZenScopeManager.getOrCreateScope(name: 'child');

        // Set up stack hierarchy
        ZenScopeStackTracker.pushScope('parent');
        ZenScopeStackTracker.pushScope('child');

        final resolvedParent = ZenScopeStackTracker.getParentScopeInstance('child');

        expect(resolvedParent, equals(parentScope));
        expect(resolvedParent, isNot(equals(childScope)));
      });

      test('should return null when parent scope is disposed', () {
        // Create and immediately dispose parent scope
        final parentScope = ZenScopeManager.getOrCreateScope(name: 'parent');
        ZenScopeManager.getOrCreateScope(name: 'child');

        ZenScopeStackTracker.pushScope('parent');
        ZenScopeStackTracker.pushScope('child');

        parentScope.dispose(); // Dispose the parent

        final resolvedParent = ZenScopeStackTracker.getParentScopeInstance('child');

        expect(resolvedParent, isNull);
      });

      test('should return null when parent scope does not exist in manager', () {
        ZenScopeStackTracker.pushScope('nonexistent');
        ZenScopeStackTracker.pushScope('child');

        final resolvedParent = ZenScopeStackTracker.getParentScopeInstance('child');

        expect(resolvedParent, isNull);
      });
    });

    group('Debug Information', () {
      test('should provide comprehensive debug info', () {
        ZenScopeStackTracker.pushScope('scope1');
        ZenScopeStackTracker.pushScope('scope2');

        final debugInfo = ZenScopeStackTracker.getDebugInfo();

        expect(debugInfo['stack'], equals(['scope1', 'scope2']));
        expect(debugInfo['stackSize'], equals(2));
        expect(debugInfo['currentScope'], equals('scope2'));

        // Check the creation times exist and are valid
        expect(debugInfo['creationTimes'], isA<Map>());
        final creationTimes = debugInfo['creationTimes'] as Map;
        expect(creationTimes.containsKey('scope1'), isTrue);
        expect(creationTimes.containsKey('scope2'), isTrue);
        expect(creationTimes['scope1'], isA<DateTime>());
        expect(creationTimes['scope2'], isA<DateTime>());
      });

      test('should provide empty debug info for empty stack', () {
        final debugInfo = ZenScopeStackTracker.getDebugInfo();

        expect(debugInfo['stack'], isEmpty);
        expect(debugInfo['stackSize'], equals(0));
        expect(debugInfo['currentScope'], isNull);
        expect(debugInfo['creationTimes'], isEmpty);
      });
    });

    group('Scope Activity Status', () {
      test('should correctly identify active scopes', () {
        ZenScopeStackTracker.pushScope('active1');
        ZenScopeStackTracker.pushScope('active2');

        expect(ZenScopeStackTracker.isActive('active1'), isTrue);
        expect(ZenScopeStackTracker.isActive('active2'), isTrue);
        expect(ZenScopeStackTracker.isActive('inactive'), isFalse);
      });

      test('should update activity status when scopes are removed', () {
        ZenScopeStackTracker.pushScope('scope1');
        ZenScopeStackTracker.pushScope('scope2');

        expect(ZenScopeStackTracker.isActive('scope1'), isTrue);

        ZenScopeStackTracker.popScope('scope1');

        expect(ZenScopeStackTracker.isActive('scope1'), isFalse);
        expect(ZenScopeStackTracker.isActive('scope2'), isTrue);
      });
    });

    group('Real-world Scenarios', () {
      test('should handle typical navigation flow', () {
        // App start
        ZenScopeStackTracker.pushScope('AppScope');
        expect(ZenScopeStackTracker.getParentScope('AppScope'), isNull);

        // Navigate to feature
        ZenScopeStackTracker.pushScope('DepartmentsScope');
        expect(ZenScopeStackTracker.getParentScope('DepartmentsScope'), equals('AppScope'));

        // Navigate to detail
        ZenScopeStackTracker.pushScope('DepartmentDetailScope');
        expect(ZenScopeStackTracker.getParentScope('DepartmentDetailScope'), equals('DepartmentsScope'));

        // Navigate to nested detail
        ZenScopeStackTracker.pushScope('EmployeeDetailScope');
        expect(ZenScopeStackTracker.getParentScope('EmployeeDetailScope'), equals('DepartmentDetailScope'));

        // Navigate back (pop detail)
        ZenScopeStackTracker.popScope('EmployeeDetailScope');
        expect(ZenScopeStackTracker.getCurrentScope(), equals('DepartmentDetailScope'));

        // Navigate back to list
        ZenScopeStackTracker.popScope('DepartmentDetailScope');
        expect(ZenScopeStackTracker.getCurrentScope(), equals('DepartmentsScope'));
      });

      test('should handle modal/dialog scenarios', () {
        // Base navigation
        ZenScopeStackTracker.pushScope('MainScope');
        ZenScopeStackTracker.pushScope('PageScope');

        // Show modal
        ZenScopeStackTracker.pushScope('ModalScope');
        expect(ZenScopeStackTracker.getParentScope('ModalScope'), equals('PageScope'));

        // Show dialog from modal
        ZenScopeStackTracker.pushScope('DialogScope');
        expect(ZenScopeStackTracker.getParentScope('DialogScope'), equals('ModalScope'));

        // Close dialog
        ZenScopeStackTracker.popScope('DialogScope');
        expect(ZenScopeStackTracker.getCurrentScope(), equals('ModalScope'));

        // Close modal
        ZenScopeStackTracker.popScope('ModalScope');
        expect(ZenScopeStackTracker.getCurrentScope(), equals('PageScope'));
      });

      test('should handle widget rebuilds (duplicate scope names)', () {
        ZenScopeStackTracker.pushScope('PageScope');
        ZenScopeStackTracker.pushScope('ChildScope');

        // Widget rebuild causes same scope to be pushed again
        ZenScopeStackTracker.pushScope('ChildScope');

        // Should not create duplicate, just move to top
        expect(ZenScopeStackTracker.getCurrentStack(), equals(['PageScope', 'ChildScope']));
        expect(ZenScopeStackTracker.getParentScope('ChildScope'), equals('PageScope'));
      });
    });
  });
}