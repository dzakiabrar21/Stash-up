import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/amount_expression.dart';
import '../../core/theme.dart';

/// Calculator numpad. Layout:
///
///   C  ÷  ×  ⌫
///   7  8  9  −
///   4  5  6  +
///   1  2  3  [✓]
///   000 0  =  [✓]
class Numpad extends StatelessWidget {
  const Numpad({
    super.key,
    required this.expression,
    required this.onChanged,
    required this.onSubmit,
    this.submitEnabled = true,
  });

  final AmountExpression expression;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;
  final bool submitEnabled;

  /// Keys shrink on short screens so the form above stays usable.
  static double keyHeightFor(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 700 ? 42.0 : 52.0;

  void _tap(void Function() action) {
    HapticFeedback.selectionClick();
    action();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final keyHeight = keyHeightFor(context);
    Widget key(
      String label, {
      required VoidCallback onTap,
      VoidCallback? onLongPress,
      IconData? icon,
      bool accent = false,
    }) {
      final fg = accent ? StashColors.primaryDark : StashColors.text;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: SizedBox(
            height: keyHeight,
            child: Material(
              color: accent ? StashColors.primaryTint : StashColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(StashRadius.field),
                side: accent ? BorderSide.none : const BorderSide(color: StashColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(StashRadius.field),
                onTap: onTap,
                onLongPress: onLongPress,
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: fg, size: 22)
                      : Text(
                          label,
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: fg),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget digit(String d) => key(d, onTap: () => _tap(() => expression.appendDigits(d)));
    Widget op(String o) =>
        key(o, accent: true, onTap: () => _tap(() => expression.appendOperator(o)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          key('C', accent: true, onTap: () => _tap(expression.clear)),
          op(AmountExpression.divide),
          op(AmountExpression.times),
          key(
            '⌫',
            icon: Icons.backspace_outlined,
            accent: true,
            onTap: () => _tap(expression.backspace),
            onLongPress: () => _tap(expression.clear),
          ),
        ]),
        Row(children: [digit('7'), digit('8'), digit('9'), op(AmountExpression.minus)]),
        Row(children: [digit('4'), digit('5'), digit('6'), op(AmountExpression.plus)]),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(children: [
                Row(children: [digit('1'), digit('2'), digit('3')]),
                Row(children: [
                  digit('000'),
                  digit('0'),
                  key('=', accent: true, onTap: () => _tap(expression.resolve)),
                ]),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Opacity(
                  opacity: submitEnabled ? 1 : 0.5,
                  child: Container(
                    height: keyHeight * 2 + 6,
                    decoration: BoxDecoration(
                      gradient: StashGradients.cta,
                      borderRadius: BorderRadius.circular(StashRadius.field),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(StashRadius.field),
                        onTap: submitEnabled
                            ? () {
                                HapticFeedback.mediumImpact();
                                onSubmit();
                              }
                            : null,
                        child: const Center(
                          child: Icon(Icons.check_rounded, size: 30, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
