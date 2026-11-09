import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/categories.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/stash_widgets.dart';
import '../widgets/transaction_list.dart';

class _AnalyticsData {
  const _AnalyticsData(this.totals, this.byCategory, this.monthly);
  final MonthTotal totals;
  final List<CategoryTotal> byCategory;
  final List<MonthTotal> monthly;
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime _month = monthStart(DateTime.now());
  Future<_AnalyticsData>? _future;
  int _loadedRevision = -1;
  DateTime? _loadedMonth;
  int _touchedSlice = -1;

  Future<_AnalyticsData> _load(AppState state) async {
    final from = _month;
    final to = nextMonth(_month);
    final results = await Future.wait([
      state.repo.totals(from, to),
      state.repo.expenseByCategory(from, to),
      state.repo.monthlyTotals(_month, count: 6),
    ]);
    return _AnalyticsData(
      results[0] as MonthTotal,
      results[1] as List<CategoryTotal>,
      results[2] as List<MonthTotal>,
    );
  }

  void _setMonth(DateTime m) => setState(() {
        _month = monthStart(m);
        _touchedSlice = -1;
      });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_loadedRevision != state.revision || _loadedMonth != _month) {
      _loadedRevision = state.revision;
      _loadedMonth = _month;
      _future = _load(state);
    }
    final isCurrentMonth = _month == monthStart(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Analitik')),
      body: FutureBuilder<_AnalyticsData>(
        future: _future,
        builder: (context, snap) {
          final data = snap.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Row(children: [
                IconButton(
                  tooltip: 'Bulan sebelumnya',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _setMonth(DateTime(_month.year, _month.month - 1)),
                ),
                Expanded(
                  child: Text(
                    formatMonth(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Bulan berikutnya',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: isCurrentMonth
                      ? null
                      : () => _setMonth(DateTime(_month.year, _month.month + 1)),
                ),
              ]),
              if (data == null)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _SummaryRow(totals: data.totals),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Pengeluaran per kategori',
                  child: data.byCategory.isEmpty
                      ? const EmptyState(
                          icon: Icons.pie_chart_outline_rounded,
                          title: 'Belum ada pengeluaran bulan ini',
                        )
                      : _CategoryDonut(
                          data: data.byCategory,
                          touched: _touchedSlice,
                          onTouch: (i) => setState(() => _touchedSlice = i),
                        ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Tren pengeluaran 6 bulan',
                  child: _MonthlyBars(
                    data: data.monthly,
                    selected: _month,
                    onSelect: _setMonth,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.totals});
  final MonthTotal totals;

  @override
  Widget build(BuildContext context) {
    final net = totals.income - totals.expense;
    Widget tile(String label, int value, Color color) => Expanded(
          child: StashCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatRupiah(value),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          ),
        );
    return Row(children: [
      tile('Pemasukan', totals.income, StashColors.income),
      const SizedBox(width: 8),
      tile('Pengeluaran', totals.expense, StashColors.expense),
      const SizedBox(width: 8),
      tile('Selisih', net, net >= 0 ? StashColors.income : StashColors.expense),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => StashCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.data, required this.touched, required this.onTouch});

  final List<CategoryTotal> data;
  final int touched;
  final ValueChanged<int> onTouch;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<int>(0, (s, c) => s + c.total);
    final text = Theme.of(context).textTheme;
    final selected = touched >= 0 && touched < data.length ? data[touched] : null;
    final selectedCat = selected == null ? null : categoryById(selected.category, TxnType.expense);

    return Column(children: [
      SizedBox(
        height: 220,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 62,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final i = response?.touchedSection?.touchedSectionIndex ?? -1;
                  onTouch(i == touched ? -1 : i);
                },
              ),
              sections: [
                for (var i = 0; i < data.length; i++)
                  () {
                    final cat = categoryById(data[i].category, TxnType.expense);
                    final pct = data[i].total / total * 100;
                    final isTouched = i == touched;
                    return PieChartSectionData(
                      value: data[i].total.toDouble(),
                      color: cat.color,
                      radius: isTouched ? 46 : 36,
                      title: pct >= 6 ? '${pct.round()}%' : '',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }(),
              ],
            ),
          ),
          IgnorePointer(
            child: SizedBox(
              width: 112,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  selectedCat?.label ?? 'Total',
                  style: text.labelMedium,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatRupiah(selected?.total ?? total),
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < data.length; i++)
        () {
          final cat = categoryById(data[i].category, TxnType.expense);
          final pct = data[i].total / total;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTouch(i == touched ? -1 : i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: i == touched ? cat.color.withValues(alpha: 0.10) : null,
              ),
              child: Row(children: [
                Icon(cat.icon, size: 20, color: cat.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat.label),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        color: cat.color,
                        backgroundColor: cat.color.withValues(alpha: 0.15),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(formatRupiah(data[i].total), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${(pct * 100).toStringAsFixed(1)}%', style: text.bodySmall),
                ]),
              ]),
            ),
          );
        }(),
    ]);
  }
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.data, required this.selected, required this.onSelect});

  final List<MonthTotal> data;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = data.fold<int>(0, (m, e) => e.expense > m ? e.expense : m);
    final maxY = maxValue == 0 ? 100000.0 : maxValue * 1.25;
    final avg = data.isEmpty ? 0 : data.fold<int>(0, (s, e) => s + e.expense) ~/ data.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Rata-rata ${formatRupiah(avg)} / bulan',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: scheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) {
                    if (value == meta.max) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(formatCompact(value), style: const TextStyle(fontSize: 10)),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    final isSel = data[i].month == selected;
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        formatMonthShort(data[i].month),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchCallback: (event, response) {
                if (event is! FlTapUpEvent) return;
                final i = response?.spot?.touchedBarGroupIndex;
                if (i != null && i >= 0 && i < data.length) onSelect(data[i].month);
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                  formatRupiah(rod.toY.round()),
                  TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].expense.toDouble(),
                      width: 22,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      color: data[i].month == selected
                          ? scheme.primary
                          : scheme.primary.withValues(alpha: 0.35),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ]);
  }
}
