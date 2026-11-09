import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/settings_service.dart';
import '../export_flow.dart';
import '../widgets/stash_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  bool _obscure = true;
  bool _hasKey = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _modelCtrl.text = settings.geminiModel;
    settings.getGeminiApiKey().then((k) {
      if (!mounted) return;
      setState(() {
        _hasKey = k != null && k.isNotEmpty;
        _keyCtrl.text = k ?? '';
      });
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _saveGemini() async {
    final settings = context.read<SettingsService>();
    await settings.setGeminiApiKey(_keyCtrl.text);
    await settings.setGeminiModel(_modelCtrl.text);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _hasKey = _keyCtrl.text.trim().isNotEmpty;
      _modelCtrl.text = settings.geminiModel;
    });
    _toast(_hasKey ? 'Pengaturan Gemini disimpan' : 'API key dihapus');
  }

  Future<void> _export(BuildContext buttonContext) async {
    setState(() => _exporting = true);
    await exportCsvAndShare(context, originContext: buttonContext);
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget header(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: StashColors.primary,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          header('Pemindai struk (Gemini AI)'),
          StashCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(
                  _hasKey ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: _hasKey ? StashColors.income : StashColors.placeholder,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_hasKey ? 'API key tersimpan' : 'API key belum diatur')),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _keyCtrl,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Gemini API key',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Tampilkan' : 'Sembunyikan',
                    icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelCtrl,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  helperText: 'Default: ${SettingsService.defaultGeminiModel}',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _saveGemini, child: const Text('Simpan')),
              const SizedBox(height: 12),
              const Text(
                'Buat API key gratis di aistudio.google.com. Key disimpan terenkripsi '
                'di perangkat (Keystore/Keychain). Foto struk hanya dikirim ke Google '
                'saat kamu menekan "Pindai struk"; data transaksi lainnya tidak pernah '
                'meninggalkan HP.',
                style: TextStyle(fontSize: 12, color: StashColors.muted, height: 1.4),
              ),
            ]),
          ),
          header('Data'),
          StashCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              Builder(
                builder: (buttonContext) => ListTile(
                  leading: const Icon(Icons.file_download_rounded, color: StashColors.primary),
                  title: const Text('Ekspor ke CSV', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Semua transaksi, bisa dibuka di Excel / Google Sheets'),
                  trailing: _exporting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _exporting ? null : () => _export(buttonContext),
                ),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.lock_rounded, color: StashColors.primary),
                title: Text('100% offline', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Database SQLite tersimpan di penyimpanan internal HP'),
              ),
            ]),
          ),
          header('Tentang'),
          const StashCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.savings_rounded, color: StashColors.primary),
              title: Text('Stash', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Versi 1.0.0 · Pelacak keuangan pribadi'),
            ),
          ),
        ],
      ),
    );
  }
}
