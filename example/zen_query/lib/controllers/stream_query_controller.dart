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

    // AUTOMATIC TRACKING - No wrapper needed!
    // Queries created in onInit() are automatically tracked and disposed
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

    // Active users stream - automatically tracked!
    activeUsersStream = ZenStreamQuery<int>(
      queryKey: 'users:active',
      streamFn: () => ApiService.getActiveUsersStream(),
      config: const ZenQueryConfig(),
    );

    // Post updates stream - automatically tracked!
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
    // NO NEED TO MANUALLY DISPOSE STREAMS ANYMORE!
    // All streams created in onInit() are automatically tracked and disposed.
    super.onClose();
  }
}
