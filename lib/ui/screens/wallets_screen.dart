import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/stash_widgets.dart';
import '../widgets/transaction_list.dart';
import 'add_transaction_screen.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dompet'),
        actions: [
          IconButton(
            tooltip: 'Transfer antar dompet',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: state.wallets.length < 2
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const AddTransactionScreen(initialType: TxnType.transfer),
                    )),
          ),
          IconButton(
            tooltip: 'Tambah dompet',
            icon: const Icon(Icons.add_card_rounded),
            onPressed: () => showWalletForm(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          const Text(
            'Total saldo',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StashColors.muted),
          ),
          Text(
            formatRupiah(state.totalBalance),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          for (final w in state.wallets) ...[
            StashCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => WalletDetailScreen(walletId: w.id!),
              )),
              child: Row(children: [
                WalletAvatar(wallet: w),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(w.kind.label, style: const TextStyle(fontSize: 12.5, color: StashColors.muted)),
                  ]),
                ),
                Text(
                  formatRupiah(w.balance),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: w.balance < 0 ? StashColors.expense : StashColors.text,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => showWalletForm(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah dompet'),
          ),
        ],
      ),
    );
  }
}

class WalletDetailScreen extends StatefulWidget {
  const WalletDetailScreen({super.key, required this.walletId});
  final int walletId;

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  Future<List<Txn>>? _future;
  int _loadedRevision = -1;

  Future<void> _delete(Wallet w) async {
    final state = context.read<AppState>();
    if (state.wallets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal harus ada satu dompet.')),
      );
      return;
    }
    final count = await state.repo.countTransactionsForWallet(w.id!);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hapus ${w.name}?'),
        content: Text(count == 0
            ? 'Dompet ini akan dihapus.'
            : 'Dompet ini beserta $count transaksinya (termasuk transfer) akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StashColors.expense),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final navigator = Navigator.of(context);
    await state.deleteWallet(w.id!);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final wallet = state.walletById(widget.walletId);
    if (wallet == null) return Scaffold(appBar: AppBar());
    if (_loadedRevision != state.revision) {
      _loadedRevision = state.revision;
      _future = state.repo.getTransactions(walletId: widget.walletId, limit: 500);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(wallet.name),
        actions: [
          IconButton(
            tooltip: 'Ubah',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => showWalletForm(context, existing: wallet),
          ),
          IconButton(
            tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(wallet),
          ),
        ],
      ),
      floatingActionButton: GradientCircleButton(
        icon: Icons.add_rounded,
        size: 58,
        elevated: true,
        tooltip: 'Catat di dompet ini',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => AddTransactionScreen(initialWalletId: wallet.id),
        )),
      ),
      body: FutureBuilder<List<Txn>>(
        future: _future,
        builder: (context, snap) {
          final txns = snap.data ?? const <Txn>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: StashCard(
                  child: Row(children: [
                    WalletAvatar(wallet: wallet, size: 52),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text(
                          'Saldo saat ini',
                          style: TextStyle(fontSize: 12.5, color: StashColors.muted),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatRupiah(wallet.balance),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          'Saldo awal ${formatRupiah(wallet.initialBalance)}',
                          style: const TextStyle(fontSize: 12, color: StashColors.muted),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text('Riwayat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (snap.connectionState == ConnectionState.waiting && snap.data == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (txns.isEmpty)
                const EmptyState(icon: Icons.history_rounded, title: 'Belum ada riwayat')
              else
                ...buildTransactionList(context, txns, walletId: wallet.id),
            ],
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------------- wallet form

Future<void> showWalletForm(BuildContext context, {Wallet? existing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WalletForm(existing: existing),
    );

class _WalletForm extends StatefulWidget {
  const _WalletForm({this.existing});
  final Wallet? existing;

  @override
  State<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends State<_WalletForm> {
  late final TextEditingController _name;
  late final TextEditingController _initial;
  late WalletKind _kind;
  late int _color;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _initial = TextEditingController(
      text: e == null || e.initialBalance == 0 ? '' : formatNumber(e.initialBalance),
    );
    _kind = e?.kind ?? WalletKind.bank;
    _color = e?.color ?? walletColors.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final initial = int.tryParse(_initial.text.replaceAll('.', '')) ?? 0;
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    final e = widget.existing;
    await state.saveWallet(
      e == null
          ? Wallet(
              name: name,
              kind: _kind,
              color: _color,
              initialBalance: initial,
              createdAt: DateTime.now(),
            )
          : e.copyWith(name: name, kind: _kind, color: _color, initialBalance: initial),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Ubah dompet' : 'Dompet baru',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (!isEdit) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final p in walletPresets)
                    ActionChip(
                      avatar: Icon(walletIcon(p.kind), size: 18, color: Color(p.color)),
                      label: Text(p.name),
                      onPressed: () => setState(() {
                        _name.text = p.name;
                        _kind = p.kind;
                        _color = p.color;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama dompet'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            SegmentedButton<WalletKind>(
              segments: [
                for (final k in WalletKind.values)
                  ButtonSegment(value: k, label: Text(k.label), icon: Icon(walletIcon(k))),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _initial,
              keyboardType: TextInputType.number,
              inputFormatters: [_ThousandsFormatter()],
              decoration: const InputDecoration(labelText: 'Saldo awal', prefixText: 'Rp '),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in walletColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(c),
                      child: c == _color
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _name.text.trim().isEmpty ? null : _save,
              child: Text(isEdit ? 'Simpan' : 'Tambah dompet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > 13) digits = digits.substring(0, 13);
    final formatted = formatNumber(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
