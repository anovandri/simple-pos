import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'order_ticket_models.dart';

class OrderTicketStorage {
  static const _orderTicketsKey = 'pos_order_tickets';

  Future<List<OrderTicket>> loadOrderTickets() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_orderTicketsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => OrderTicket.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveOrderTickets(List<OrderTicket> orderTickets) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(orderTickets.map((t) => t.toJson()).toList());
    await preferences.setString(_orderTicketsKey, encoded);
  }

  Future<void> clearOrderTickets() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_orderTicketsKey);
  }
}
