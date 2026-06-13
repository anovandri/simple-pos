class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.category = 'Drinks',
  });

  final String id;
  final String name;
  final int price;
  final String category;

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      price: rawPrice is int ? rawPrice : int.parse(rawPrice.toString()),
      category: (json['category'] ?? 'Drinks').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
    };
  }
}
