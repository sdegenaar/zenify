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
      permanent: true,
    );
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('ShowcaseModule initialized');
    }
  }
}