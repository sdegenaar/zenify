import 'package:zenify/zenify.dart';
import '../../shared/services/todo_service.dart';

/// Module for registering Todo-related dependencies
class TodoModule extends ZenModule {
  @override
  String get name => 'TodoModule';

  @override
  void register(ZenScope scope) {
    // Register the TodoService as a permanent singleton
    scope.put<TodoService>(
      TodoService(),
      isPermanent: true,
    );
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('TodoModule initialized');
    }

    // Pre-load todos when the module initializes
    final todoService = scope.find<TodoService>();
    await todoService?.loadTodos();
  }
}
