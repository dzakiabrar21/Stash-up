import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../receipt_scan_flow.dart';
import '../widgets/stash_widgets.dart';
import '../widgets/transaction_list.dart';
import 'add_transaction_screen.dart';
import 'wallets_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// Keeps the front page short; the full history lives in each wallet.
  static const recentShown = 10;

  static Future<void> openAdd(BuildContext context, {TxnType type = TxnType.expense}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AddTransactionScreen(initialType: type)),
      );

  static Future<void> openScan(BuildContext context) async {
    final result = await scanReceipt(context);
    if (result == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AddTransactionScreen(prefill: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final recent = state.recent.take(recentShown).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stash', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Pindai struk',
            icon: const Icon(Icons.document_scanner_rounded, color: StashColors.primary),
            onPressed: () => openScan(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _BalanceCard(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(children: [
                _QuickAction(
                  icon: Icons.edit_note_rounded,
                  label: 'Catat',
                  onTap: () => openAdd(context),
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  icon: Icons.document_scanner_rounded,
                  label: 'Scan struk',
                  onTap: () => openScan(context),
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transfer',
                  onTap: () => openAdd(context, type: TxnType.transfer),
                ),
              ]),
            ),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: state.wallets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final w = state.wallets[i];
                  return StashCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => WalletDetailScreen(walletId: w.id!),
                    )),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      WalletAvatar(wallet: w, size: 38),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            formatRupiah(w.balance),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: w.balance < 0 ? StashColors.expense : StashColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ]),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text('Transaksi terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (recent.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Belum ada transaksi',
                message: 'Tekan tombol + untuk mencatat, atau pindai struk belanja.',
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StashCard(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(children: buildTransactionList(context, recent)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    const white70 = TextStyle(fontSize: 12, color: Color(0xB3FFFFFF));

    Widget stat(IconData icon, String label, int value, Color color) => Expanded(
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: white70),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupiah(value),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: StashGradients.hero,
        borderRadius: BorderRadius.circular(24),
        boxShadow: StashShadows.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total saldo', style: TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatRupiah(state.totalBalance),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Color(0x26FFFFFF), height: 1),
          ),
          Text(formatMonth(DateTime.now()), style: white70),
          const SizedBox(height: 8),
          Row(children: [
            stat(Icons.south_west_rounded, 'Pemasukan', state.thisMonth.income, StashColors.heroIncome),
            const SizedBox(width: 12),
            stat(Icons.north_east_rounded, 'Pengeluaran', state.thisMonth.expense, StashColors.heroExpense),
          ]),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StashCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: StashColors.primaryTint, shape: BoxShape.circle),
            child: Icon(icon, color: StashColors.primary, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
