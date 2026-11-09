import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A Gemini call failed; [message] is safe to show to the user (Indonesian).
class GeminiException implements Exception {
  const GeminiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thin client for `models/<model>:generateContent` that returns the model's
/// JSON answer. Shared by the receipt scanner and the voice-note scanner.
class GeminiClient {
  GeminiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const offlineMessage = 'Tidak ada koneksi internet. Fitur ini butuh internet, '
      'tapi pencatatan manual tetap bisa offline.';

  /// Sends [parts] (text and `inlineData` parts) and asks for JSON matching
  /// [responseSchema].
  Future<Map<String, dynamic>> generateJson({
    required String apiKey,
    required String model,
    required List<Map<String, Object>> parts,
    required Map<String, Object> responseSchema,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
    final body = jsonEncode({
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
      },
    });

    final http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
            body: body,
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const GeminiException('Waktu habis saat menghubungi Gemini. Coba lagi.');
    } on SocketException {
      throw const GeminiException(offlineMessage);
    } on http.ClientException {
      throw const GeminiException(offlineMessage);
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } on FormatException {
      json = null;
    }

    if (res.statusCode != 200) {
      final error = json?['error'] as Map<String, dynamic>?;
      final apiMessage = error?['message'] as String? ?? 'HTTP ${res.statusCode}';
      final details = jsonEncode(error?['details'] ?? const []);
      if (details.contains('API_KEY_INVALID') || res.statusCode == 401) {
        throw const GeminiException('API key Gemini tidak valid. Periksa di Pengaturan.');
      }
      if (res.statusCode == 429) {
        throw const GeminiException(
          'Kuota Gemini habis atau terlalu banyak permintaan. Coba lagi nanti.',
        );
      }
      if (res.statusCode == 404) {
        throw GeminiException('Model "$model" tidak ditemukan. Ganti model di Pengaturan.');
      }
      throw GeminiException('Gemini error: $apiMessage');
    }
    if (json == null) throw const GeminiException('Respons Gemini tidak valid.');
    return extractJson(json);
  }

  /// Pulls the JSON object out of a raw `generateContent` response body.
  static Map<String, dynamic> extractJson(Map<String, dynamic> body) {
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      final reason = (body['promptFeedback'] as Map?)?['blockReason'];
      throw GeminiException(
        reason != null ? 'Masukan ditolak oleh Gemini ($reason).' : 'Gemini tidak memberi jawaban.',
      );
    }
    final parts = ((candidates.first as Map)['content'] as Map?)?['parts'];
    if (parts is! List) throw const GeminiException('Gemini tidak memberi jawaban.');
    var text = parts.map((p) => (p as Map)['text'] ?? '').join().trim();
    // Defensive: strip ```json fences if the model added them anyway.
    text = text.replaceAll(RegExp(r'^```(?:json)?|```$'), '').trim();
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    } on FormatException {
      throw const GeminiException('Hasil tidak bisa dibaca. Coba ulangi.');
    }
  }
}
