import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'detailed_report_screen.dart'; 

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  Key _streamKey = UniqueKey();

  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _expenseData = [];
  Map<String, dynamic> _reportData = {};

  @override
  void initState() {
    super.initState();
    _resetToToday();
  }

  void _resetToToday() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate! : _endDate!,
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
    setState(() {
      _salesData = [];
      _expenseData = [];
      _reportData = {};
      _streamKey = UniqueKey();
    });
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
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selectDate(context, true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text('Inicio: \${dateFormat.format(_startDate!)}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selectDate(context, false),
                        icon: const Icon(Icons.calendar_today),
                        label: Text('Fin: \${dateFormat.format(_endDate!)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _applyFilter,
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
                  return Center(child: Text('Error al cargar datos: \${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                   return const Center(child: Text('No hay datos disponibles.'));
                }

                // *** ULTIMATE FIX: Wrap all calculation logic in a try-catch block ***
                try {
                  final salesDocs = snapshot.data!['sales']?.docs ?? [];
                  final expenseDocs = snapshot.data!['expenses']?.docs ?? [];

                  _salesData = salesDocs
                      .where((doc) => doc.exists && doc.data() != null)
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList();
                  _expenseData = expenseDocs
                      .where((doc) => doc.exists && doc.data() != null)
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList();

                  if (_salesData.isEmpty && _expenseData.isEmpty) {
                    return const Center(child: Text('No hay datos disponibles en este rango.'));
                  }

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
                  
                  double netProfit = 0;
                  profitDistributionBudget.forEach((category, budget) {
                    final spent = expensesByCategory[category] ?? 0;
                    netProfit += (budget - spent);
                  });

                  _reportData = {
                    'totalRevenue': totalRevenue,
                    'totalCost': totalCost,
                    'grossProfit': grossProfit,
                    'totalExpenses': totalExpenses,
                    'netProfit': netProfit,
                    'expensesByCategory': expensesByCategory,
                    'profitDistribution': profitDistributionBudget,
                  };

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    child: Column(
                      children: [
                        _buildSummaryCards(totalRevenue, totalCost, totalExpenses, netProfit),
                        const SizedBox(height: 24),
                        _buildDistributionSection(context, 'Presupuesto vs. Gasto por Cuenta', profitDistributionBudget, expensesByCategory),
                      ],
                    ),
                  );
                } catch (e, stackTrace) {
                  // If any error occurs during processing, show it on screen
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Ocurrió un error al procesar los datos. Esto puede deberse a un registro con formato incorrecto en la base de datos.\n\nError: $e',
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
