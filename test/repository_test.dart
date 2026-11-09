import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stash/data/app_database.dart';
import 'package:stash/data/models.dart';
import 'package:stash/data/stash_repository.dart';
import 'package:stash/services/csv_exporter.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late StashRepository repo;

  setUp(() async {
    db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = StashRepository(db);
  });

  tearDown(() => db.close());

  Txn txn(TxnType type, int amount, int wallet,
          {int? to, String? category, DateTime? date}) =>
      Txn(
        type: type,
        amount: amount,
        walletId: wallet,
        toWalletId: to,
        category: category,
        date: date ?? DateTime(2026, 11, 5, 12),
        createdAt: DateTime(2026, 11, 5),
      );

  test('seeds a cash wallet on first open', () async {
    final wallets = await repo.getWallets();
    expect(wallets.single.name, 'Tunai');
    expect(wallets.single.kind, WalletKind.cash);
  });

  test('balances include income, expense and transfers', () async {
    final cash = (await repo.getWallets()).single.id!;
    final bca = await repo.insertWallet(Wallet(
      name: 'BCA',
      kind: WalletKind.bank,
      color: 0xFF0060AF,
      initialBalance: 1000000,
      createdAt: DateTime(2026),
    ));

    await repo.insertTxn(txn(TxnType.income, 500000, bca, category: 'salary'));
    await repo.insertTxn(txn(TxnType.expense, 75000, bca, category: 'food'));
    await repo.insertTxn(txn(TxnType.transfer, 200000, bca, to: cash));
    await repo.insertTxn(txn(TxnType.expense, 30000, cash, category: 'transport'));

    final byId = {for (final w in await repo.getWallets()) w.id: w.balance};
    expect(byId[bca], 1000000 + 500000 - 75000 - 200000);
    expect(byId[cash], 200000 - 30000);

    final totals = await repo.totals(DateTime(2026, 11), DateTime(2026, 12));
    expect(totals.income, 500000);
    expect(totals.expense, 105000, reason: 'transfers are not expenses');

    final walletTxns = await repo.getTransactions(walletId: cash);
    expect(walletTxns.length, 2, reason: 'incoming transfer is listed for the target wallet');
  });

  test('analytics group by category and month', () async {
    final cash = (await repo.getWallets()).single.id!;
    await repo.insertTxn(txn(TxnType.expense, 10000, cash, category: 'food'));
    await repo.insertTxn(txn(TxnType.expense, 20000, cash, category: 'food'));
    await repo.insertTxn(txn(TxnType.expense, 5000, cash, category: 'transport'));
    await repo.insertTxn(
        txn(TxnType.expense, 40000, cash, category: 'bills', date: DateTime(2026, 9, 30, 23)));

    final cats = await repo.expenseByCategory(DateTime(2026, 11), DateTime(2026, 12));
    expect(cats.map((c) => (c.category, c.total)), [('food', 30000), ('transport', 5000)]);

    final months = await repo.monthlyTotals(DateTime(2026, 11), count: 3);
    expect(months.map((m) => m.month.month), [9, 10, 11]);
    expect(months.map((m) => m.expense), [40000, 0, 35000]);
  });

  test('deleting a wallet cascades to its transactions', () async {
    final cash = (await repo.getWallets()).single.id!;
    final ovo = await repo.insertWallet(
        Wallet(name: 'OVO', kind: WalletKind.ewallet, color: 1, createdAt: DateTime(2026)));
    await repo.insertTxn(txn(TxnType.transfer, 50000, cash, to: ovo));
    await repo.insertTxn(txn(TxnType.expense, 1000, ovo, category: 'food'));
    expect(await repo.countTransactionsForWallet(ovo), 2);

    await repo.deleteWallet(ovo);
    expect(await repo.getTransactions(), isEmpty);
    expect((await repo.getWallets()).single.balance, 0);
  });

  test('CSV export includes wallet names and escapes text', () async {
    final cash = (await repo.getWallets()).single.id!;
    await repo.insertTxn(Txn(
      type: TxnType.expense,
      amount: 25000,
      walletId: cash,
      category: 'food',
      merchant: 'Warung "Bu Sri", Depok',
      date: DateTime(2026, 11, 5, 12, 30),
      createdAt: DateTime(2026, 11, 5),
    ));
    final csv = CsvExporter.buildCsv(await repo.exportRows());
    final lines = csv.split('\r\n');
    expect(lines.first, 'Tanggal,Jenis,Kategori,Jumlah,Dompet,Dompet Tujuan,Merchant,Catatan');
    expect(lines[1],
        '2026-11-05 12:30,Pengeluaran,Makan & Minum,25000,Tunai,,"Warung ""Bu Sri"", Depok",');
  });
}
