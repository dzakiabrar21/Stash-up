import 'package:flutter/foundation.dart';

import '../core/formatters.dart';
import '../data/models.dart';
import '../data/stash_repository.dart';
import '../services/settings_service.dart';

/// App-wide state. Every mutation goes to SQLite first, then reloads.
class AppState extends ChangeNotifier {
  AppState(this.repo, this.settings);

  final StashRepository repo;
  final SettingsService settings;

  static const recentLimit = 60;

  List<Wallet> wallets = const [];
  List<Txn> recent = const [];
  MonthTotal thisMonth = MonthTotal(DateTime(2000));

  /// Bumped on every change so screens with their own queries can reload.
  int revision = 0;

  int get totalBalance => wallets.fold(0, (sum, w) => sum + w.balance);

  Wallet? walletById(int? id) {
    for (final w in wallets) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Last used wallet, falling back to the first one.
  int? get defaultWalletId {
    final last = settings.lastWalletId;
    if (walletById(last) != null) return last;
    return wallets.isEmpty ? null : wallets.first.id;
  }

  Future<void> refresh() async {
    final now = DateTime.now();
    final results = await Future.wait([
      repo.getWallets(),
      repo.getTransactions(limit: recentLimit),
      repo.totals(monthStart(now), nextMonth(now)),
    ]);
    wallets = results[0] as List<Wallet>;
    recent = results[1] as List<Txn>;
    thisMonth = results[2] as MonthTotal;
    revision++;
    notifyListeners();
  }

  Future<void> saveTxn(Txn t) async {
    if (t.id == null) {
      await repo.insertTxn(t);
    } else {
      await repo.updateTxn(t);
    }
    await settings.setLastWalletId(t.walletId);
    await refresh();
  }

  Future<void> deleteTxn(int id) async {
    await repo.deleteTxn(id);
    await refresh();
  }

  Future<void> saveWallet(Wallet w) async {
    if (w.id == null) {
      await repo.insertWallet(w);
    } else {
      await repo.updateWallet(w);
    }
    await refresh();
  }

  Future<void> deleteWallet(int id) async {
    await repo.deleteWallet(id);
    await refresh();
  }
}
