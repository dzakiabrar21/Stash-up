import 'formatters.dart';

/// Calculator-style amount input used by the quick-input numpad.
///
/// Holds a raw expression such as `25000+3500×2` and evaluates it with
/// normal operator precedence. Results are rounded to whole Rupiah.
class AmountExpression {
  AmountExpression([String initial = '']) : _raw = initial;

  static const plus = '+';
  static const minus = '−';
  static const times = '×';
  static const divide = '÷';
  static const operators = {plus, minus, times, divide};
  static const maxDigits = 12;

  String _raw;

  String get raw => _raw;
  bool get isEmpty => _raw.isEmpty;
  bool get hasOperator => _raw.split('').any(operators.contains);

  int? get value => evaluate(_raw);

  String get _currentNumber {
    var i = _raw.length;
    while (i > 0 && !operators.contains(_raw[i - 1])) {
      i--;
    }
    return _raw.substring(i);
  }

  /// [digits] is '0'..'9' or '000'.
  void appendDigits(String digits) {
    final current = _currentNumber;
    final allZeros = digits.split('').every((c) => c == '0');
    // '000' on an empty number would only produce leading zeros.
    if (allZeros && digits.length > 1 && (current.isEmpty || current == '0')) return;
    if (current == '0') {
      // Replace a lone leading zero.
      _raw = _raw.substring(0, _raw.length - 1);
      if (digits == '0') {
        _raw += '0';
        return;
      }
    }
    if (current.length + digits.length > maxDigits) return;
    _raw += digits;
  }

  void appendOperator(String op) {
    assert(operators.contains(op));
    if (_raw.isEmpty) return;
    if (operators.contains(_raw[_raw.length - 1])) {
      _raw = _raw.substring(0, _raw.length - 1) + op;
    } else {
      _raw += op;
    }
  }

  void backspace() {
    if (_raw.isNotEmpty) _raw = _raw.substring(0, _raw.length - 1);
  }

  void clear() => _raw = '';

  /// Replaces the expression with its result.
  void resolve() {
    final v = value;
    _raw = (v == null || v <= 0) ? '' : '$v';
  }

  /// `25000+3500` -> `25.000 + 3.500`
  String get display {
    final out = StringBuffer();
    final number = StringBuffer();
    void flush() {
      if (number.isEmpty) return;
      out.write(formatNumber(int.parse(number.toString())));
      number.clear();
    }

    for (final ch in _raw.split('')) {
      if (operators.contains(ch)) {
        flush();
        out.write(' $ch ');
      } else {
        number.write(ch);
      }
    }
    flush();
    return out.toString().trimRight();
  }

  /// Returns null for an empty/invalid expression or division by zero.
  static int? evaluate(String raw) {
    if (raw.isEmpty) return null;
    final nums = <double>[];
    final ops = <String>[];
    final buf = StringBuffer();
    for (final ch in raw.split('')) {
      if (operators.contains(ch)) {
        if (buf.isEmpty) return null;
        nums.add(double.parse(buf.toString()));
        buf.clear();
        ops.add(ch);
      } else {
        buf.write(ch);
      }
    }
    if (buf.isEmpty) {
      if (ops.isEmpty) return null;
      ops.removeLast(); // ignore a trailing operator
    } else {
      nums.add(double.parse(buf.toString()));
    }

    // First pass: × and ÷.
    final terms = <double>[nums.first];
    final addOps = <String>[];
    for (var i = 0; i < ops.length; i++) {
      final b = nums[i + 1];
      switch (ops[i]) {
        case times:
          terms.last *= b;
        case divide:
          if (b == 0) return null;
          terms.last /= b;
        default:
          addOps.add(ops[i]);
          terms.add(b);
      }
    }
    // Second pass: + and −.
    var result = terms.first;
    for (var i = 0; i < addOps.length; i++) {
      result = addOps[i] == plus ? result + terms[i + 1] : result - terms[i + 1];
    }
    if (!result.isFinite || result.abs() > 1e15) return null;
    return result.round();
  }
}
