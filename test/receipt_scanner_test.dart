import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stash/services/receipt_scanner.dart';

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
  final now = DateTime(2026, 11, 7);

  test('parses a structured Gemini response', () {
    final r = ReceiptScanResult.fromGeminiResponse(
      geminiBody({
        'is_receipt': true,
        'merchant': 'Indomaret',
        'total': 48500,
        'date': '2026-11-06',
        'category': 'groceries',
        'items_summary': 'Susu, roti, telur',
      }),
      now: now,
    );
    expect(r.isReceipt, isTrue);
    expect(r.total, 48500);
    expect(r.merchant, 'Indomaret');
    expect(r.date, DateTime(2026, 11, 6));
    expect(r.category, 'groceries');
  });

  test('sanitises bad values', () {
    final r = ReceiptScanResult.fromJson({
      'is_receipt': true,
      'merchant': '  ',
      'total': 'Rp 25.000',
      'date': '2031-01-01',
      'category': 'crypto',
    }, now: now);
    expect(r.total, 25000);
    expect(r.merchant, isNull);
    expect(r.date, isNull, reason: 'future dates are rejected');
    expect(r.category, 'other_expense');
  });

  test('strips markdown fences', () {
    final body = {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': '```json\n{"is_receipt": true, "total": 1000, "category": "food"}\n```'},
            ],
          },
        },
      ],
    };
    expect(ReceiptScanResult.fromGeminiResponse(body, now: now).total, 1000);
  });

  test('sends image and maps API errors to friendly messages', () async {
    late http.Request captured;
    final ok = ReceiptScanner(
      client: MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode(geminiBody({'is_receipt': true, 'total': 12000, 'category': 'food'})),
          200,
        );
      }),
    );
    final result = await ok.scan(
      imageBytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/jpeg',
      apiKey: 'test-key',
      model: 'gemini-2.5-flash',
    );
    expect(result.total, 12000);
    expect(captured.headers['x-goog-api-key'], 'test-key');
    expect(captured.url.path, endsWith('gemini-2.5-flash:generateContent'));
    final sent = jsonDecode(captured.body) as Map<String, dynamic>;
    final inline = sent['contents'][0]['parts'][1]['inlineData'] as Map<String, dynamic>;
    expect(inline['data'], base64Encode([1, 2, 3]));

    final bad = ReceiptScanner(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'error': {
                'message': 'API key not valid.',
                'details': [
                  {'reason': 'API_KEY_INVALID'},
                ],
              },
            }),
            400,
          )),
    );
    expect(
      () => bad.scan(
        imageBytes: Uint8List(0),
        mimeType: 'image/jpeg',
        apiKey: 'x',
        model: 'gemini-2.5-flash',
      ),
      throwsA(isA<ReceiptScanException>()
          .having((e) => e.message, 'message', contains('tidak valid'))),
    );
  });
}
