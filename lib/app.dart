import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'services/receipt_scanner.dart';
import 'services/settings_service.dart';
import 'services/voice_scanner.dart';
import 'state/app_state.dart';
import 'ui/screens/analytics_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/wallets_screen.dart';
import 'ui/widgets/stash_widgets.dart';

class StashApp extends StatelessWidget {
  const StashApp({
    super.key,
    required this.state,
    required this.settings,
    required this.scanner,
    this.voiceScanner,
  });

  final AppState state;
  final SettingsService settings;
  final ReceiptScanner scanner;

  /// Defaults to a real [VoiceScanner]; tests can inject one.
  final VoiceScanner? voiceScanner;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        Provider<SettingsService>.value(value: settings),
        Provider<ReceiptScanner>.value(value: scanner),
        Provider<VoiceScanner>(create: (_) => voiceScanner ?? VoiceScanner()),
      ],
      child: MaterialApp(
        title: 'Stash',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        themeMode: ThemeMode.light,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    DashboardScreen(),
    WalletsScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: _index <= 1
          ? GradientCircleButton(
              icon: Icons.add_rounded,
              size: 60,
              elevated: true,
              tooltip: 'Catat transaksi',
              onPressed: () => DashboardScreen.openAdd(context),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Dompet',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Analitik',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
