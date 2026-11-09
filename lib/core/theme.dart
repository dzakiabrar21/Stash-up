import 'package:flutter/material.dart';

import '../data/models.dart';

/// Design tokens (see the Stash design spec).
abstract final class StashColors {
  static const page = Color(0xFFF4F8F9);
  static const card = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFF0F5F5);

  static const primary = Color(0xFF007F88);
  static const primaryDark = Color(0xFF075F68);
  static const primaryTint = Color(0xFFE2F8F5);
  static const accent = Color(0xFF24B9B4);

  static const expense = Color(0xFFE24B4B);
  static const expenseTint = Color(0xFFFEEEEE);
  static const income = Color(0xFF0B9D70);
  static const incomeTint = Color(0xFFE5F7EF);
  static const transfer = Color(0xFF3478E5);
  static const transferTint = Color(0xFFEAF2FE);

  static const text = Color(0xFF102A32);
  static const muted = Color(0xFF647A80);
  static const placeholder = Color(0xFF8A9CA1);
  static const border = Color(0xFFDCE7E9);

  /// Soft tints used on top of the dark hero card.
  static const heroIncome = Color(0xFF6BE3D0);
  static const heroExpense = Color(0xFFFFB3B3);

  static Color forType(TxnType t) => switch (t) {
        TxnType.expense => expense,
        TxnType.income => income,
        TxnType.transfer => transfer,
      };

  static Color tintForType(TxnType t) => switch (t) {
        TxnType.expense => expenseTint,
        TxnType.income => incomeTint,
        TxnType.transfer => transferTint,
      };
}

abstract final class StashGradients {
  /// CTA buttons: linear-gradient(135deg, #007F88 0%, #00A6A6 100%)
  static const cta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF007F88), Color(0xFF00A6A6)],
  );

  /// Hero balance card: linear-gradient(125deg, #073F49 0%, #086C73 54%, #00989A 100%)
  static const hero = LinearGradient(
    begin: Alignment(-1, -0.7),
    end: Alignment(1, 0.7),
    colors: [Color(0xFF073F49), Color(0xFF086C73), Color(0xFF00989A)],
    stops: [0, 0.54, 1],
  );
}

abstract final class StashShadows {
  /// 0px 5px 18px rgba(26, 69, 76, 0.04)
  static const card = [
    BoxShadow(color: Color(0x0A1A454C), offset: Offset(0, 5), blurRadius: 18),
  ];

  /// 0px 18px 35px rgba(3, 68, 76, 0.18)
  static const hero = [
    BoxShadow(color: Color(0x2E03444C), offset: Offset(0, 18), blurRadius: 35),
  ];
}

abstract final class StashRadius {
  static const pill = 9999.0;
  static const card = 18.0;
  static const field = 12.0;
}

/// Plus Jakarta Sans is bundled in `assets/fonts` (family `PlusJakartaSans`).
const fontFamilyName = 'PlusJakartaSans';

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: StashColors.primary,
    onPrimary: Colors.white,
    primaryContainer: StashColors.primaryTint,
    onPrimaryContainer: StashColors.primaryDark,
    secondary: StashColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: StashColors.primaryTint,
    onSecondaryContainer: StashColors.primaryDark,
    tertiary: StashColors.transfer,
    tertiaryContainer: StashColors.transferTint,
    onTertiaryContainer: StashColors.transfer,
    error: StashColors.expense,
    surface: StashColors.page,
    onSurface: StashColors.text,
    onSurfaceVariant: StashColors.muted,
    surfaceContainerLowest: StashColors.card,
    surfaceContainerLow: StashColors.card,
    surfaceContainer: StashColors.card,
    surfaceContainerHigh: StashColors.subtle,
    surfaceContainerHighest: StashColors.subtle,
    outline: StashColors.placeholder,
    outlineVariant: StashColors.border,
    inverseSurface: StashColors.text,
    onInverseSurface: Colors.white,
  );

  final textTheme = ThemeData(brightness: Brightness.light).textTheme.apply(
        fontFamily: fontFamilyName,
        bodyColor: StashColors.text,
        displayColor: StashColors.text,
      );

  // Button/chip text styles replace (not merge with) the theme font, so each
  // one is derived from the themed textTheme to keep the font family.
  final label = textTheme.labelLarge ?? const TextStyle();

  OutlineInputBorder fieldBorder(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(StashRadius.field),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamilyName,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: StashColors.page,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: StashColors.page,
      surfaceTintColor: Colors.transparent,
      foregroundColor: StashColors.text,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: StashColors.card,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StashRadius.card)),
    ),
    dividerTheme: const DividerThemeData(color: StashColors.border, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: StashColors.subtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      hintStyle: const TextStyle(color: StashColors.placeholder),
      labelStyle: const TextStyle(color: StashColors.muted),
      border: fieldBorder(Colors.transparent),
      enabledBorder: fieldBorder(Colors.transparent),
      focusedBorder: fieldBorder(StashColors.primary, 1.5),
      errorBorder: fieldBorder(StashColors.expense),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: StashColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: const StadiumBorder(),
        textStyle: label.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: StashColors.primary,
        minimumSize: const Size(0, 48),
        shape: const StadiumBorder(),
        side: const BorderSide(color: StashColors.border),
        textStyle: label.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: StashColors.primary,
        shape: const StadiumBorder(),
        textStyle: label.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: StashColors.text),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: const BorderSide(color: StashColors.border),
      backgroundColor: StashColors.card,
      selectedColor: StashColors.primaryTint,
      labelStyle: label.copyWith(fontWeight: FontWeight.w600, fontSize: 13, color: StashColors.text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: StashColors.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: StashColors.primaryTint,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return label.copyWith(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? StashColors.primaryDark : StashColors.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? StashColors.primaryDark : StashColors.muted);
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: StashColors.text,
      contentTextStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: StashColors.page,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: StashColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

IconData walletIcon(WalletKind kind) => switch (kind) {
      WalletKind.bank => Icons.account_balance_rounded,
      WalletKind.ewallet => Icons.phone_android_rounded,
      WalletKind.cash => Icons.payments_rounded,
    };

/// Colors offered in the wallet form.
const walletColors = <int>[
  0xFF0060AF,
  0xFF003D79,
  0xFFF2A900,
  0xFF00AED6,
  0xFF4C2A86,
  0xFF2E7D32,
  0xFFD81B60,
  0xFFEF6C00,
  0xFF546E7A,
];

class WalletPreset {
  const WalletPreset(this.name, this.kind, this.color);
  final String name;
  final WalletKind kind;
  final int color;
}

const walletPresets = <WalletPreset>[
  WalletPreset('BCA', WalletKind.bank, 0xFF0060AF),
  WalletPreset('Mandiri', WalletKind.bank, 0xFF003D79),
  WalletPreset('Bank Jago', WalletKind.bank, 0xFFF2A900),
  WalletPreset('GoPay', WalletKind.ewallet, 0xFF00AED6),
  WalletPreset('OVO', WalletKind.ewallet, 0xFF4C2A86),
  WalletPreset('Tunai', WalletKind.cash, 0xFF2E7D32),
];
