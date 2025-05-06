class Todo {
  final int id;
  final String title;
  bool completed;

  Todo({
    required this.id,
    required this.title,
    this.completed = false,
  });

  Todo copyWith({
    int? id,
    String? title,
    bool? completed,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }
}