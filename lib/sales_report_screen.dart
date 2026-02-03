import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'detailed_report_screen.dart';

enum DateFilter { today, thisWeek, thisMonth, custom }

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  DateFilter _selectedFilter = DateFilter.today;
  Key _streamKey = UniqueKey();

  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _expenseData = [];
  Map<String, dynamic> _reportData = {};

  @override
  void initState() {
    super.initState();
    _setFilter(DateFilter.today);
  }

  void _setFilter(DateFilter filter) {
    final now = DateTime.now();
    setState(() {
      _selectedFilter = filter;
      switch (filter) {
        case DateFilter.today:
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case DateFilter.thisWeek:
          final weekDay = now.weekday;
          _startDate = DateTime(now.year, now.month, now.day - (weekDay - 1));
          _endDate = DateTime(now.year, now.month, now.day + (7 - weekDay), 23, 59, 59);
          break;
        case DateFilter.thisMonth:
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case DateFilter.custom:
          // No action needed, user will pick dates
          break;
      }
      if (filter != DateFilter.custom) {
        _applyFilter();
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      locale: const Locale('es', 'MX'),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
    }
  }

  void _applyFilter() {
    if (_startDate != null && _endDate != null) {
      setState(() {
        _salesData = [];
        _expenseData = [];
        _reportData = {};
        _streamKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_MX');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis de Rentabilidad'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: SegmentedButton<DateFilter>(
              style: SegmentedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                textStyle: Theme.of(context).textTheme.titleSmall,
              ),
              segments: const <ButtonSegment<DateFilter>>[
                ButtonSegment<DateFilter>(value: DateFilter.today, label: Text('Hoy')),
                ButtonSegment<DateFilter>(value: DateFilter.thisWeek, label: Text('Semana')),
                ButtonSegment<DateFilter>(value: DateFilter.thisMonth, label: Text('Mes')),
                ButtonSegment<DateFilter>(value: DateFilter.custom, label: Text('Personal.'), icon: Icon(Icons.calendar_month_outlined)),
              ],
              selected: {_selectedFilter},
              onSelectionChanged: (Set<DateFilter> newSelection) {
                _setFilter(newSelection.first);
              },
            ),
          ),
          if (_selectedFilter == DateFilter.custom)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _selectDate(context, true),
                          icon: const Icon(Icons.calendar_today),
                          label: Text('Inicio: ${_startDate != null ? dateFormat.format(_startDate!) : '...'}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _selectDate(context, false),
                          icon: const Icon(Icons.calendar_today),
                          label: Text('Fin: ${_endDate != null ? dateFormat.format(_endDate!) : '...'}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: (_startDate != null && _endDate != null) ? _applyFilter : null,
                    child: const Text('Aplicar Filtro'),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<Map<String, QuerySnapshot>>(
              key: _streamKey,
              stream: _fetchData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar datos: ${snapshot.error}'));
                }
                if (!snapshot.hasData || (snapshot.data!['sales']!.docs.isEmpty && snapshot.data!['expenses']!.docs.isEmpty)) {
                  return const Center(child: Text('No hay datos disponibles en este rango.'));
                }

                try {
                  _salesData = snapshot.data!['sales']!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                  _expenseData = snapshot.data!['expenses']!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

                  final double totalRevenue = _salesData.fold(0.0, (sum, item) => sum + (item['total_orden'] as num? ?? 0));
                  final double totalCost = _salesData.fold(0.0, (sum, item) => sum + (item['total_costo'] as num? ?? 0));
                  final double grossProfit = totalRevenue - totalCost;

                  final Map<String, double> profitDistributionBudget = {
                    'Rentas y servicios': grossProfit * 0.67,
                    'Otros gastos': grossProfit * 0.17,
                    'Losa': grossProfit * 0.08,
                    'Transporte': grossProfit * 0.08,
                  };

                  Map<String, double> expensesByCategory = {};
                  double totalExpenses = 0;
                  for (var expense in _expenseData) {
                    final category = expense['categoria'] as String? ?? 'Otros gastos';
                    final amount = (expense['monto'] as num? ?? 0.0).toDouble();
                    expensesByCategory[category] = (expensesByCategory[category] ?? 0) + amount;
                    totalExpenses += amount;
                  }
                  
                  double netProfit = grossProfit - totalExpenses;

                  _reportData = {
                    'totalRevenue': totalRevenue,
                    'totalCost': totalCost,
                    'grossProfit': grossProfit,
                    'totalExpenses': totalExpenses,
                    'netProfit': netProfit,
                    'expensesByCategory': expensesByCategory,
                    'profitDistribution': profitDistributionBudget,
                  };
                  
                  final Map<String, int> topDrinks = {};
                  for (var sale in _salesData) {
                      final List<dynamic> items = sale['items'] ?? [];
                      for (var item in items) {
                          final String name = item['nombre'] ?? 'Bebida desconocida';
                          final int quantity = (item['cantidad'] as num? ?? 0).toInt();
                          topDrinks.update(name, (value) => value + quantity, ifAbsent: () => quantity);
                      }
                  }

                  final sortedDrinks = topDrinks.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                  final top5Drinks = sortedDrinks.take(5).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    child: Column(
                      children: [
                        _buildSummaryCards(totalRevenue, totalCost, totalExpenses, netProfit),
                        const SizedBox(height: 24),
                        _buildFinancialSummaryChart(context, totalRevenue, totalCost, totalExpenses),
                        const SizedBox(height: 24),
                        _buildTopDrinksChart(context, top5Drinks),
                        const SizedBox(height: 24),
                        _buildDistributionSection(context, 'Presupuesto vs. Gasto por Cuenta', profitDistributionBudget, expensesByCategory),
                      ],
                    ),
                  );
                } catch (e, stackTrace) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Ocurrió un error al procesar los datos.\nError: $e\nStack: $stackTrace',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (_salesData.isNotEmpty || _expenseData.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () {
                if (_startDate == null || _endDate == null || _reportData.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailedReportScreen(
                      startDate: _startDate!,
                      endDate: _endDate!,
                      salesDocs: _salesData,
                      expenseDocs: _expenseData,
                      totalRevenue: _reportData['totalRevenue'] ?? 0.0,
                      totalCost: _reportData['totalCost'] ?? 0.0,
                      grossProfit: _reportData['grossProfit'] ?? 0.0,
                      totalExpenses: _reportData['totalExpenses'] ?? 0.0,
                      netProfit: _reportData['netProfit'] ?? 0.0,
                      expensesByCategory: _reportData['expensesByCategory'] as Map<String, double>? ?? {},
                      profitDistribution: _reportData['profitDistribution'] as Map<String, double>? ?? {},
                    ),
                  ),
                );
              },
              label: const Text('Ver Reporte Detallado'),
              icon: const Icon(Icons.list_alt),
            )
          : null,
    );
  }

  Stream<Map<String, QuerySnapshot>> _fetchData() {
    if (_startDate == null || _endDate == null) {
      return Stream.value({});
    }
    final salesStream = FirebaseFirestore.instance
        .collection('ordenes_archivadas')
        .where('fecha_finalizacion', isGreaterThanOrEqualTo: _startDate)
        .where('fecha_finalizacion', isLessThanOrEqualTo: _endDate)
        .get();

    final expensesStream = FirebaseFirestore.instance
        .collection('gastos')
        .where('fecha', isGreaterThanOrEqualTo: _startDate)
        .where('fecha', isLessThanOrEqualTo: _endDate)
        .get();

    return Stream.fromFuture(Future.wait([salesStream, expensesStream]))
        .map((snapshots) => {'sales': snapshots[0], 'expenses': snapshots[1]});
  }

  Widget _buildSummaryCards(double revenue, double totalCost, double expenses, double netProfit) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');
    return Column(
      children: [
        _buildMetricCard('Ganancia Neta REAL', currencyFormat.format(netProfit), Icons.insights, Colors.blue.shade600, isHighlighted: true),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard('Ingresos', currencyFormat.format(revenue), Icons.trending_up, Colors.green),
            _buildMetricCard('Costos', currencyFormat.format(totalCost), Icons.shopping_cart, Colors.orange),
            _buildMetricCard('Gastos', currencyFormat.format(expenses), Icons.receipt_long, Colors.red),
          ],
        ),
      ],
    );
  }

 Widget _buildMetricCard(String label, String value, IconData icon, Color color, {bool isHighlighted = false}) {
     return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isHighlighted ? color : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: isHighlighted ? Colors.white : color, size: 24),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 14, color: isHighlighted ? Colors.white70 : Colors.grey[700]), textAlign: TextAlign.center, maxLines: 1),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isHighlighted ? Colors.white : color), maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryChart(BuildContext context, double revenue, double cost, double expense) {
    final currencyFormat = NumberFormat.compactSimpleCurrency(locale: 'es_MX');
    final maxValue = [revenue, cost, expense].reduce((a, b) => a > b ? a : b) * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen Financiero',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue > 0 ? maxValue : 100,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final value = rod.toY;
                        return BarTooltipItem(
                          NumberFormat.simpleCurrency(locale: 'es_MX').format(value),
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 14);
                          String text;
                          switch (value.toInt()) {
                            case 0:
                              text = 'Ingresos';
                              break;
                            case 1:
                              text = 'Costos';
                              break;
                            case 2:
                              text = 'Gastos';
                              break;
                            default:
                              text = '';
                              break;
                          }
                          return SideTitleWidget(axisSide: meta.axisSide, child: Text(text, style: style));
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value == meta.max || value == 0) return Container();
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 5,
                            child: Text(
                              currencyFormat.format(value),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    checkToShowHorizontalLine: (value) => value % (maxValue / 5) == 0,
                     getDrawingHorizontalLine: (value) {
                      return const FlLine(
                        color: Colors.black12,
                        strokeWidth: 1,
                        dashArray: [3, 3],
                      );
                    },
                  ),
                  barGroups: [
                    _makeBarGroupData(0, revenue, Colors.green.shade600),
                    _makeBarGroupData(1, cost, Colors.orange.shade600),
                    _makeBarGroupData(2, expense, Colors.red.shade600),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _makeBarGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 22,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget _buildTopDrinksChart(BuildContext context, List<MapEntry<String, int>> topDrinks) {
    if (topDrinks.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Color> chartColors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.purple.shade400,
      Colors.amber.shade400,
      Colors.red.shade400,
    ];

    final double totalDrinks = topDrinks.fold(0, (sum, item) => sum + item.value);
    int touchedIndex = -1; // This should be a state variable for interaction

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proporción de Bebidas Vendidas',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          // Interaction logic can be added here
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: List.generate(topDrinks.length, (i) {
                        final isTouched = i == touchedIndex;
                        final fontSize = isTouched ? 18.0 : 14.0;
                        final radius = isTouched ? 60.0 : 50.0;
                        final percentage = (topDrinks[i].value / totalDrinks) * 100;
                        
                        return PieChartSectionData(
                          color: chartColors[i % chartColors.length],
                          value: topDrinks[i].value.toDouble(),
                          title: '${percentage.toStringAsFixed(1)}%',
                          radius: radius,
                          titleStyle: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ...List.generate(topDrinks.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Container(
                          width: 16, 
                          height: 16,
                          color: chartColors[i % chartColors.length],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          topDrinks[i].key,
                          style: Theme.of(context).textTheme.bodyLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          '${topDrinks[i].value} un.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionSection(BuildContext context, String title, Map<String, double> budgets, Map<String, double> expenses) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');
    final allCategories = {...budgets.keys, ...expenses.keys}.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...allCategories.map((category) {
          final budget = budgets[category] ?? 0;
          final spent = expenses[category] ?? 0;
          final remaining = budget - spent;
          final percentage = budget > 0 ? (spent / budget) * 100 : (spent > 0 ? 101.0 : 0.0);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(category, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
                      Text('${percentage.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (percentage / 100).clamp(0, 2),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(percentage > 100 ? Colors.red.shade700 : Colors.blue.shade600),
                  ),
                  const SizedBox(height: 16),
                  _buildBudgetRow('Presupuesto:', currencyFormat.format(budget), Colors.green.shade700),
                  const SizedBox(height: 8),
                  _buildBudgetRow('Gastado:', currencyFormat.format(spent), Colors.red.shade700),
                  const Divider(height: 20),
                  _buildBudgetRow('Restante:', currencyFormat.format(remaining), remaining < 0 ? Colors.orange.shade800 : Colors.blue.shade800, isBold: true),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildBudgetRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: valueColor)),
      ],
    );
  }
}
