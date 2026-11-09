import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/receipt_scanner.dart';
import '../services/settings_service.dart';
import 'screens/settings_screen.dart';

/// Returns the saved Gemini API key, or null after offering to open Settings
/// when none is set. [feature] names what needs the key, e.g. "Pemindai struk".
Future<String?> requireGeminiApiKey(BuildContext context, {required String feature}) async {
  final settings = context.read<SettingsService>();
  final navigator = Navigator.of(context);
  final apiKey = await settings.getGeminiApiKey();
  if (!context.mounted) return null;
  if (apiKey != null && apiKey.isNotEmpty) return apiKey;

  final openSettings = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.key_rounded),
      title: const Text('API key Gemini belum diatur'),
      content: Text(
        '$feature memakai Google Gemini. Masukkan API key gratis dari '
        'Google AI Studio di Pengaturan terlebih dahulu.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nanti')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Buka Pengaturan')),
      ],
    ),
  );
  if (openSettings == true) {
    await navigator.push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }
  return null;
}

/// Pick/take a receipt photo and send it to Gemini.
/// Returns null if the user cancelled or scanning failed (an error is shown).
Future<ReceiptScanResult?> scanReceipt(BuildContext context) async {
  final settings = context.read<SettingsService>();
  final scanner = context.read<ReceiptScanner>();
  final messenger = ScaffoldMessenger.of(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);

  void toast(String message) => messenger.showSnackBar(SnackBar(content: Text(message)));

  final apiKey = await requireGeminiApiKey(context, feature: 'Pemindai struk');
  if (apiKey == null || !context.mounted) return null;

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Foto struk'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
  } on PlatformException catch (e) {
    toast('Tidak bisa membuka kamera/galeri: ${e.message ?? e.code}');
    return null;
  }
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final mimeType = file.mimeType ?? _guessMime(file.name);
  if (!context.mounted) return null;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('Membaca struk dengan Gemini AI…')),
        ]),
      ),
    ),
  );

  try {
    final result = await scanner.scan(
      imageBytes: bytes,
      mimeType: mimeType,
      apiKey: apiKey,
      model: settings.geminiModel,
    );
    rootNavigator.pop();
    if (!result.isReceipt) {
      toast('Gambar tidak terlihat seperti struk. Coba foto ulang.');
      return null;
    }
    if (result.total == null) toast('Total tidak terbaca, silakan isi nominal manual.');
    return result;
  } on ReceiptScanException catch (e) {
    rootNavigator.pop();
    toast(e.message);
  } catch (e) {
    rootNavigator.pop();
    toast('Gagal memindai struk: $e');
  }
  return null;
}

String _guessMime(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}
