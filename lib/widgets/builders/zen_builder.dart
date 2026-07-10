import '../../controllers/zen_controller.dart';
import 'zen_updater.dart';

@Deprecated(
    'Use ZenUpdater instead. ZenBuilder is renamed in V2 and no longer supports controller creation.')
typedef ZenBuilder<T extends ZenController> = ZenUpdater<T>;
