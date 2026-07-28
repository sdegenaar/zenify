import 'package:zenify/zenify.dart';
import '../controllers/home_controller.dart';

class HomeModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // Register the home controller
    scope.put<HomeController>(HomeController());
  }

  @override
  String get name => 'HomeModule';
}
