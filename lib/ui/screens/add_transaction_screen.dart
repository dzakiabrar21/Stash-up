import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/amount_expression.dart';
import '../../core/categories.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/receipt_scanner.dart';
import '../../services/voice_scanner.dart';
import '../../state/app_state.dart';
import '../receipt_scan_flow.dart';
import '../voice_flow.dart';
import '../widgets/numpad.dart';
import '../widgets/stash_widgets.dart';
import '../widgets/wallet_picker.dart';

/// Quick input: amount on a calculator numpad, tap a category, tap ✓.
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.existing,
    this.initialType = TxnType.expense,
    this.initialWalletId,
    this.prefill,
  });

  final Txn? existing;
  final TxnType initialType;
  final int? initialWalletId;
  final ReceiptScanResult? prefill;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late TxnType _type;
  late AmountExpression _amount;
  int? _walletId;
  int? _toWalletId;
  String _expenseCategory = expenseCategories.first.id;
  String _incomeCategory = incomeCategories.first.id;
  late DateTime _date;
  final _merchantCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  /// Shown when the form was filled by Gemini (receipt photo or voice).
  String? _aiBanner;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final e = widget.existing;
    if (e != null) {
      _type = e.type;
      _amount = AmountExpression('${e.amount}');
      _walletId = e.walletId;
      _toWalletId = e.toWalletId;
      if (e.type == TxnType.expense && e.category != null) {
        _expenseCategory = e.category!;
      }
      if (e.type == TxnType.income && e.category != null) {
        _incomeCategory = e.category!;
      }
      _date = e.date;
      _merchantCtrl.text = e.merchant ?? '';
      _noteCtrl.text = e.note ?? '';
    } else {
      _type = widget.initialType;
      _amount = AmountExpression();
      _walletId = widget.initialWalletId ?? state.defaultWalletId;
      _date = DateTime.now();
      if (_type == TxnType.transfer) _toWalletId = _firstOtherWallet(state);
    }
    if (widget.prefill != null) _applyScan(widget.prefill!);
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int? _firstOtherWallet(AppState state) {
    for (final w in state.wallets) {
      if (w.id != _walletId) return w.id;
    }
    return null;
  }

  void _applyScan(ReceiptScanResult r) {
    _type = TxnType.expense;
    if (r.total != null) _amount = AmountExpression('${r.total}');
    if (r.merchant != null) _merchantCtrl.text = r.merchant!;
    if (r.date != null) {
      final now = DateTime.now();
      _date = DateTime(r.date!.year, r.date!.month, r.date!.day, now.hour, now.minute);
    }
    if (r.category != null) _expenseCategory = r.category!;
    if (r.itemsSummary != null && _noteCtrl.text.isEmpty) {
      _noteCtrl.text = r.itemsSummary!;
    }
    _aiBanner = 'Diisi otomatis oleh Gemini AI — periksa sebelum menyimpan.';
  }

  Future<void> _scan() async {
    final result = await scanReceipt(context);
    if (result != null && mounted) setState(() => _applyScan(result));
  }

  void _applyVoice(VoiceEntryResult r, AppState state) {
    _type = r.type;
    if (r.amount != null) _amount = AmountExpression('${r.amount}');
    final from = VoiceEntryResult.resolveWalletId(r.walletName, state.wallets);
    if (from != null) _walletId = from;
    if (r.type == TxnType.transfer) {
      final to = VoiceEntryResult.resolveWalletId(r.toWalletName, state.wallets);
      _toWalletId = (to != null && to != _walletId) ? to : _firstOtherWallet(state);
    }
    if (r.type == TxnType.expense && r.category != null) _expenseCategory = r.category!;
    if (r.type == TxnType.income && r.category != null) _incomeCategory = r.category!;
    if (r.merchant != null) _merchantCtrl.text = r.merchant!;
    if (r.note != null) _noteCtrl.text = r.note!;
    if (r.date != null) {
      final now = DateTime.now();
      _date = DateTime(r.date!.year, r.date!.month, r.date!.day, now.hour, now.minute);
    }
    final heard = r.transcript;
    _aiBanner = heard == null
        ? 'Diisi dari suaramu — periksa sebelum menyimpan.'
        : 'Terdengar: “$heard”. Periksa sebelum menyimpan.';
  }

  Future<void> _voice() async {
    final state = context.read<AppState>();
    final result = await recordVoiceEntry(context);
    if (result != null && mounted) setState(() => _applyVoice(result, state));
  }

  String? get _category => switch (_type) {
        TxnType.expense => _expenseCategory,
        TxnType.income => _incomeCategory,
        TxnType.transfer => null,
      };

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (_saving) return;
    final amount = _amount.value;
    if (amount == null || amount <= 0) {
      _toast('Masukkan nominal terlebih dahulu');
      return;
    }
    if (_walletId == null) {
      _toast('Pilih dompet');
      return;
    }
    if (_type == TxnType.transfer && (_toWalletId == null || _toWalletId == _walletId)) {
      _toast('Pilih dompet tujuan yang berbeda');
      return;
    }
    setState(() => _saving = true);
    final merchant = _merchantCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final txn = Txn(
      id: widget.existing?.id,
      type: _type,
      amount: amount,
      walletId: _walletId!,
      toWalletId: _type == TxnType.transfer ? _toWalletId : null,
      category: _category,
      merchant: _type == TxnType.expense && merchant.isNotEmpty ? merchant : null,
      note: note.isEmpty ? null : note,
      date: _date,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    final navigator = Navigator.of(context);
    await context.read<AppState>().saveTxn(txn);
    navigator.pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Transaksi ini akan dihapus permanen.'),
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
    await context.read<AppState>().deleteTxn(widget.existing!.id!);
    navigator.pop(true);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final wallet = state.walletById(_walletId);
    final toWallet = state.walletById(_toWalletId);
    final typeColor = StashColors.forType(_type);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah transaksi' : 'Catat transaksi'),
        actions: [
          if (!_isEdit)
            IconButton(
              tooltip: 'Catat dengan suara',
              icon: const Icon(Icons.mic_rounded, color: StashColors.primary),
              onPressed: _voice,
            ),
          if (_type != TxnType.transfer)
            IconButton(
              tooltip: 'Pindai struk',
              icon: const Icon(Icons.document_scanner_rounded, color: StashColors.primary),
              onPressed: _scan,
            ),
          if (_isEdit)
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline_rounded, color: StashColors.expense),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TxnTypeTabs(
                selected: _type,
                onChanged: (t) => setState(() {
                  _type = t;
                  if (_type == TxnType.transfer && (_toWalletId == null || _toWalletId == _walletId)) {
                    _toWalletId = _firstOtherWallet(state);
                  }
                }),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_aiBanner != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: StashColors.primaryTint,
                        borderRadius: BorderRadius.circular(StashRadius.field),
                      ),
                      child: Row(children: [
                        const Icon(Icons.auto_awesome_rounded, size: 18, color: StashColors.primaryDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _aiBanner!,
                            style: const TextStyle(fontSize: 12.5, color: StashColors.primaryDark),
                          ),
                        ),
                      ]),
                    ),
                  _AmountDisplay(expression: _amount, color: typeColor),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: Icon(walletIcon(wallet?.kind ?? WalletKind.cash), size: 18),
                        label: Text(_type == TxnType.transfer
                            ? 'Dari: ${wallet?.name ?? 'Pilih'}'
                            : wallet?.name ?? 'Pilih dompet'),
                        onPressed: () async {
                          final id = await pickWallet(context,
                              title: _type == TxnType.transfer ? 'Dari dompet' : 'Dompet',
                              selected: _walletId);
                          if (id != null) {
                            setState(() {
                              _walletId = id;
                              if (_toWalletId == id) _toWalletId = _firstOtherWallet(state);
                            });
                          }
                        },
                      ),
                      if (_type == TxnType.transfer)
                        ActionChip(
                          avatar: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: Text('Ke: ${toWallet?.name ?? 'Pilih'}'),
                          onPressed: () async {
                            final id = await pickWallet(context,
                                title: 'Ke dompet', selected: _toWalletId, exclude: _walletId);
                            if (id != null) setState(() => _toWalletId = id);
                          },
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_today_rounded, size: 18),
                        label: Text(dayOf(_date) == dayOf(DateTime.now()) ||
                                dayOf(_date) == dayOf(DateTime.now().subtract(const Duration(days: 1)))
                            ? formatDayLabel(_date)
                            : DateFormat('d MMM yyyy', 'id_ID').format(_date)),
                        onPressed: _pickDate,
                      ),
                    ],
                  ),
                  if (_type != TxnType.transfer) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final c in categoriesFor(_type))
                          ChoiceChip(
                            avatar: Icon(c.icon, size: 18, color: c.color),
                            label: Text(c.label),
                            showCheckmark: false,
                            selected: _category == c.id,
                            onSelected: (_) => setState(() {
                              if (_type == TxnType.expense) {
                                _expenseCategory = c.id;
                              } else {
                                _incomeCategory = c.id;
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_type == TxnType.expense) ...[
                    TextField(
                      controller: _merchantCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.storefront_rounded),
                        hintText: 'Toko / merchant (opsional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _noteCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.notes_rounded),
                      hintText: 'Catatan (opsional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Numpad(
                expression: _amount,
                submitEnabled: !_saving,
                onChanged: () {
                  FocusScope.of(context).unfocus();
                  setState(() {});
                },
                onSubmit: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.expression, required this.color});
  final AmountExpression expression;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = expression.value ?? 0;
    final compact = MediaQuery.sizeOf(context).height < 700;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            height: 22,
            child: expression.hasOperator
                ? Text(
                    expression.display,
                    style: const TextStyle(fontSize: 16, color: StashColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatRupiah(value),
              style: TextStyle(fontSize: compact ? 32 : 38, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
