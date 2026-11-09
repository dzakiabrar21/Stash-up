import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Opens the local SQLite database. Everything lives on-device.
class AppDatabase {
  static const fileName = 'stash.db';
  static const version = 1;

  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    return f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
      ),
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE wallets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          kind TEXT NOT NULL,
          color INTEGER NOT NULL,
          initial_balance INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''')
      ..execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL CHECK (type IN ('expense', 'income', 'transfer')),
          amount INTEGER NOT NULL CHECK (amount > 0),
          wallet_id INTEGER NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
          to_wallet_id INTEGER REFERENCES wallets(id) ON DELETE CASCADE,
          category TEXT,
          merchant TEXT,
          note TEXT,
          date INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''')
      ..execute('CREATE INDEX idx_txn_date ON transactions(date)')
      ..execute('CREATE INDEX idx_txn_wallet ON transactions(wallet_id)')
      ..execute('CREATE INDEX idx_txn_to_wallet ON transactions(to_wallet_id)')
      ..insert(
        'wallets',
        Wallet(
          name: 'Tunai',
          kind: WalletKind.cash,
          color: 0xFF2E7D32,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    await batch.commit(noResult: true);
  }
}
