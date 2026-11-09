import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/categories.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../screens/add_transaction_screen.dart';

/// Builds sliver-friendly children: day headers followed by transaction tiles.
/// [walletId], when set, signs transfers from that wallet's perspective.
List<Widget> buildTransactionList(BuildContext context, List<Txn> txns, {int? walletId}) {
  final widgets = <Widget>[];
  DateTime? currentDay;
  for (var i = 0; i < txns.length; i++) {
    final t = txns[i];
    final day = dayOf(t.date);
    if (day != currentDay) {
      currentDay = day;
      var net = 0;
      for (final o in txns.skip(i)) {
        if (dayOf(o.date) != day) break;
        net += walletId != null ? o.effectOn(walletId) : _netEffect(o);
      }
      widgets.add(_DayHeader(day: day, net: net));
    }
    widgets.add(TransactionTile(txn: t, walletId: walletId));
  }
  return widgets;
}

int _netEffect(Txn t) => switch (t.type) {
      TxnType.income => t.amount,
      TxnType.expense => -t.amount,
      TxnType.transfer => 0,
    };

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.net});
  final DateTime day;
  final int net;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: StashColors.muted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(children: [
        Expanded(child: Text(formatDayLabel(day), style: style)),
        if (net != 0) Text(formatSignedRupiah(net), style: style),
      ]),
    );
  }
}

/// One transaction row: category icon, merchant + meta, signed amount.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.txn, this.walletId});

  final Txn txn;
  final int? walletId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cat = categoryById(txn.category, txn.type);
    final wallet = state.walletById(txn.walletId);
    final toWallet = state.walletById(txn.toWalletId);

    final title = txn.type == TxnType.transfer
        ? 'Transfer'
        : (txn.merchant?.isNotEmpty ?? false)
            ? txn.merchant!
            : cat.label;

    final walletText = txn.type == TxnType.transfer
        ? '${wallet?.name ?? '?'} → ${toWallet?.name ?? '?'}'
        : wallet?.name ?? '?';
    final subtitleParts = [
      if (txn.type != TxnType.transfer && title != cat.label) cat.label,
      walletText,
      if (txn.note?.isNotEmpty ?? false) txn.note!,
    ];

    final signed = walletId != null
        ? txn.effectOn(walletId!)
        : switch (txn.type) {
            TxnType.income => txn.amount,
            TxnType.expense => -txn.amount,
            TxnType.transfer => 0,
          };
    final Color amountColor;
    final String amountText;
    if (txn.type == TxnType.transfer && walletId == null) {
      amountColor = StashColors.transfer;
      amountText = formatRupiah(txn.amount);
    } else if (signed > 0) {
      amountColor = StashColors.income;
      amountText = formatSignedRupiah(signed);
    } else if (signed < 0) {
      amountColor = StashColors.expense;
      amountText = formatRupiah(signed);
    } else {
      amountColor = StashColors.muted;
      amountText = formatRupiah(txn.amount);
    }

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AddTransactionScreen(existing: txn)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(cat.icon, size: 21, color: cat.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
              const SizedBox(height: 2),
              Text(
                subtitleParts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: StashColors.muted),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Text(
            amountText,
            style: TextStyle(color: amountColor, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: StashColors.primaryTint, shape: BoxShape.circle),
          child: Icon(icon, size: 26, color: StashColors.primary),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(
            message!,
            style: const TextStyle(color: StashColors.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ]),
    );
  }
}
