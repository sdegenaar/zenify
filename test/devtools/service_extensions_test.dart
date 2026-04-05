import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for ZenServiceExtensions.
/// The private helpers are pure functions that can be tested via
/// calling registerExtensions() (guarded, idempotent) and by
/// evaluating the publicly visible behaviors.
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
    Zen.init();
  });

  tearDown(Zen.reset);

  group('ZenServiceExtensions', () {
    test('registerExtensions does not throw', () {
      expect(() => ZenServiceExtensions.registerExtensions(), returnsNormally);
    });

    test('registerExtensions is idempotent (calling twice safe)', () {
      // First call registers
      ZenServiceExtensions.registerExtensions();
      // Second call guards via _registered flag (line 20)
      expect(() => ZenServiceExtensions.registerExtensions(), returnsNormally);
    });
  });
}
