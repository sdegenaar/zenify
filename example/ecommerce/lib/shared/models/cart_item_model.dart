import 'product_model.dart';

/// Cart item model for the e-commerce app
class CartItem {
  final String id;
  final Product product;
  final int quantity;

  const CartItem({
    required this.id,
    required this.product,
    this.quantity = 1,
  });

  /// Calculate the total price for this cart item
  double get totalPrice => product.price * quantity;

  /// Create a cart item from JSON
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num).toInt(),
    );
  }

  /// Convert cart item to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product.toJson(),
      'quantity': quantity,
    };
  }

  /// Create a copy of this cart item with the given fields replaced
  CartItem copyWith({
    String? id,
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Create a new cart item with updated quantity
  CartItem updateQuantity(int newQuantity) {
    return copyWith(quantity: newQuantity > 0 ? newQuantity : 1);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
