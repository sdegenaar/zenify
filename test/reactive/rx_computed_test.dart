import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  group('RxComputed', () {
    test('should compute values based on dependencies', () {
      final firstName = 'John'.obs();
      final lastName = 'Doe'.obs();

      final fullName = RxComputed(() => '${firstName.value} ${lastName.value}');

      expect(fullName.value, 'John Doe');

      firstName.value = 'Jane';
      expect(fullName.value, 'Jane Doe');

      lastName.value = 'Smith';
      expect(fullName.value, 'Jane Smith');
    });

    test('should track dependencies automatically', () {
      final a = 5.obs();
      final b = 10.obs();
      final sum = RxComputed(() => a.value + b.value);

      expect(sum.dependencies.length, 2);
      expect(sum.dependencies.contains(a), true);
      expect(sum.dependencies.contains(b), true);
    });

    test('should only recompute when dependencies change', () {
      final count = 0.obs();
      var computeCount = 0;

      final doubled = RxComputed(() {
        computeCount++;
        return count.value * 2;
      });

      // Initial computation
      expect(doubled.value, 0);
      expect(computeCount, 1);

      // Access again without dependency change
      expect(doubled.value, 0);
      expect(computeCount, 1); // Should not recompute

      // Change dependency
      count.value = 5;
      expect(doubled.value, 10);
      expect(computeCount, 2); // Should recompute
    });

    test('should handle nested computed values', () {
      final base = 2.obs();
      final squared = RxComputed(() => base.value * base.value);
      final cubed = RxComputed(() => squared.value * base.value);

      expect(cubed.value, 8); // 2^3

      base.value = 3;
      expect(cubed.value, 27); // 3^3
    });

    test('should dispose properly', () {
      final a = 5.obs();
      final computed = RxComputed(() => a.value * 2);

      expect(computed.isDisposed, false);

      computed.dispose();
      expect(computed.isDisposed, true);
    });
  });
}