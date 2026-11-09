import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stash/app.dart';
import 'package:stash/data/app_database.dart';
import 'package:stash/data/stash_repository.dart';
import 'package:stash/services/receipt_scanner.dart';
import 'package:stash/services/settings_service.dart';
import 'package:stash/state/app_state.dart';

void main() {
  sqfliteFfiInit();

  late AppState state;
  late Database db;

  /// Boots the app on a phone-sized screen with an in-memory database.
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1080, 2400), // typical phone: 360 x 800 dp
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    // SQLite (ffi) needs the real event loop, not fake-async time.
    await tester.runAsync(() async {
      await initializeDateFormatting('id_ID');
      db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      final settings = await SettingsService.create();
      state = AppState(StashRepository(db), settings);
      await state.refresh();
      await tester.pumpWidget(StashApp(
        state: state,
        settings: settings,
        scanner: ReceiptScanner(),
      ));
      // The Analytics tab queries SQLite on first build; let it finish.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  testWidgets('front page keeps the original layout and flow', (tester) async {
    await pumpApp(tester);

    expect(find.text('Stash'), findsOneWidget);
    expect(find.byTooltip('Pindai struk'), findsOneWidget);
    expect(find.text('Total saldo'), findsOneWidget);
    expect(find.text('Catat'), findsOneWidget);
    expect(find.text('Scan struk'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Tunai'), findsOneWidget); // wallet card
    expect(find.text('Transaksi terbaru'), findsOneWidget);
    expect(find.text('Belum ada transaksi'), findsOneWidget);
    expect(find.byTooltip('Catat transaksi'), findsOneWidget);

    await tester.runAsync(db.close);
  });

  testWidgets('bottom tabs: Dompet, Analitik, Pengaturan', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Dompet').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tambah dompet'), findsOneWidget);
    expect(find.byTooltip('Transfer antar dompet'), findsOneWidget);
    expect(find.text('Tambah dompet'), findsOneWidget);

    await tester.tap(find.text('Analitik').last);
    await tester.pumpAndSettle();
    expect(find.text('Pengeluaran per kategori'), findsOneWidget);

    await tester.tap(find.text('Pengaturan').last);
    await tester.pumpAndSettle();
    expect(find.text('Ekspor ke CSV'), findsOneWidget);
    expect(find.byTooltip('Catat transaksi'), findsNothing, reason: 'FAB only on Beranda/Dompet');

    await tester.runAsync(db.close);
  });

  testWidgets('quick input saves an expense via the numpad', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Catat transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Catat transaksi'), findsOneWidget); // screen title
    expect(find.byTooltip('Catat dengan suara'), findsOneWidget);
    expect(find.byTooltip('Pindai struk'), findsOneWidget);

    for (final k in ['2', '5', '000', '+', '5', '000']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    expect(find.text('Rp 30.000'), findsOneWidget);

    await tester.ensureVisible(find.text('Transportasi'));
    await tester.tap(find.text('Transportasi'));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.check_rounded));
      // Let the SQLite write + refresh complete on the real event loop, then
      // rebuild here so screens that re-query SQLite do so outside fake time.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(state.recent.single.amount, 30000);
    expect(state.recent.single.category, 'transport');
    expect(find.text('Transportasi'), findsWidgets);
    expect(state.totalBalance, -30000);

    await tester.runAsync(db.close);
  });

  testWidgets('Catat transaksi stays usable on a small phone (360 x 640 dp)', (tester) async {
    await pumpApp(tester, size: const Size(1080, 1920));

    await tester.tap(find.byTooltip('Catat transaksi'));
    await tester.pumpAndSettle();

    // The numpad leaves a usable window for the form above it.
    expect(find.text('Rp 0'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    final numpadTop = tester.getTopLeft(find.text('C').last).dy;
    final amountBottom = tester.getBottomLeft(find.text('Rp 0')).dy;
    expect(numpadTop - amountBottom, greaterThan(40)); // dp: chips row fits under the amount

    // And the rest of the form is reachable by scrolling.
    await tester.scrollUntilVisible(
      find.text('Catatan (opsional)'),
      100,
      scrollable: find.descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.pump();
    expect(find.text('Catatan (opsional)'), findsOneWidget);

    await tester.runAsync(db.close);
  });
}
