import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'detailed_report_screen.dart';

class ProfitAnalysisScreen extends StatefulWidget {
  const ProfitAnalysisScreen({super.key});

  @override
  State<ProfitAnalysisScreen> createState() => _ProfitAnalysisScreenState();
}

class _ProfitAnalysisScreenState extends State<ProfitAnalysisScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  Key _streamKey = UniqueKey();

  // Store the results to be accessible by the FAB
  Map<String, dynamic>? _lastSuccessfulData;

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
      _streamKey = UniqueKey();
      _lastSuccessfulData = null; // Clear previous data on new filter
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_MX');

    return Scaffold( // The main and ONLY Scaffold for this screen
      appBar: AppBar(
        title: const Text('Análisis de Rentabilidad'),
      ),
      floatingActionButton: _buildFloatingActionButton(), // Build FAB based on state
      body: Column(
        children: [
          _buildDateFilters(dateFormat),
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
                if (!snapshot.hasData || snapshot.data!['sales']!.docs.isEmpty && snapshot.data!['expenses']!.docs.isEmpty) {
                     _lastSuccessfulData = null; // Clear data if empty
                  return const Center(child: Text('No hay datos en el período seleccionado.'));
                }

                final salesDocs = snapshot.data!['sales']!.docs;
                final expenseDocs = snapshot.data!['expenses']!.docs;

                final salesData = salesDocs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                final expensesData = expenseDocs.map((doc) => doc.data() as Map<String, dynamic>).toList();

                final double totalRevenue = salesData.fold(0, (sum, item) => sum + (item['total_orden'] ?? 0));
                final double totalCost = salesData.fold(0, (sum, item) => sum + (item['total_costo'] ?? 0));
                final double grossProfit = totalRevenue - totalCost;

                Map<String, double> expensesByCategory = {};
                double totalExpenses = 0;
                for (var expense in expensesData) {
                  final category = expense['categoria'] ?? 'Otros';
                  final amount = (expense['monto'] ?? 0.0).toDouble();
                  expensesByCategory[category] = (expensesByCategory[category] ?? 0) + amount;
                  totalExpenses += amount;
                }

                final Map<String, double> profitDistributionBudget = {
                  'Rentas y servicios': grossProfit * 0.67,
                  'Otros gastos': grossProfit * 0.17,
                  'Losa': grossProfit * 0.08,
                  'Transporte': grossProfit * 0.08,
                };
                
                double netProfit = 0;
                profitDistributionBudget.forEach((category, budget) {
                  final spent = expensesByCategory[category] ?? 0;
                  netProfit += (budget - spent);
                });

                // Store the calculated data to be used by the FAB
                WidgetsBinding.instance.addPostFrameCallback((_) {
                    if(mounted) {
                        setState(() {
                             _lastSuccessfulData = {
                                'salesData': salesData,
                                'expensesData': expensesData,
                                'totalRevenue': totalRevenue,
                                'totalCost': totalCost,
                                'grossProfit': grossProfit,
                                'totalExpenses': totalExpenses,
                                'netProfit': netProfit,
                                'expensesByCategory': expensesByCategory,
                                'profitDistributionBudget': profitDistributionBudget,
                            };
                        });
                    }
                });

                // The StreamBuilder now returns ONLY the content, not a Scaffold
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  child: Column(
                    children: [
                      _buildSummaryCards(totalRevenue, totalCost, grossProfit, totalExpenses, netProfit),
                      const SizedBox(height: 24),
                      _buildDistributionSection(context, 'Presupuesto y Gasto por Cuenta', profitDistributionBudget, expensesByCategory),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_lastSuccessfulData == null) {
      return const SizedBox.shrink(); // Return an empty widget if no data
    }
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailedReportScreen(
              startDate: _startDate!,
              endDate: _endDate!,
              salesDocs: _lastSuccessfulData!['salesData'],
              expenseDocs: _lastSuccessfulData!['expensesData'],
              totalRevenue: _lastSuccessfulData!['totalRevenue'],
              totalCost: _lastSuccessfulData!['totalCost'],
              grossProfit: _lastSuccessfulData!['grossProfit'],
              totalExpenses: _lastSuccessfulData!['totalExpenses'],
              netProfit: _lastSuccessfulData!['netProfit'],
              expensesByCategory: _lastSuccessfulData!['expensesByCategory'],
              profitDistribution: _lastSuccessfulData!['profitDistributionBudget'],
            ),
          ),
        );
      },
      label: const Text('Ver Reporte Detallado'),
      icon: const Icon(Icons.bar_chart),
    );
  }

  Widget _buildDateFilters(DateFormat dateFormat) {
     return Padding(
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

  Widget _buildSummaryCards(double revenue, double totalCost, double grossProfit, double expenses, double netProfit) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...budgets.keys.map((category) {
          final budget = budgets[category] ?? 0;
          final spent = expenses[category] ?? 0;
          final remaining = budget - spent;
          final percentage = budget > 0 ? (spent / budget).clamp(0, 2) * 100 : 0;

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
                      Text('\${percentage.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: percentage / 100,
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
