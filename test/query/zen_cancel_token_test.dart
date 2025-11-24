import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/query/zen_cancel_token.dart';

void main() {
  group('ZenCancelToken', () {
    test('initial state is not cancelled', () {
      final token = ZenCancelToken();
      expect(token.isCancelled, false);
    });

    test('cancel() sets isCancelled to true', () {
      final token = ZenCancelToken();
      token.cancel();
      expect(token.isCancelled, true);
    });

    test('notifies listeners on cancellation', () {
      final token = ZenCancelToken();
      bool called = false;

      token.onCancel(() {
        called = true;
      });

      token.cancel();
      expect(called, true);
    });

    test('notifies listeners added after cancellation immediately', () {
      final token = ZenCancelToken();
      token.cancel();

      bool called = false;
      token.onCancel(() {
        called = true;
      });

      expect(called, true);
    });

    test('handles multiple listeners', () {
      final token = ZenCancelToken();
      int count = 0;

      token.onCancel(() => count++);
      token.onCancel(() => count++);
      token.onCancel(() => count++);

      token.cancel();
      expect(count, 3);
    });

    test('cancel() is idempotent (listeners called once)', () {
      final token = ZenCancelToken();
      int count = 0;

      token.onCancel(() => count++);

      token.cancel();
      token.cancel();
      token.cancel();

      expect(count, 1);
    });

    test('throwIfCancelled throws only when cancelled', () {
      final token = ZenCancelToken();

      // Should not throw
      token.throwIfCancelled();

      token.cancel();

      // Should throw
      expect(
        () => token.throwIfCancelled(),
        throwsA(isA<ZenCancellationException>()),
      );
    });

    test('provides cancellation message', () {
      final token = ZenCancelToken('Custom message');
      token.cancel();

      try {
        token.throwIfCancelled();
      } catch (e) {
        expect(e, isA<ZenCancellationException>());
        expect(e.toString(), contains('Custom message'));
      }
    });

    test('listeners are robust against errors', () {
      final token = ZenCancelToken();
      bool secondListenerCalled = false;

      token.onCancel(() {
        throw Exception('Listener failed');
      });

      token.onCancel(() {
        secondListenerCalled = true;
      });

      // Should not throw exception out of cancel()
      token.cancel();

      // Second listener should still run despite first failing
      expect(secondListenerCalled, true);
    });
  });
}
