// test/di/zen_service_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

class TestService extends ZenService {
  final String name;
  TestService(this.name);

  @override
  void onInit() {
    super.onInit();
  }
}

class TestController extends ZenController {
  final String name;
  TestController(this.name);
}

void main() {
  group('ZenService Integration', () {
    tearDown(() {
      ZenService.disposeAllServices();
      Zen.reset();
    });

    test('_isZenServiceFactory should detect ZenService types correctly', () {
      // This tests the type detection for putLazy
      Zen.putLazy<TestService>(() => TestService('lazy'));
      Zen.putLazy<TestController>(() => TestController('lazy'));

      final service = Zen.find<TestService>();
      final controller = Zen.find<TestController>();

      expect(service.name, 'lazy');
      expect(service.isInitialized, true);
      expect(controller.name, 'lazy');
    });

    test('should work with tagged services', () {
      Zen.put<TestService>(TestService('main'));
      Zen.put<TestService>(TestService('secondary'), tag: 'alt');

      final mainService = Zen.find<TestService>();
      final altService = Zen.find<TestService>(tag: 'alt');

      expect(mainService.name, 'main');
      expect(altService.name, 'secondary');
      expect(mainService.isInitialized, true);
      expect(altService.isInitialized, true);
    });
  });
}
