import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/todo_controller.dart';

class TodoPage extends StatelessWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ZenControllerScope<TodoController>(
      create: () => TodoController(),
      child: Builder(
        builder: (context) {
          final controller = Zen.find<TodoController>()!;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Todo List Example'),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'New Todo',
                            border: OutlineInputBorder(),
                          ),
                          // Use ValueNotifier-based two-way binding
                          onChanged: (value) => controller.newTodoText.value = value,
                          // Track the value reactively
                          controller: TextEditingController(text: controller.newTodoText.value)
                            ..selection = TextSelection.fromPosition(
                              TextPosition(offset: controller.newTodoText.value.length),
                            ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: controller.addTodo,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  // Obx automatically rebuilds when todos list changes
                  child: Obx(() => ListView.builder(
                    itemCount: controller.todos.value.length,
                    itemBuilder: (context, index) {
                      final todo = controller.todos.value[index];

                      return ListTile(
                        leading: Checkbox(
                          value: todo.completed,
                          onChanged: (_) => controller.toggleTodo(todo.id),
                        ),
                        title: Text(
                          todo.title,
                          style: TextStyle(
                            decoration: todo.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => controller.removeTodo(todo.id),
                        ),
                      );
                    },
                  )),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}