import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stash/data/models.dart';
import 'package:stash/services/gemini_client.dart';
import 'package:stash/services/voice_scanner.dart';

Map<String, dynamic> geminiBody(Map<String, Object?> payload) => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(payload)},
            ],
          },
        },
      ],
    };

void main() {
  final now = DateTime(2026, 11, 9, 10);

  setUpAll(() => initializeDateFormatting('id_ID'));

  Wallet w(int id, String name) =>
      Wallet(id: id, name: name, kind: WalletKind.bank, color: 0, createdAt: DateTime(2026));

  group('VoiceEntryResult.fromJson', () {
    test('parses an expense', () {
      final r = VoiceEntryResult.fromJson({
        'is_transaction': true,
        'transcript': 'makan siang padang tiga puluh lima ribu pakai bca',
        'type': 'expense',
        'amount': 35000,
        'wallet': 'BCA',
        'category': 'food',
        'merchant': 'Warung Padang',
        'note': 'Makan siang',
        'date': '2026-11-08',
      }, now: now);
      expect(r.type, TxnType.expense);
      expect(r.amount, 35000);
      expect(r.walletName, 'BCA');
      expect(r.category, 'food');
      expect(r.merchant, 'Warung Padang');
      expect(r.date, DateTime(2026, 11, 8));
      expect(r.transcript, contains('makan siang'));
    });

    test('income and transfer pick the right category rules', () {
      final income = VoiceEntryResult.fromJson(
        {'type': 'income', 'amount': 5000000.0, 'category': 'salary', 'merchant': 'PT Maju'},
        now: now,
      );
      expect(income.type, TxnType.income);
      expect(income.amount, 5000000);
      expect(income.category, 'salary');
      expect(income.merchant, isNull, reason: 'merchant is for expenses only');

      final transfer = VoiceEntryResult.fromJson(
        {'type': 'transfer', 'amount': 250000, 'wallet': 'BCA', 'to_wallet': 'GoPay', 'category': 'transfer'},
        now: now,
      );
      expect(transfer.type, TxnType.transfer);
      expect(transfer.category, isNull);
      expect(transfer.toWalletName, 'GoPay');
    });

    test('sanitises bad values', () {
      final r = VoiceEntryResult.fromJson({
        'type': 'weird',
        'amount': -5,
        'category': 'crypto',
        'date': '2031-01-01',
        'wallet': '  ',
      }, now: now);
      expect(r.type, TxnType.expense);
      expect(r.amount, isNull);
      expect(r.category, 'other_expense');
      expect(r.date, isNull, reason: 'future dates are rejected');
      expect(r.walletName, isNull);

      expect(VoiceEntryResult.fromJson({'type': 'income', 'category': 'food'}).category, 'other_income');
      expect(VoiceEntryResult.fromJson({'is_transaction': false}).isTransaction, isFalse);
    });
  });

  test('resolveWalletId matches case-insensitively, then by containment', () {
    final wallets = [w(1, 'Tunai'), w(2, 'BCA'), w(3, 'Bank Jago')];
    expect(VoiceEntryResult.resolveWalletId('bca', wallets), 2);
    expect(VoiceEntryResult.resolveWalletId('Jago', wallets), 3);
    expect(VoiceEntryResult.resolveWalletId('rekening bca saya', wallets), 2);
    expect(VoiceEntryResult.resolveWalletId('OVO', wallets), isNull);
    expect(VoiceEntryResult.resolveWalletId(null, wallets), isNull);
  });

  test('sends the audio with wallet names and today\'s date', () async {
    late http.Request captured;
    final scanner = VoiceScanner(
      client: MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode(geminiBody({
            'is_transaction': true,
            'type': 'expense',
            'amount': 20000,
            'category': 'transport',
          })),
          200,
        );
      }),
    );
    final r = await scanner.parse(
      audioBytes: Uint8List.fromList([9, 8, 7]),
      mimeType: 'audio/wav',
      apiKey: 'test-key',
      model: 'gemini-3.6-flash',
      walletNames: ['Tunai', 'BCA'],
      now: now,
    );
    expect(r.amount, 20000);
    expect(captured.headers['x-goog-api-key'], 'test-key');
    expect(captured.url.path, endsWith('gemini-3.6-flash:generateContent'));

    final sent = jsonDecode(captured.body) as Map<String, dynamic>;
    final parts = sent['contents'][0]['parts'] as List;
    expect(parts[0]['text'], contains('Tunai, BCA'));
    expect(parts[0]['text'], contains('2026-11-09'));
    expect(parts[1]['inlineData']['mimeType'], 'audio/wav');
    expect(parts[1]['inlineData']['data'], base64Encode([9, 8, 7]));
    expect(sent['generationConfig']['responseMimeType'], 'application/json');
  });

  test('network and API errors become friendly messages', () async {
    final offline = VoiceScanner(client: MockClient((_) async => throw http.ClientException('no route')));
    expect(
      () => offline.parse(
        audioBytes: Uint8List(0),
        mimeType: 'audio/wav',
        apiKey: 'x',
        model: 'm',
        walletNames: const [],
      ),
      throwsA(isA<GeminiException>().having((e) => e.message, 'message', contains('internet'))),
    );

    final quota = VoiceScanner(client: MockClient((_) async => http.Response('{}', 429)));
    expect(
      () => quota.parse(
        audioBytes: Uint8List(0),
        mimeType: 'audio/wav',
        apiKey: 'x',
        model: 'm',
        walletNames: const [],
      ),
      throwsA(isA<GeminiException>().having((e) => e.message, 'message', contains('Kuota'))),
    );
  });
}
