/// User model for the e-commerce app
class User {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final List<String> favoriteProductIds;
  final List<String> orderIds;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.favoriteProductIds = const [],
    this.orderIds = const [],
  });

  /// Create a user from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      favoriteProductIds: (json['favoriteProductIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      orderIds: (json['orderIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Convert user to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'favoriteProductIds': favoriteProductIds,
      'orderIds': orderIds,
    };
  }

  /// Create a copy of this user with the given fields replaced
  User copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    List<String>? favoriteProductIds,
    List<String>? orderIds,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      favoriteProductIds: favoriteProductIds ?? this.favoriteProductIds,
      orderIds: orderIds ?? this.orderIds,
    );
  }

  /// Add a product to favorites
  User addToFavorites(String productId) {
    if (favoriteProductIds.contains(productId)) {
      return this;
    }
    return copyWith(
      favoriteProductIds: [...favoriteProductIds, productId],
    );
  }

  /// Remove a product from favorites
  User removeFromFavorites(String productId) {
    return copyWith(
      favoriteProductIds:
          favoriteProductIds.where((id) => id != productId).toList(),
    );
  }

  /// Toggle a product in favorites
  User toggleFavorite(String productId) {
    return favoriteProductIds.contains(productId)
        ? removeFromFavorites(productId)
        : addToFavorites(productId);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
