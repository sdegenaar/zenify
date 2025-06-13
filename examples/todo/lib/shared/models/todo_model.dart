import 'package:uuid/uuid.dart';

/// Represents a Todo item in the application
class Todo {
  /// Unique identifier for the todo
  final String id;
  
  /// Title/description of the todo
  String title;
  
  /// Whether the todo is completed
  bool isCompleted;
  
  /// Creation date of the todo
  final DateTime createdAt;
  
  /// Last updated date of the todo
  DateTime updatedAt;
  
  /// Optional due date for the todo
  DateTime? dueDate;
  
  /// Optional priority level (1-3, where 3 is highest)
  int priority;
  
  /// Optional notes or additional details
  String? notes;
  
  /// Creates a new Todo with the given parameters
  Todo({
    String? id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.dueDate,
    this.priority = 1,
    this.notes,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();
  
  /// Creates a Todo from a JSON map
  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      dueDate: json['dueDate'] != null 
          ? DateTime.parse(json['dueDate'] as String) 
          : null,
      priority: json['priority'] as int? ?? 1,
      notes: json['notes'] as String?,
    );
  }
  
  /// Converts the Todo to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority,
      'notes': notes,
    };
  }
  
  /// Creates a copy of this Todo with the given fields replaced with new values
  Todo copyWith({
    String? title,
    bool? isCompleted,
    DateTime? updatedAt,
    DateTime? dueDate,
    int? priority,
    String? notes,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
    );
  }
}