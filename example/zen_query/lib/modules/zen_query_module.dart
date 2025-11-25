import 'package:zenify/zenify.dart';

/// Module for ZenQuery example app
/// Registers shared services and configures the app
class ZenQueryModule extends ZenModule {
  @override
  String get name => 'ZenQueryModule';

  @override
  Future<void> register(ZenScope scope) async {
    // Register any shared services here if needed
    // For now, this example uses local controllers per page

    ZenLogger.logInfo('ZenQuery Module registered');
  }
}
