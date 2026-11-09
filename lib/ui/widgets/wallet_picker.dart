import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../state/app_state.dart';
import 'stash_widgets.dart';

/// Bottom sheet that returns the chosen wallet id.
Future<int?> pickWallet(
  BuildContext context, {
  required String title,
  int? selected,
  int? exclude,
}) {
  final wallets = context.read<AppState>().wallets.where((w) => w.id != exclude).toList();
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final w in wallets)
                    ListTile(
                      leading: WalletAvatar(wallet: w),
                      title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(formatRupiah(w.balance)),
                      trailing: w.id == selected
                          ? const Icon(Icons.check_circle, color: StashColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, w.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
