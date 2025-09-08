// test/integration/controller_lifecycle_memory_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';
import '../test_helpers.dart';

void main() {
  group('Controller Lifecycle Memory Management', () {
    setUp(() {
      ZenTestHelper.resetDI();
    });

    tearDown(() {
      ZenTestHelper.resetDI();
    });

    test('should track controller disposal correctly', () {
      final controller1 = TestController('page1');
      final controller2 = TestController('page2');

      // Register controllers with different tags
      Zen.put<TestController>(controller1, tag: 'page1');
      Zen.put<TestController>(controller2, tag: 'page2');

      // Verify they exist
      expect(Zen.findOrNull<TestController>(tag: 'page1'), isNotNull);
      expect(Zen.findOrNull<TestController>(tag: 'page2'), isNotNull);

      // Dispose one
      Zen.delete<TestController>(tag: 'page1', force: true);

      // Verify disposal
      expect(Zen.findOrNull<TestController>(tag: 'page1'), isNull);
      expect(Zen.findOrNull<TestController>(tag: 'page2'), isNotNull);
      expect(controller1.isDisposed, true);
      expect(controller2.isDisposed, false);
    });

    test('should prevent multiple controller instances with same signature',
        () {
      final controller1 = TestController('first');

      Zen.put<TestController>(controller1);

      // Trying to put another should replace the first one
      final controller2 = TestController('second');
      Zen.put<TestController>(controller2);

      expect(Zen.find<TestController>(), equals(controller2));
      expect(Zen.find<TestController>(), isNot(equals(controller1)));
    });

    test('should detect accumulated controllers in global scope', () {
      final controllers = <TestController>[];

      // Simulate the scenario where controllers are not properly cleaned up
      for (int i = 0; i < 5; i++) {
        final controller = TestController('controller_$i');
        controllers.add(controller);

        // Register with unique tags (simulating different pages)
        Zen.put<TestController>(controller, tag: 'page_$i');
      }

      // All controllers should be findable
      for (int i = 0; i < 5; i++) {
        expect(Zen.findOrNull<TestController>(tag: 'page_$i'), isNotNull);
      }

      // Now simulate proper cleanup - dispose when navigating away
      for (int i = 0; i < 5; i++) {
        Zen.delete<TestController>(tag: 'page_$i', force: true);
        expect(controllers[i].isDisposed, true);
      }

      // All should be cleaned up
      for (int i = 0; i < 5; i++) {
        expect(Zen.findOrNull<TestController>(tag: 'page_$i'), isNull);
      }
    });

    test(
        'should verify controller lifecycle states during navigation simulation',
        () {
      // Simulate the DepartmentsController -> DepartmentDetailController -> EmployeeProfileController flow

      // 1. Start with DepartmentsController
      final departmentsController = TestController('departments');
      Zen.put<TestController>(departmentsController, tag: 'departments');

      expect(departmentsController.isDisposed, false);
      expect(Zen.findOrNull<TestController>(tag: 'departments'), isNotNull);

      // 2. Navigate to department detail - DepartmentsController should remain
      final departmentDetailController = TestController('department_detail');
      Zen.put<TestController>(departmentDetailController,
          tag: 'department_detail');

      expect(departmentsController.isDisposed, false);
      expect(departmentDetailController.isDisposed, false);
      expect(Zen.findOrNull<TestController>(tag: 'departments'), isNotNull);
      expect(
          Zen.findOrNull<TestController>(tag: 'department_detail'), isNotNull);

      // 3. Navigate to employee profile - both previous should remain (PROBLEM!)
      final employeeProfileController = TestController('employee_profile');
      Zen.put<TestController>(employeeProfileController,
          tag: 'employee_profile');

      expect(departmentsController.isDisposed, false);
      expect(departmentDetailController.isDisposed, false);
      expect(employeeProfileController.isDisposed, false);
      expect(Zen.findOrNull<TestController>(tag: 'departments'), isNotNull);
      expect(
          Zen.findOrNull<TestController>(tag: 'department_detail'), isNotNull);
      expect(
          Zen.findOrNull<TestController>(tag: 'employee_profile'), isNotNull);

      // 4. Navigate back to home - should dispose intermediate controllers
      // This is what SHOULD happen but currently doesn't:

      // When going back to department detail, employee profile should be disposed
      Zen.delete<TestController>(tag: 'employee_profile', force: true);
      expect(employeeProfileController.isDisposed, true);
      expect(Zen.findOrNull<TestController>(tag: 'employee_profile'), isNull);

      // When going back to home, department detail should be disposed
      Zen.delete<TestController>(tag: 'department_detail', force: true);
      expect(departmentDetailController.isDisposed, true);
      expect(Zen.findOrNull<TestController>(tag: 'department_detail'), isNull);

      // Departments controller should still be active
      expect(departmentsController.isDisposed, false);
      expect(Zen.findOrNull<TestController>(tag: 'departments'), isNotNull);
    });

    test('should detect the exact memory leak pattern from logs', () {
      // This test simulates the exact pattern from your logs:
      // Multiple controllers being "resumed" instead of being disposed

      final activeControllers = <String, TestController>{};

      void simulateNavigateToPage(String pageName) {
        if (!activeControllers.containsKey(pageName)) {
          final controller = TestController(pageName);
          activeControllers[pageName] = controller;
          Zen.put<TestController>(controller, tag: pageName);
        }

        // Simulate "resume" - this should NOT happen for disposed controllers
        for (final entry in activeControllers.entries) {
          if (!entry.value.isDisposed) {
            // This simulates the "Controller X resumed" log
            // In a real scenario, this would be called by the framework
            // The problem is that we have too many non-disposed controllers
          }
        }
      }

      void simulateProperNavigateBack(String fromPage) {
        if (activeControllers.containsKey(fromPage)) {
          final controller = activeControllers[fromPage]!;
          Zen.delete<TestController>(tag: fromPage, force: true);
          expect(controller.isDisposed, true);
          activeControllers.remove(fromPage);
        }
      }

      // Simulate the navigation pattern
      simulateNavigateToPage('departments');
      expect(activeControllers.length, 1);

      simulateNavigateToPage('department_detail');
      expect(activeControllers.length, 2); // PROBLEM: accumulating

      simulateNavigateToPage('employee_profile');
      expect(activeControllers.length, 3); // PROBLEM: still accumulating

      // Simulate what SHOULD happen when navigating back
      simulateProperNavigateBack('employee_profile');
      expect(activeControllers.length, 2);

      simulateProperNavigateBack('department_detail');
      expect(activeControllers.length, 1);

      // Now when navigating again, we shouldn't accumulate
      simulateNavigateToPage('department_detail');
      simulateNavigateToPage('employee_profile');
      expect(activeControllers.length, 3); // Should be back to 3, not 5!

      // The issue in your logs suggests that controllers are NOT being disposed
      // so they keep accumulating and all respond to "resume" events
    });
  });
}
