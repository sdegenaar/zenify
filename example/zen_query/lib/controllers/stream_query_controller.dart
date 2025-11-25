import 'package:zenify/zenify.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class StreamQueryController extends ZenController {
  late final ZenStreamQuery<String> notificationStream;
  late final ZenStreamQuery<int> activeUsersStream;
  late final ZenStreamQuery<Post> postUpdatesStream;

  final allNotifications = <String>[].obs();
  final isSubscribed = true.obs();

  @override
  void onInit() {
    super.onInit();

    // Notification stream
    notificationStream = ZenStreamQuery<String>(
      queryKey: 'notifications:live',
      streamFn: () => ApiService.getNotificationStream(),
      config: const ZenQueryConfig(),
    );

    // Listen to notifications and store them
    ZenWorkers.ever(notificationStream.data, (notification) {
      if (notification != null) {
        allNotifications.add(notification);
      }
    });

    // Active users stream
    activeUsersStream = ZenStreamQuery<int>(
      queryKey: 'users:active',
      streamFn: () => ApiService.getActiveUsersStream(),
      config: const ZenQueryConfig(),
    );

    // Post updates stream
    postUpdatesStream = ZenStreamQuery<Post>(
      queryKey: 'post:1:updates',
      streamFn: () => ApiService.getPostUpdatesStream(1),
      config: const ZenQueryConfig(),
    );
  }

  void subscribeAll() {
    notificationStream.subscribe();
    activeUsersStream.subscribe();
    postUpdatesStream.subscribe();
    isSubscribed.value = true;
  }

  void unsubscribeAll() {
    notificationStream.unsubscribe();
    activeUsersStream.unsubscribe();
    postUpdatesStream.unsubscribe();
    isSubscribed.value = false;
  }

  void clearNotifications() {
    allNotifications.clear();
  }

  @override
  void onClose() {
    notificationStream.dispose();
    activeUsersStream.dispose();
    postUpdatesStream.dispose();
    super.onClose();
  }
}
