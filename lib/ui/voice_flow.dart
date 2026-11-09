import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../core/theme.dart';
import '../services/gemini_client.dart';
import '../services/settings_service.dart';
import '../services/voice_scanner.dart';
import '../state/app_state.dart';
import 'receipt_scan_flow.dart';

/// Records a short voice note and has Gemini turn it into a transaction draft.
/// Returns null if the user cancelled or it failed (the sheet shows why).
Future<VoiceEntryResult?> recordVoiceEntry(BuildContext context) async {
  final settings = context.read<SettingsService>();
  final scanner = context.read<VoiceScanner>();
  final walletNames = [for (final w in context.read<AppState>().wallets) w.name];

  final apiKey = await requireGeminiApiKey(context, feature: 'Catat dengan suara');
  if (apiKey == null || !context.mounted) return null;

  return showModalBottomSheet<VoiceEntryResult>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    builder: (_) => _VoiceSheet(
      scanner: scanner,
      apiKey: apiKey,
      model: settings.geminiModel,
      walletNames: walletNames,
    ),
  );
}

enum _Phase { starting, recording, processing, error }

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet({
    required this.scanner,
    required this.apiKey,
    required this.model,
    required this.walletNames,
  });

  final VoiceScanner scanner;
  final String apiKey;
  final String model;
  final List<String> walletNames;

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> with SingleTickerProviderStateMixin {
  static const _maxSeconds = 30;
  // 16 kHz, 16-bit mono WAV is 32,000 bytes/s; below ~0.5 s is just a tap.
  static const _minBytes = 16000;

  final _recorder = AudioRecorder();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  _Phase _phase = _Phase.starting;
  String? _error;
  Timer? _ticker;
  int _elapsedMs = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    unawaited(() async {
      if (await _recorder.isRecording()) await _recorder.cancel();
      await _recorder.dispose();
    }());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _phase = _Phase.starting;
      _error = null;
      _elapsedMs = 0;
    });
    try {
      if (!await _recorder.hasPermission()) {
        _fail('Izin mikrofon ditolak. Aktifkan lewat Pengaturan HP untuk memakai fitur suara.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'stash_voice_${DateTime.now().millisecondsSinceEpoch}.wav');
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: path,
      );
      if (!mounted) return;
      setState(() => _phase = _Phase.recording);
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() => _elapsedMs += 200);
        if (_elapsedMs >= _maxSeconds * 1000) _stopAndSend();
      });
    } catch (e) {
      _fail('Tidak bisa mulai merekam: $e');
    }
  }

  void _fail(String message) {
    _ticker?.cancel();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _error = message;
    });
  }

  Future<void> _stopAndSend() async {
    if (_phase != _Phase.recording) return;
    _ticker?.cancel();
    setState(() => _phase = _Phase.processing);
    try {
      final path = await _recorder.stop();
      if (path == null) {
        _fail('Rekaman gagal disimpan. Coba lagi.');
        return;
      }
      final file = File(path);
      final bytes = await file.readAsBytes();
      // The recording only lives long enough to be sent.
      unawaited(file.delete().catchError((_) => file));
      if (bytes.length < _minBytes) {
        _fail('Rekaman terlalu singkat. Tahan sebentar lalu ucapkan transaksinya.');
        return;
      }
      final result = await widget.scanner.parse(
        audioBytes: bytes,
        mimeType: 'audio/wav',
        apiKey: widget.apiKey,
        model: widget.model,
        walletNames: widget.walletNames,
      );
      if (!mounted) return;
      if (!result.isTransaction) {
        _fail('Tidak terdengar seperti catatan transaksi. Coba ucapkan lagi dengan jelas.');
        return;
      }
      Navigator.of(context).pop(result);
    } on GeminiException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Gagal memproses suara: $e');
    }
  }

  String get _timer {
    final s = _elapsedMs ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final recording = _phase == _Phase.recording;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: StashColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              switch (_phase) {
                _Phase.starting => 'Menyiapkan mikrofon…',
                _Phase.recording => 'Mendengarkan…',
                _Phase.processing => 'Memahami ucapanmu…',
                _Phase.error => 'Belum berhasil',
              },
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: Center(
                child: switch (_phase) {
                  _Phase.processing => const CircularProgressIndicator(),
                  _Phase.error => Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: StashColors.expenseTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_off_rounded, size: 34, color: StashColors.expense),
                    ),
                  _ => AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) => Container(
                        width: 84 + (recording ? 28 * _pulse.value : 0),
                        height: 84 + (recording ? 28 * _pulse.value : 0),
                        decoration: BoxDecoration(
                          color: StashColors.primary.withValues(alpha: recording ? 0.14 : 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: child),
                      ),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          gradient: StashGradients.cta,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic_rounded, size: 34, color: Colors.white),
                      ),
                    ),
                },
              ),
            ),
            const SizedBox(height: 12),
            if (recording) ...[
              Text(
                _timer,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Contoh: “makan siang padang tiga puluh lima ribu pakai BCA”',
                textAlign: TextAlign.center,
                style: TextStyle(color: StashColors.muted, fontSize: 13),
              ),
            ] else if (_phase == _Phase.error)
              Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: StashColors.muted),
              )
            else if (_phase == _Phase.processing)
              const Text(
                'Suaramu dikirim ke Gemini AI lalu dihapus dari HP.',
                textAlign: TextAlign.center,
                style: TextStyle(color: StashColors.muted, fontSize: 13),
              ),
            const SizedBox(height: 22),
            if (recording)
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _stopAndSend,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Selesai'),
                  ),
                ),
              ])
            else if (_phase == _Phase.error)
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: _start, child: const Text('Coba lagi')),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
