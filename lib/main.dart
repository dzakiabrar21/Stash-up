import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/stash_repository.dart';
import 'services/receipt_scanner.dart';
import 'services/settings_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  Intl.defaultLocale = 'id_ID';

  final db = await AppDatabase.open();
  final settings = await SettingsService.create();
  final state = AppState(StashRepository(db), settings);
  await state.refresh();

  runApp(StashApp(state: state, settings: settings, scanner: ReceiptScanner()));
}
