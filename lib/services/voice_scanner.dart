import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../core/categories.dart';
import '../data/models.dart';
import 'gemini_client.dart';

/// A transaction understood from a spoken sentence.
class VoiceEntryResult {
  const VoiceEntryResult({
    required this.isTransaction,
    required this.type,
    this.amount,
    this.walletName,
    this.toWalletName,
    this.category,
    this.merchant,
    this.note,
    this.date,
    this.transcript,
  });

  final bool isTransaction;
  final TxnType type;
  final int? amount;

  /// Wallet names as Gemini returned them; resolve with [resolveWalletId].
  final String? walletName;
  final String? toWalletName;
  final String? category;
  final String? merchant;
  final String? note;
  final DateTime? date;

  /// What Gemini heard, shown to the user so they can spot mistakes.
  final String? transcript;

  static List<String> get _incomeIds => [for (final c in incomeCategories) c.id];

  factory VoiceEntryResult.fromJson(Map<String, dynamic> j, {DateTime? now}) {
    final today = now ?? DateTime.now();

    String? clean(Object? v) {
      if (v is! String) return null;
      final s = v.trim();
      return s.isEmpty ? null : s;
    }

    final type = switch (j['type']) {
      'income' => TxnType.income,
      'transfer' => TxnType.transfer,
      _ => TxnType.expense,
    };

    int? amount;
    final rawAmount = j['amount'];
    if (rawAmount is num) {
      amount = rawAmount.round();
    } else if (rawAmount is String) {
      amount = int.tryParse(rawAmount.replaceAll(RegExp(r'[^0-9]'), ''));
    }
    if (amount != null && amount <= 0) amount = null;

    DateTime? date;
    final rawDate = j['date'];
    if (rawDate is String) {
      final parsed = DateTime.tryParse(rawDate.trim());
      if (parsed != null &&
          parsed.year >= 2000 &&
          !parsed.isAfter(today.add(const Duration(days: 1)))) {
        date = parsed;
      }
    }

    final rawCategory = j['category'];
    String? category;
    if (type == TxnType.expense) {
      category = rawCategory is String && expenseCategoryIds.contains(rawCategory)
          ? rawCategory
          : 'other_expense';
    } else if (type == TxnType.income) {
      category = rawCategory is String && _incomeIds.contains(rawCategory)
          ? rawCategory
          : 'other_income';
    }

    return VoiceEntryResult(
      isTransaction: j['is_transaction'] != false,
      type: type,
      amount: amount,
      walletName: clean(j['wallet']),
      toWalletName: clean(j['to_wallet']),
      category: category,
      merchant: type == TxnType.expense ? clean(j['merchant']) : null,
      note: clean(j['note']),
      date: date,
      transcript: clean(j['transcript']),
    );
  }

  /// Finds the wallet whose name matches [name] (case-insensitive, exact first,
  /// then containment). Returns null when nothing matches.
  static int? resolveWalletId(String? name, List<Wallet> wallets) {
    if (name == null) return null;
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final w in wallets) {
      if (w.name.trim().toLowerCase() == n) return w.id;
    }
    for (final w in wallets) {
      final wn = w.name.trim().toLowerCase();
      if (wn.contains(n) || n.contains(wn)) return w.id;
    }
    return null;
  }
}

/// Understands a short voice note ("makan siang padang 35 ribu pakai BCA")
/// using Gemini's audio input. The recording is sent to Google only when the
/// user records one.
class VoiceScanner {
  VoiceScanner({http.Client? client}) : _gemini = GeminiClient(client: client);

  final GeminiClient _gemini;

  static String _prompt(List<String> walletNames, DateTime now) {
    final today = DateFormat('EEEE, yyyy-MM-dd', 'id_ID').format(now);
    return '''
Kamu mencatat transaksi keuangan pribadi dari ucapan singkat dalam Bahasa Indonesia.
Dengarkan audio dan ekstrak satu transaksi.
- is_transaction: false jika ucapan jelas bukan tentang uang/transaksi atau tidak terdengar.
- transcript: apa yang kamu dengar, apa adanya.
- type: "expense" (pengeluaran, default), "income" (gaji, bonus, dapat uang, terima uang)
  atau "transfer" (memindahkan uang antar dompet).
- amount: jumlah Rupiah sebagai angka bulat. "ribu"/"rb"/"k" = x1.000, "juta"/"jt" = x1.000.000,
  "setengah juta" = 500000, "dua setengah juta" = 2500000, "seratus lima puluh ribu" = 150000.
  Isi null jika tidak disebut.
- wallet: nama dompet sumber (atau dompet tujuan untuk income), HARUS persis salah satu dari:
  ${walletNames.join(', ')}. Isi null jika tidak disebut.
- to_wallet: dompet tujuan untuk transfer, dari daftar yang sama; selain transfer isi null.
- category: untuk expense pilih dari ${expenseCategoryIds.join(', ')};
  untuk income pilih dari ${[for (final c in incomeCategories) c.id].join(', ')};
  untuk transfer pakai "transfer".
  (food = makan/minum, groceries = belanja harian/minimarket, transport = bensin/parkir/ojek,
  shopping = barang/pakaian, bills = listrik/pulsa/internet, entertainment = hiburan,
  health = obat/dokter, education = buku/kursus)
- merchant: nama toko/tempat jika disebut (expense), selain itu null.
- note: keterangan singkat (misal apa yang dibeli), maksimal 60 karakter, atau null.
- date: YYYY-MM-DD. Hari ini adalah $today. Pahami "kemarin", "tadi pagi", "lusa kemarin",
  "hari senin kemarin". Jika tidak disebut, isi null (artinya hari ini).
Jangan mengarang angka atau nama yang tidak diucapkan.''';
  }

  static Map<String, Object> get _schema => {
        'type': 'OBJECT',
        'properties': {
          'is_transaction': {'type': 'BOOLEAN'},
          'transcript': {'type': 'STRING', 'nullable': true},
          'type': {
            'type': 'STRING',
            'enum': ['expense', 'income', 'transfer'],
          },
          'amount': {'type': 'NUMBER', 'nullable': true},
          'wallet': {'type': 'STRING', 'nullable': true},
          'to_wallet': {'type': 'STRING', 'nullable': true},
          'category': {
            'type': 'STRING',
            'enum': [
              ...expenseCategoryIds,
              for (final c in incomeCategories) c.id,
              'transfer',
            ],
          },
          'merchant': {'type': 'STRING', 'nullable': true},
          'note': {'type': 'STRING', 'nullable': true},
          'date': {'type': 'STRING', 'nullable': true, 'description': 'YYYY-MM-DD'},
        },
        'required': ['is_transaction', 'type', 'category'],
      };

  Future<VoiceEntryResult> parse({
    required Uint8List audioBytes,
    required String mimeType,
    required String apiKey,
    required String model,
    required List<String> walletNames,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final json = await _gemini.generateJson(
      apiKey: apiKey,
      model: model,
      parts: [
        {'text': _prompt(walletNames, today)},
        {
          'inlineData': {'mimeType': mimeType, 'data': base64Encode(audioBytes)},
        },
      ],
      responseSchema: _schema,
    );
    return VoiceEntryResult.fromJson(json, now: today);
  }
}
