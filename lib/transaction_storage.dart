import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'transaction_models.dart';

class TransactionStorage {
  static const _transactionsKey = 'pos_transactions';

  Future<List<PosTransaction>> loadTransactions() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_transactionsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => PosTransaction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTransactions(List<PosTransaction> transactions) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(transactions.map((t) => t.toJson()).toList());
    await preferences.setString(_transactionsKey, encoded);
  }
}
