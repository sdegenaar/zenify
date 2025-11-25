import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
    Zen.testMode().clearQueryCache();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenQuery Placeholder Data', () {
    test('shows placeholder data initially', () async {
      final query = ZenQuery<String>(
        queryKey: 'placeholder',
        fetcher: (_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'real-data';
        },
        config: const ZenQueryConfig(
          placeholderData: 'fake-data',
        ),
      );

      // Initially (sync)
      expect(query.data.value, 'fake-data');
      expect(query.isPlaceholderData.value, true);
      // Status is success so UI renders
      expect(query.status.value, ZenQueryStatus.success);

      // Wait for fetch
      await Future.delayed(const Duration(milliseconds: 60));

      // Real data arrives
      expect(query.data.value, 'real-data');
      expect(query.isPlaceholderData.value, false);
    });

    test('placeholder data is replaced by real data even if empty', () async {
      final query = ZenQuery<String>(
        queryKey: 'placeholder-empty',
        fetcher: (_) async => '', // Empty string is valid real data
        config: const ZenQueryConfig(
          placeholderData: 'loading...',
        ),
      );

      expect(query.data.value, 'loading...');

      // Allow microtasks
      await Future.delayed(Duration.zero);

      expect(query.data.value, '');
      expect(query.isPlaceholderData.value, false);
    });
  });
}
