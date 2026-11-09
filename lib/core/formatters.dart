import 'package:intl/intl.dart';

final NumberFormat _rupiah =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final NumberFormat _plain = NumberFormat.decimalPattern('id_ID');
final NumberFormat _compact = NumberFormat.compact(locale: 'id_ID');

String formatRupiah(int amount) => _rupiah.format(amount);

/// "+Rp 25.000" / "-Rp 25.000" (zero has no sign).
String formatSignedRupiah(int amount) =>
    amount > 0 ? '+${_rupiah.format(amount)}' : _rupiah.format(amount);

/// "25.000"
String formatNumber(num n) => _plain.format(n);

/// "1,5 jt"
String formatCompact(num n) => _compact.format(n);

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime monthStart(DateTime d) => DateTime(d.year, d.month);
DateTime nextMonth(DateTime d) => DateTime(d.year, d.month + 1);

String formatDayLabel(DateTime d, {DateTime? now}) {
  final today = dayOf(now ?? DateTime.now());
  final day = dayOf(d);
  if (day == today) return 'Hari ini';
  if (day == DateTime(today.year, today.month, today.day - 1)) return 'Kemarin';
  if (day.year == today.year) return DateFormat('EEEE, d MMM', 'id_ID').format(d);
  return DateFormat('d MMM yyyy', 'id_ID').format(d);
}

String formatMonth(DateTime d) => DateFormat('MMMM yyyy', 'id_ID').format(d);
String formatMonthShort(DateTime d) => DateFormat('MMM', 'id_ID').format(d);
