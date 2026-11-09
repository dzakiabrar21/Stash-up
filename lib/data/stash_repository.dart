import 'package:sqflite/sqflite.dart';

import 'models.dart';

class StashRepository {
  StashRepository(this._db);

  final Database _db;

  // ---------------------------------------------------------------- wallets

  Future<List<Wallet>> getWallets() async {
    final rows = await _db.rawQuery('''
      SELECT w.*,
        w.initial_balance
        + COALESCE((SELECT SUM(CASE t.type WHEN 'income' THEN t.amount ELSE -t.amount END)
                    FROM transactions t WHERE t.wallet_id = w.id), 0)
        + COALESCE((SELECT SUM(t.amount) FROM transactions t
                    WHERE t.type = 'transfer' AND t.to_wallet_id = w.id), 0)
        AS balance
      FROM wallets w
      ORDER BY w.id
    ''');
    return rows.map(Wallet.fromMap).toList();
  }

  Future<int> insertWallet(Wallet w) => _db.insert('wallets', w.toMap());

  Future<void> updateWallet(Wallet w) =>
      _db.update('wallets', w.toMap(), where: 'id = ?', whereArgs: [w.id]);

  /// Deletes the wallet and (via ON DELETE CASCADE) all its transactions.
  Future<void> deleteWallet(int id) =>
      _db.delete('wallets', where: 'id = ?', whereArgs: [id]);

  Future<int> countTransactionsForWallet(int id) async {
    final r = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions WHERE wallet_id = ? OR to_wallet_id = ?',
      [id, id],
    );
    return (r.first['c'] as num).toInt();
  }

  // ----------------------------------------------------------- transactions

  Future<int> insertTxn(Txn t) => _db.insert('transactions', t.toMap());

  Future<void> updateTxn(Txn t) =>
      _db.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  Future<void> deleteTxn(int id) =>
      _db.delete('transactions', where: 'id = ?', whereArgs: [id]);

  /// Newest first. [walletId] matches both the source and destination wallet.
  /// [to] is exclusive.
  Future<List<Txn>> getTransactions({
    int? walletId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final where = <String>[];
    final args = <Object>[];
    if (walletId != null) {
      where.add('(wallet_id = ? OR to_wallet_id = ?)');
      args.addAll([walletId, walletId]);
    }
    if (from != null) {
      where.add('date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('date < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await _db.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return rows.map(Txn.fromMap).toList();
  }

  // -------------------------------------------------------------- analytics

  /// Income/expense totals for [from, to). Transfers are excluded.
  Future<MonthTotal> totals(DateTime from, DateTime to) async {
    final rows = await _db.rawQuery(
      '''SELECT type, SUM(amount) AS total FROM transactions
         WHERE type != 'transfer' AND date >= ? AND date < ?
         GROUP BY type''',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    var income = 0, expense = 0;
    for (final r in rows) {
      final total = (r['total'] as num).toInt();
      if (r['type'] == 'income') income = total;
      if (r['type'] == 'expense') expense = total;
    }
    return MonthTotal(from, income: income, expense: expense);
  }

  /// Expense totals per category for [from, to), largest first.
  Future<List<CategoryTotal>> expenseByCategory(DateTime from, DateTime to) async {
    final rows = await _db.rawQuery(
      '''SELECT COALESCE(category, 'other_expense') AS category, SUM(amount) AS total
         FROM transactions
         WHERE type = 'expense' AND date >= ? AND date < ?
         GROUP BY COALESCE(category, 'other_expense')
         ORDER BY total DESC''',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return rows
        .map((r) => CategoryTotal(r['category'] as String, (r['total'] as num).toInt()))
        .toList();
  }

  /// Totals for the [count] months ending with [lastMonth] (oldest first).
  /// Months are grouped in local time.
  Future<List<MonthTotal>> monthlyTotals(DateTime lastMonth, {int count = 6}) async {
    final start = DateTime(lastMonth.year, lastMonth.month - count + 1);
    final end = DateTime(lastMonth.year, lastMonth.month + 1);
    final rows = await _db.query(
      'transactions',
      columns: ['type', 'amount', 'date'],
      where: "type != 'transfer' AND date >= ? AND date < ?",
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    final income = List<int>.filled(count, 0);
    final expense = List<int>.filled(count, 0);
    for (final r in rows) {
      final d = DateTime.fromMillisecondsSinceEpoch(r['date'] as int);
      final i = (d.year - start.year) * 12 + d.month - start.month;
      if (i < 0 || i >= count) continue;
      final amount = (r['amount'] as num).toInt();
      if (r['type'] == 'income') {
        income[i] += amount;
      } else {
        expense[i] += amount;
      }
    }
    return List.generate(
      count,
      (i) => MonthTotal(
        DateTime(start.year, start.month + i),
        income: income[i],
        expense: expense[i],
      ),
    );
  }

  // ----------------------------------------------------------------- export

  /// All transactions (oldest first) joined with wallet names.
  Future<List<Map<String, Object?>>> exportRows() => _db.rawQuery('''
        SELECT t.*, w.name AS wallet_name, tw.name AS to_wallet_name
        FROM transactions t
        JOIN wallets w ON w.id = t.wallet_id
        LEFT JOIN wallets tw ON tw.id = t.to_wallet_id
        ORDER BY t.date ASC, t.id ASC
      ''');
}
