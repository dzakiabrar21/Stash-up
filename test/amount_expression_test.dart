import 'package:flutter_test/flutter_test.dart';
import 'package:stash/core/amount_expression.dart';

void main() {
  const p = AmountExpression.plus;
  const m = AmountExpression.minus;
  const x = AmountExpression.times;
  const d = AmountExpression.divide;

  group('evaluate', () {
    test('respects operator precedence', () {
      expect(AmountExpression.evaluate('25000${p}3500${x}2'), 32000);
      expect(AmountExpression.evaluate('100000${m}20000${d}4'), 95000);
    });
    test('ignores trailing operator', () {
      expect(AmountExpression.evaluate('15000$p'), 15000);
    });
    test('rounds division to whole rupiah', () {
      expect(AmountExpression.evaluate('10000${d}3'), 3333);
    });
    test('returns null for empty input and division by zero', () {
      expect(AmountExpression.evaluate(''), isNull);
      expect(AmountExpression.evaluate('5${d}0'), isNull);
    });
  });

  group('input', () {
    test('builds an expression and formats it', () {
      final e = AmountExpression()
        ..appendDigits('25')
        ..appendDigits('000')
        ..appendOperator(p)
        ..appendDigits('3')
        ..appendDigits('500');
      expect(e.display, '25.000 + 3.500');
      expect(e.value, 28500);
      expect(e.hasOperator, isTrue);
    });

    test('replaces consecutive operators and ignores leading operator', () {
      final e = AmountExpression()..appendOperator(p);
      expect(e.raw, '');
      e
        ..appendDigits('5')
        ..appendOperator(p)
        ..appendOperator(x);
      expect(e.raw, '5$x');
    });

    test('no leading zeros and 000 needs a number first', () {
      final e = AmountExpression()
        ..appendDigits('000')
        ..appendDigits('0')
        ..appendDigits('0')
        ..appendDigits('7');
      expect(e.raw, '7');
    });

    test('resolve collapses to the result', () {
      final e = AmountExpression('2000${x}3')..resolve();
      expect(e.raw, '6000');
      final neg = AmountExpression('10${m}20')..resolve();
      expect(neg.raw, '');
    });

    test('limits digits per number', () {
      final e = AmountExpression();
      for (var i = 0; i < 20; i++) {
        e.appendDigits('9');
      }
      expect(e.raw.length, AmountExpression.maxDigits);
    });
  });
}
