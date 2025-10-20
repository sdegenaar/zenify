import 'package:zenify/zenify.dart';
import '../../shared/services/demo_service.dart';

class ShowcaseModule extends ZenModule {
  @override
  String get name => 'ShowcaseModule';

  @override
  void register(ZenScope scope) {
    // Register services
    scope.put<DemoService>(
      DemoService(),
      isPermanent: true,
    );
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    ZenLogger.logInfo('ShowcaseModule initialized');
  }
}
