class User {
  final String id;
  final String username;
  final String email;
  final String fullName;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
  });

  // Create a mock user
  factory User.mock() {
    return User(
      id: '1',
      username: 'user',
      email: 'user@example.com',
      fullName: 'John Doe',
    );
  }
}