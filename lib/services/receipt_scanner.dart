import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/categories.dart';
import 'gemini_client.dart';

/// Kept for existing call sites; every Gemini feature throws [GeminiException].
typedef ReceiptScanException = GeminiException;

class ReceiptScanResult {
  const ReceiptScanResult({
    required this.isReceipt,
    this.total,
    this.merchant,
    this.date,
    this.category,
    this.itemsSummary,
  });

  final bool isReceipt;
  final int? total;
  final String? merchant;
  final DateTime? date;
  final String? category;
  final String? itemsSummary;

  factory ReceiptScanResult.fromJson(Map<String, dynamic> j, {DateTime? now}) {
    final today = now ?? DateTime.now();

    int? total;
    final rawTotal = j['total'];
    if (rawTotal is num) {
      total = rawTotal.round();
    } else if (rawTotal is String) {
      total = int.tryParse(rawTotal.replaceAll(RegExp(r'[^0-9]'), ''));
    }
    if (total != null && total <= 0) total = null;

    DateTime? date;
    final rawDate = j['date'];
    if (rawDate is String) {
      final parsed = DateTime.tryParse(rawDate.trim());
      // Reject obviously wrong years and future dates.
      if (parsed != null &&
          parsed.year >= 2000 &&
          !parsed.isAfter(today.add(const Duration(days: 1)))) {
        date = parsed;
      }
    }

    final rawCategory = j['category'];
    final category = rawCategory is String && expenseCategoryIds.contains(rawCategory)
        ? rawCategory
        : 'other_expense';

    String? clean(Object? v) {
      if (v is! String) return null;
      final s = v.trim();
      return s.isEmpty ? null : s;
    }

    return ReceiptScanResult(
      isReceipt: j['is_receipt'] != false,
      total: total,
      merchant: clean(j['merchant']),
      date: date,
      category: category,
      itemsSummary: clean(j['items_summary']),
    );
  }

  /// Parses a raw `generateContent` response body.
  factory ReceiptScanResult.fromGeminiResponse(Map<String, dynamic> body, {DateTime? now}) =>
      ReceiptScanResult.fromJson(GeminiClient.extractJson(body), now: now);
}

/// Turns a receipt photo into structured data using the Gemini API.
///
/// The image is sent to Google only when the user explicitly scans a receipt.
class ReceiptScanner {
  ReceiptScanner({http.Client? client}) : _gemini = GeminiClient(client: client);

  final GeminiClient _gemini;

  static String get _prompt => '''
Kamu adalah asisten yang membaca struk/nota belanja (umumnya dari Indonesia).
Ambil data berikut dari gambar:
- is_receipt: false jika gambar jelas bukan struk/nota/invoice.
- merchant: nama toko/merchant seperti tertulis di struk.
- total: total akhir yang dibayar (setelah pajak, diskon, service charge) dalam Rupiah,
  sebagai angka bulat tanpa pemisah. Di Indonesia titik adalah pemisah ribuan
  ("Rp 25.000" = 25000). Gunakan baris seperti TOTAL / GRAND TOTAL / TOTAL BAYAR.
  JANGAN gunakan TUNAI, CASH, BAYAR, atau KEMBALI (itu uang yang diserahkan/kembalian).
- date: tanggal transaksi format YYYY-MM-DD (struk Indonesia biasanya DD/MM/YY atau DD-MM-YYYY).
  Isi null jika tidak terbaca.
- category: pilih satu dari: ${expenseCategoryIds.join(', ')}.
  (food = makan/minum/restoran/kafe, groceries = supermarket/minimarket kebutuhan harian,
  transport = bensin/parkir/tol/ojek, shopping = pakaian/elektronik/barang,
  bills = listrik/air/pulsa/internet, entertainment = bioskop/hiburan,
  health = apotek/klinik, education = buku/kursus).
- items_summary: ringkasan singkat barang utama, maksimal 60 karakter.
Jika suatu nilai tidak terbaca, isi null. Jangan mengarang angka.''';

  static final Map<String, Object> _schema = {
    'type': 'OBJECT',
    'properties': {
      'is_receipt': {'type': 'BOOLEAN'},
      'merchant': {'type': 'STRING', 'nullable': true},
      'total': {'type': 'NUMBER', 'nullable': true},
      'date': {'type': 'STRING', 'nullable': true, 'description': 'YYYY-MM-DD'},
      'category': {'type': 'STRING', 'enum': expenseCategoryIds},
      'items_summary': {'type': 'STRING', 'nullable': true},
    },
    'required': ['is_receipt', 'category'],
  };

  Future<ReceiptScanResult> scan({
    required Uint8List imageBytes,
    required String mimeType,
    required String apiKey,
    required String model,
  }) async {
    final json = await _gemini.generateJson(
      apiKey: apiKey,
      model: model,
      parts: [
        {'text': _prompt},
        {
          'inlineData': {'mimeType': mimeType, 'data': base64Encode(imageBytes)},
        },
      ],
      responseSchema: _schema,
    );
    return ReceiptScanResult.fromJson(json);
  }
}
