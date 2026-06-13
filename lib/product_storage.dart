import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'product_models.dart';

class ProductStorage {
  static const _productsKey = 'catalog_products';

  Future<List<Product>> loadProducts() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_productsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProducts(List<Product> products) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(products.map((p) => p.toJson()).toList());
    await preferences.setString(_productsKey, encoded);
  }
}
