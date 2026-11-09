/// Domain models for Stash. All money is stored as whole Rupiah (int).
library;

enum TxnType {
  expense('Pengeluaran'),
  income('Pemasukan'),
  transfer('Transfer');

  const TxnType(this.label);
  final String label;
}

enum WalletKind {
  bank('Bank'),
  ewallet('E-Wallet'),
  cash('Tunai');

  const WalletKind(this.label);
  final String label;
}

class Wallet {
  const Wallet({
    this.id,
    required this.name,
    required this.kind,
    required this.color,
    this.initialBalance = 0,
    required this.createdAt,
    this.balance = 0,
  });

  final int? id;
  final String name;
  final WalletKind kind;

  /// ARGB color value.
  final int color;
  final int initialBalance;
  final DateTime createdAt;

  /// Current balance, computed by the repository (not stored).
  final int balance;

  Wallet copyWith({
    String? name,
    WalletKind? kind,
    int? color,
    int? initialBalance,
  }) =>
      Wallet(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        color: color ?? this.color,
        initialBalance: initialBalance ?? this.initialBalance,
        createdAt: createdAt,
        balance: balance,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'kind': kind.name,
        'color': color,
        'initial_balance': initialBalance,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Wallet.fromMap(Map<String, Object?> m) {
    final initial = (m['initial_balance'] as num).toInt();
    return Wallet(
      id: m['id'] as int,
      name: m['name'] as String,
      kind: WalletKind.values.byName(m['kind'] as String),
      color: m['color'] as int,
      initialBalance: initial,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      balance: (m['balance'] as num?)?.toInt() ?? initial,
    );
  }
}

class Txn {
  const Txn({
    this.id,
    required this.type,
    required this.amount,
    required this.walletId,
    this.toWalletId,
    this.category,
    this.merchant,
    this.note,
    required this.date,
    required this.createdAt,
  });

  final int? id;
  final TxnType type;

  /// Always positive; the sign comes from [type].
  final int amount;
  final int walletId;

  /// Destination wallet, only for transfers.
  final int? toWalletId;

  /// Category id (see `categories.dart`); null for transfers.
  final String? category;
  final String? merchant;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'amount': amount,
        'wallet_id': walletId,
        'to_wallet_id': toWalletId,
        'category': category,
        'merchant': merchant,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as int,
        type: TxnType.values.byName(m['type'] as String),
        amount: (m['amount'] as num).toInt(),
        walletId: m['wallet_id'] as int,
        toWalletId: m['to_wallet_id'] as int?,
        category: m['category'] as String?,
        merchant: m['merchant'] as String?,
        note: m['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );

  /// Signed effect of this transaction on [walletId]'s balance.
  int effectOn(int walletId) {
    switch (type) {
      case TxnType.income:
        return this.walletId == walletId ? amount : 0;
      case TxnType.expense:
        return this.walletId == walletId ? -amount : 0;
      case TxnType.transfer:
        if (this.walletId == walletId) return -amount;
        if (toWalletId == walletId) return amount;
        return 0;
    }
  }
}

class MonthTotal {
  const MonthTotal(this.month, {this.income = 0, this.expense = 0});
  final DateTime month;
  final int income;
  final int expense;
}

class CategoryTotal {
  const CategoryTotal(this.category, this.total);
  final String category;
  final int total;
}
