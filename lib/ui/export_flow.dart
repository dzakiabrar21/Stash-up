import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/csv_exporter.dart';
import '../state/app_state.dart';

/// Builds the CSV of every transaction and opens the system share sheet.
/// [originContext] anchors the share popover on iPad.
Future<void> exportCsvAndShare(BuildContext context, {BuildContext? originContext}) async {
  final messenger = ScaffoldMessenger.of(context);
  final repo = context.read<AppState>().repo;
  final box = (originContext ?? context).findRenderObject();
  final origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;

  try {
    final result = await CsvExporter(repo).export();
    if (result.count == 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Belum ada transaksi untuk diekspor')));
      return;
    }
    await SharePlus.instance.share(ShareParams(
      files: [XFile(result.file.path, mimeType: 'text/csv')],
      subject: 'Ekspor data Stash',
      sharePositionOrigin: origin,
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Gagal mengekspor: $e')));
  }
}
