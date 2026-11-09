import 'package:flutter/material.dart';

import '../data/models.dart';

class TxnCategory {
  const TxnCategory(this.id, this.label, this.icon, this.color);
  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

const List<TxnCategory> expenseCategories = [
  TxnCategory('food', 'Makan & Minum', Icons.restaurant_rounded, Color(0xFFEF6C00)),
  TxnCategory('groceries', 'Kebutuhan Harian', Icons.local_grocery_store_rounded, Color(0xFF43A047)),
  TxnCategory('transport', 'Transportasi', Icons.directions_car_rounded, Color(0xFF1E88E5)),
  TxnCategory('shopping', 'Belanja', Icons.shopping_bag_rounded, Color(0xFFD81B60)),
  TxnCategory('bills', 'Tagihan', Icons.receipt_long_rounded, Color(0xFF6D4C41)),
  TxnCategory('entertainment', 'Hiburan', Icons.movie_rounded, Color(0xFF8E24AA)),
  TxnCategory('health', 'Kesehatan', Icons.medical_services_rounded, Color(0xFFE53935)),
  TxnCategory('education', 'Pendidikan', Icons.school_rounded, Color(0xFF3949AB)),
  TxnCategory('other_expense', 'Lainnya', Icons.more_horiz_rounded, Color(0xFF757575)),
];

const List<TxnCategory> incomeCategories = [
  TxnCategory('salary', 'Gaji', Icons.work_rounded, Color(0xFF2E7D32)),
  TxnCategory('bonus', 'Bonus', Icons.star_rounded, Color(0xFFF9A825)),
  TxnCategory('gift', 'Hadiah', Icons.redeem_rounded, Color(0xFFD81B60)),
  TxnCategory('investment', 'Investasi', Icons.trending_up_rounded, Color(0xFF00897B)),
  TxnCategory('other_income', 'Lainnya', Icons.more_horiz_rounded, Color(0xFF757575)),
];

const TxnCategory transferCategory =
    TxnCategory('transfer', 'Transfer', Icons.swap_horiz_rounded, Color(0xFF546E7A));

List<TxnCategory> categoriesFor(TxnType type) => switch (type) {
      TxnType.expense => expenseCategories,
      TxnType.income => incomeCategories,
      TxnType.transfer => const [transferCategory],
    };

TxnCategory categoryById(String? id, TxnType type) {
  if (type == TxnType.transfer) return transferCategory;
  final list = categoriesFor(type);
  return list.firstWhere((c) => c.id == id, orElse: () => list.last);
}

/// Ids the receipt scanner is allowed to return.
List<String> get expenseCategoryIds => [for (final c in expenseCategories) c.id];
