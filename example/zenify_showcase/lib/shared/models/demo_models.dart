/// Demo user model
class DemoUser {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  DemoUser({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });
}

/// Demo product model
class DemoProduct {
  final String id;
  final String name;
  final double price;
  final String category;
  final bool isAvailable;

  DemoProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.isAvailable,
  });
}

/// Demo notification model
class DemoNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  DemoNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
  });
}