// test/core/zen_workers_type_inference_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test controller with various reactive types
class TypeTestController extends ZenController {
  // Basic types
  final RxBool boolValue = false.obs();
  final RxInt intValue = 0.obs();
  final RxDouble doubleValue = 0.0.obs();
  final RxString stringValue = ''.obs();

  // Collection types
  final RxList<String> stringList = <String>[].obs();
  final RxMap<String, int> stringIntMap = <String, int>{}.obs();
  final RxSet<int> intSet = <int>{}.obs();

  // Nullable types
  final Rx<String?> nullableString = Rx<String?>(null);
  final Rx<int?> nullableInt = Rx<int?>(null);

  // Custom types
  final Rx<DateTime> dateTime = DateTime.now().obs();
  final Rx<Duration> duration = Duration.zero.obs();

  // Complex custom type
  final Rx<TestModel> model = TestModel('initial').obs();
}

class TestModel {
  final String name;
  TestModel(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is TestModel && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZenWorkers Type Inference Tests', () {
    late TypeTestController controller;

    setUp(() {
      Zen.init();
      controller = TypeTestController();
    });

    tearDown(() {
      controller.dispose();
      Zen.deleteAll(force: true);
    });

    group('Basic Type Inference', () {
      test('bool type inference works correctly', () async {
        bool? capturedValue;

        // This should compile without explicit typing
        final handle = controller.ever(controller.boolValue, (value) {
          capturedValue = value;
          // Verify that 'value' is properly typed as bool
          expect(value.runtimeType, bool);
        });

        controller.boolValue.value = true;
        await Future.delayed(Duration.zero);

        expect(capturedValue, true);
        handle.dispose();
      });

      test('int type inference works correctly', () async {
        int? capturedValue;

        final handle = controller.ever(controller.intValue, (value) {
          capturedValue = value;
          expect(value.runtimeType, int);
          // Should be able to use int methods without casting
          expect(value.isEven, false); // 1 is odd
        });

        controller.intValue.value = 1;
        await Future.delayed(Duration.zero);

        expect(capturedValue, 1);
        handle.dispose();
      });

      test('string type inference works correctly', () async {
        String? capturedValue;

        final handle = controller.ever(controller.stringValue, (value) {
          capturedValue = value;
          expect(value.runtimeType, String);
          // Should be able to use string methods without casting
          expect(value.length, 5); // 'hello'.length
        });

        controller.stringValue.value = 'hello';
        await Future.delayed(Duration.zero);

        expect(capturedValue, 'hello');
        handle.dispose();
      });
    });

    group('Collection Type Inference', () {
      test('List<String> type inference works correctly', () async {
        List<String>? capturedValue;

        final handle = controller.ever(controller.stringList, (value) {
          capturedValue = value;
          expect(value.runtimeType.toString(), 'List<String>');
          // Should be able to use list methods without casting
          if (value.isNotEmpty) {
            expect(value.first.runtimeType, String);
          }
        });

        // For reactive collections, we need to trigger the change by reassigning
        controller.stringList.value = ['test'];
        await Future.delayed(Duration.zero);

        expect(capturedValue, ['test']);
        handle.dispose();
      });

      test('Map<String, int> type inference works correctly', () async {
        Map<String, int>? capturedValue;

        final handle = controller.ever(controller.stringIntMap, (value) {
          capturedValue = value;
          // Should be able to use map methods without casting
          if (value.isNotEmpty) {
            final firstKey = value.keys.first;
            expect(firstKey.runtimeType, String);
            expect(value[firstKey].runtimeType, int);
          }
        });

        // For reactive maps, we need to trigger the change by reassigning
        controller.stringIntMap.value = {'key': 42};
        await Future.delayed(Duration.zero);

        expect(capturedValue, {'key': 42});
        handle.dispose();
      });

      test('Set<int> type inference works correctly', () async {
        Set<int>? capturedValue;

        final handle = controller.ever(controller.intSet, (value) {
          capturedValue = value;
          expect(value.runtimeType.toString(), 'Set<int>');
          // Should be able to use set methods without casting
          if (value.isNotEmpty) {
            expect(value.first.runtimeType, int);
          }
        });

        // For reactive sets, we need to trigger the change by reassigning
        controller.intSet.value = {1, 2, 3};
        await Future.delayed(Duration.zero);

        expect(capturedValue, {1, 2, 3});
        handle.dispose();
      });
    });

    group('Nullable Type Inference', () {
      test('nullable String type inference works correctly', () async {
        String? capturedValue;

        final handle = controller.ever(controller.nullableString, (value) {
          capturedValue = value;
          // Should handle null values correctly
          if (value != null) {
            expect(value.runtimeType, String);
            expect(value.length, greaterThan(0));
          }
        });

        controller.nullableString.value = 'nullable test';
        await Future.delayed(Duration.zero);

        expect(capturedValue, 'nullable test');
        handle.dispose();
      });

      test('nullable int type inference works correctly', () async {
        int? capturedValue;

        final handle = controller.ever(controller.nullableInt, (value) {
          capturedValue = value;
          if (value != null) {
            expect(value.runtimeType, int);
            expect(value.isOdd, true); // 3 is odd
          }
        });

        controller.nullableInt.value = 3;
        await Future.delayed(Duration.zero);

        expect(capturedValue, 3);
        handle.dispose();
      });
    });

    group('Custom Type Inference', () {
      test('DateTime type inference works correctly', () async {
        DateTime? capturedValue;
        final testDate = DateTime(2023, 12, 25);

        final handle = controller.ever(controller.dateTime, (value) {
          capturedValue = value;
          expect(value.runtimeType, DateTime);
          // Should be able to use DateTime methods without casting
          expect(value.year, 2023);
        });

        controller.dateTime.value = testDate;
        await Future.delayed(Duration.zero);

        expect(capturedValue, testDate);
        handle.dispose();
      });

      test('custom model type inference works correctly', () async {
        TestModel? capturedValue;
        final testModel = TestModel('test model');

        final handle = controller.ever(controller.model, (value) {
          capturedValue = value;
          expect(value.runtimeType, TestModel);
          // Should be able to access model properties without casting
          expect(value.name, 'test model');
        });

        controller.model.value = testModel;
        await Future.delayed(Duration.zero);

        expect(capturedValue?.name, 'test model');
        handle.dispose();
      });
    });

    group('Worker Type Consistency', () {
      test('all worker types maintain proper inference', () async {
        final capturedValues = <String>[];

        // Test all worker types with the same observable
        final handles = <ZenWorkerHandle>[
          controller.ever(controller.stringValue, (value) {
            capturedValues.add('ever:$value');
            expect(value.runtimeType, String);
          }),

          controller.once(controller.stringValue, (value) {
            capturedValues.add('once:$value');
            expect(value.runtimeType, String);
          }),

          controller.debounce(controller.stringValue, (value) {
            capturedValues.add('debounce:$value');
            expect(value.runtimeType, String);
          }, const Duration(milliseconds: 50)),

          controller.condition(controller.stringValue, (value) => value.isNotEmpty, (value) {
            capturedValues.add('condition:$value');
            expect(value.runtimeType, String);
          }),
        ];

        controller.stringValue.value = 'test';

        // Wait for all workers to execute
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify all workers received the value with correct type
        expect(capturedValues.length, greaterThan(0));
        for (final value in capturedValues) {
          expect(value.contains('test'), true);
        }

        // Clean up
        for (final handle in handles) {
          handle.dispose();
        }
      });
    });

    group('Effect Type Inference', () {
      test('effect data type inference works correctly', () async {
        final effect = controller.createEffect<String>(name: 'test');
        String? capturedValue;

        final handle = controller.ever(effect.data, (value) {
          capturedValue = value;
          if (value != null) {
            expect(value.runtimeType, String);
            expect(value.length, greaterThan(0));
          }
        });

        await effect.run(() async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'effect result';
        });

        expect(capturedValue, 'effect result');
        handle.dispose();
      });

      test('effect loading state type inference works correctly', () async {
        final effect = controller.createEffect<int>(name: 'test');
        bool? capturedValue;

        final handle = controller.ever(effect.isLoading, (value) {
          capturedValue = value;
          expect(value.runtimeType, bool);
        });

        final future = effect.run(() async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 42;
        });

        // Should capture true when loading starts
        expect(capturedValue, true);

        await future;

        // Should capture false when loading completes
        expect(capturedValue, false);

        handle.dispose();
      });
    });

    group('Type Inference Edge Cases', () {
      test('handles rapid type changes correctly', () async {
        final values = <String>[];

        final handle = controller.ever(controller.stringValue, (value) {
          values.add(value);
          // Verify type is preserved through rapid changes
          expect(value.runtimeType, String);
        });

        // Rapid changes
        controller.stringValue.value = 'first';
        await Future.delayed(Duration.zero);
        controller.stringValue.value = 'second';
        await Future.delayed(Duration.zero);
        controller.stringValue.value = 'third';
        await Future.delayed(Duration.zero);

        expect(values, ['first', 'second', 'third']);
        handle.dispose();
      });

      test('handles complex nested types correctly', () async {
        final complexData = <String, List<int>>{}.obs();
        Map<String, List<int>>? capturedValue;

        final handle = controller.ever(complexData, (value) {
          capturedValue = value;
          // Should maintain complex type structure
          if (value.isNotEmpty) {
            final firstValue = value.values.first;
            expect(firstValue.runtimeType.toString(), 'List<int>');
          }
        });

        complexData.value = {'numbers': [1, 2, 3]};
        await Future.delayed(Duration.zero);

        expect(capturedValue?['numbers'], [1, 2, 3]);
        handle.dispose();
      });
    });
  });
}