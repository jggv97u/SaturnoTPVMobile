import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'report_screen.dart'; // Importa la nueva pantalla de reporte

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  Key _streamKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _resetToToday();
    _grantAdminPrivileges(); // Grant admin role on load
  }

  // One-time function to grant admin privileges to the specified user.
  Future<void> _grantAdminPrivileges() async {
    final String adminUID = 'qmMq8FwRQ2ZL2acACdwgub3qkn13'; // UID for jggv97u@gmail.com
    final userDoc = FirebaseFirestore.instance.collection('usuarios').doc(adminUID);

    try {
      final docSnapshot = await userDoc.get();
      if (!docSnapshot.exists || !(docSnapshot.data()?['isAdmin'] ?? false)) {
        await userDoc.set({'isAdmin': true}, SetOptions(merge: true));
        print('Admin privileges granted to $adminUID');
      }
    } catch (e) {
      print('Error granting admin privileges: $e');
    }
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Análisis de Rentabilidad'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Visión General'),
              Tab(icon: Icon(Icons.list_alt), text: 'Desglose'),
            ],
          ),
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
                          label: Text('Inicio: ${dateFormat.format(_startDate!)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _selectDate(context, false),
                          icon: const Icon(Icons.calendar_today),
                          label: Text('Fin: ${dateFormat.format(_endDate!)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _applyFilter, child: const Text('Aplicar Filtro'))
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<Map<String, QuerySnapshot>>(
                key: _streamKey, // Rebuilds when dates change
                stream: Stream.fromFuture(Future.wait([
                  FirebaseFirestore.instance
                      .collection('ordenes_archivadas')
                      .where('fecha_finalizacion', isGreaterThanOrEqualTo: _startDate)
                      .where('fecha_finalizacion', isLessThanOrEqualTo: _endDate)
                      .orderBy('fecha_finalizacion', descending: true)
                      .get(),
                  FirebaseFirestore.instance
                      .collection('gastos')
                      .where('fecha', isGreaterThanOrEqualTo: _startDate)
                      .where('fecha', isLessThanOrEqualTo: _endDate)
                      .orderBy('fecha', descending: true)
                      .get(),
                ]).then((snapshots) => {
                  'sales': snapshots[0],
                  'expenses': snapshots[1],
                })),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error al cargar los datos: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: Text('No hay datos disponibles.'));
                  }

                  final salesDocs = snapshot.data!['sales']!.docs;
                  final expenseDocs = snapshot.data!['expenses']!.docs;

                  final salesData =
                      salesDocs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                  final expensesData =
                      expenseDocs.map((doc) => doc.data() as Map<String, dynamic>).toList();

                  // --- Calculations ---
                  double totalRevenue = salesData.fold(0, (sum, item) => sum + (item['total_orden'] ?? 0));
                  double totalCost = salesData.fold(0, (sum, item) => sum + (item['total_costo'] ?? 0));
                  double totalExpenses = expensesData.fold(0, (sum, item) => sum + (item['monto'] ?? 0));
                  final double netProfit = totalRevenue - totalCost - totalExpenses;

                  Map<String, double> expensesByCategory = {};
                  for (var expense in expensesData) {
                    final category = expense['categoria'] ?? 'Otros';
                    expensesByCategory[category] = (expensesByCategory[category] ?? 0) + (expense['monto'] ?? 0);
                  }

                  // --- Net Profit Distribution ---
                  final Map<String, double> profitDistribution = {
                    'Rentas y servicios': netProfit * 0.67,
                    'Otros gastos': netProfit * 0.17,
                    'Losa': netProfit * 0.08,
                    'Transporte': netProfit * 0.08,
                  };

                  return Scaffold(
                    floatingActionButton: FloatingActionButton.extended(
                      onPressed: () {
                        // NAVEGAR A LA NUEVA PANTALLA DE REPORTE
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReportScreen(
                              startDate: _startDate!,
                              endDate: _endDate!,
                              salesDocs: salesData,
                              expenseDocs: expensesData,
                              totalRevenue: totalRevenue,
                              totalCost: totalCost,
                              totalExpenses: totalExpenses,
                              netProfit: netProfit,
                              expensesByCategory: expensesByCategory,
                              profitDistribution: profitDistribution,
                            ),
                          ),
                        );
                      },
                      label: const Text('Ver Reporte Detallado'), // TEXTO CAMBIADO
                      icon: const Icon(Icons.bar_chart), // ICONO CAMBIADO
                    ),
                    body: TabBarView(
                      children: [
                        _buildOverviewTab(context, currencyFormat, salesData, totalRevenue,
                            totalCost, totalExpenses, netProfit, expensesByCategory, profitDistribution),
                        _buildBreakdownTab(
                            context, currencyFormat, salesData, expensesData, dateFormat),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    NumberFormat currencyFormat,
    List<Map<String, dynamic>> salesData,
    double totalRevenue,
    double totalCost,
    double totalExpenses,
    double netProfit,
    Map<String, double> expensesByCategory,
    Map<String, double> profitDistribution,
  ) {
    final int totalOrders = salesData.length;
    final double averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Padding for FAB
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen del Período', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildMetricCard(context, label: 'Ganancia Neta REAL', value: currencyFormat.format(netProfit), icon: Icons.insights, color: Theme.of(context).colorScheme.primary, isFullWidth: true),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildMetricCard(context, label: 'Ingresos Totales', value: currencyFormat.format(totalRevenue), icon: Icons.attach_money, color: Colors.green.shade600)),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricCard(context, label: 'Costos de Productos', value: currencyFormat.format(totalCost), icon: Icons.shopping_cart_checkout, color: Colors.orange.shade600)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildMetricCard(context, label: 'Total de Gastos', value: currencyFormat.format(totalExpenses), icon: Icons.receipt, color: Colors.red.shade600)),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricCard(context, label: 'Órdenes Finalizadas', value: totalOrders.toString(), icon: Icons.receipt_long, color: Colors.blue.shade600)),
          ]),
          const SizedBox(height: 16),
           _buildMetricCard(context, label: 'Ticket Promedio', value: currencyFormat.format(averageOrderValue), icon: Icons.pie_chart, color: Colors.purple.shade400, isFullWidth: true),

          const SizedBox(height: 24),
          Text('Distribución de Ganancia Neta', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...profitDistribution.entries.map((entry) {
            final Map<String, double> percentages = {
              'Rentas y servicios': 67,
              'Otros gastos': 17,
              'Losa': 8,
              'Transporte': 8,
            };
            return _buildExpenseCategoryCard(context, currencyFormat, entry.key, entry.value, netProfit, percentage: percentages[entry.key]);
          }).toList(),


          const SizedBox(height: 24),
          Text('Desglose de Gastos por Categoría', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (expensesByCategory.isEmpty)
            const Center(child: Text('No hay gastos registrados en este período.'))
          else
            ...expensesByCategory.entries.map((entry) => 
              _buildExpenseCategoryCard(context, currencyFormat, entry.key, entry.value, totalExpenses)
            ).toList(),
        ],
      ),
    );
  }

   Widget _buildBreakdownTab(BuildContext context, NumberFormat currencyFormat, List<Map<String, dynamic>> salesData, List<Map<String, dynamic>> expensesData, DateFormat dateFormat) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Padding for FAB
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Desglose de Órdenes del Período', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          salesData.isEmpty
              ? const Center(child: Text('No hay ventas en este período.'))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: salesData.length,
                  itemBuilder: (context, index) {
                    final data = salesData[index];
                    final double orderRevenue = (data['total_orden'] ?? 0.0).toDouble();
                    final double orderCost = (data['total_costo'] ?? 0.0).toDouble();
                    final double orderProfit = orderRevenue - orderCost;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        title: Text(data['nombre_orden'] ?? 'Orden sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'Ganancia: ${currencyFormat.format(orderProfit)}\nPagado con: ${data['metodo_pago'] ?? 'N/A'}'),
                        trailing: Text(
                            'Ingreso: ${currencyFormat.format(orderRevenue)}', 
                            style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 14)),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
          const SizedBox(height: 24),
          Text('Desglose de Gastos del Período', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          expensesData.isEmpty
              ? const Center(child: Text('No hay gastos en este período.'))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: expensesData.length,
                  itemBuilder: (context, index) {
                    final expense = expensesData[index];
                    final String description = expense['descripcion'] ?? 'Sin descripción';
                    final double amount = (expense['monto'] ?? 0.0).toDouble();
                    final String category = expense['categoria'] ?? 'Sin categoría';
                     final DateTime date = (expense['fecha'] as Timestamp).toDate();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 2,
                      child: ListTile(
                         leading: const Icon(Icons.payment, color: Colors.white70),
                        title: Text(description, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$category - ${dateFormat.format(date)}'),
                        trailing: Text(
                          currencyFormat.format(amount),
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }


  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [BarChartRodData(toY: y, color: color, width: 22, borderRadius: BorderRadius.zero)],
    );
  }

  Widget _buildMetricCard(BuildContext context, { required String label, required String value, required IconData icon, required Color color, bool isFullWidth = false }) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color), maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCategoryCard(BuildContext context, NumberFormat currencyFormat, String category, double amount, double total, {double? percentage}) {
    final double calculatedPercentage = percentage ?? (total > 0 ? (amount / total) * 100 : 0);
    final Color progressColor = percentage == null ? Colors.redAccent : Theme.of(context).colorScheme.secondary; // Different color for profit distribution

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(category, style: Theme.of(context).textTheme.titleMedium),
                Text(currencyFormat.format(amount), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: calculatedPercentage / 100,
                    backgroundColor: Colors.grey.shade700,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${calculatedPercentage.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.bodySmall),
              ],
            )
          ],
        ),
      ),
    );
  }
}
