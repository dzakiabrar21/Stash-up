import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/categories.dart';
import '../data/models.dart';
import '../data/stash_repository.dart';

class CsvExporter {
  CsvExporter(this._repo);

  final StashRepository _repo;

  static const header = [
    'Tanggal',
    'Jenis',
    'Kategori',
    'Jumlah',
    'Dompet',
    'Dompet Tujuan',
    'Merchant',
    'Catatan',
  ];

  /// Builds RFC 4180 CSV text from [StashRepository.exportRows] output.
  static String buildCsv(List<Map<String, Object?>> rows) {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final data = <List<Object?>>[
      header,
      for (final r in rows)
        () {
          final t = Txn.fromMap(r);
          return [
            dateFmt.format(t.date),
            t.type.label,
            t.type == TxnType.transfer ? '' : categoryById(t.category, t.type).label,
            t.amount,
            r['wallet_name'],
            r['to_wallet_name'] ?? '',
            t.merchant ?? '',
            t.note ?? '',
          ];
        }(),
    ];
    return const ListToCsvConverter().convert(data);
  }

  /// Writes all transactions to a temporary CSV file and returns it.
  /// The file starts with a UTF-8 BOM so Excel shows non-ASCII text correctly.
  Future<({File file, int count})> export() async {
    final rows = await _repo.exportRows();
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File(p.join(dir.path, 'stash_export_$stamp.csv'));
    await file.writeAsString('﻿${buildCsv(rows)}', flush: true);
    return (file: file, count: rows.length);
  }
}
