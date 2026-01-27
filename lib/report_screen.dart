import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportScreen extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final List<Map<String, dynamic>> salesDocs;
  final List<Map<String, dynamic>> expenseDocs;
  final double totalRevenue;
  final double totalCost;
  final double totalExpenses;
  final double netProfit;
  final Map<String, double> expensesByCategory;
  final Map<String, double> profitDistribution;

  const ReportScreen({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.salesDocs,
    required this.expenseDocs,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalExpenses,
    required this.netProfit,
    required this.expensesByCategory,
    required this.profitDistribution,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Rentabilidad'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir Reporte',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Usa la función de impresión de tu navegador (Ctrl+P o Cmd+P) para guardar o imprimir esta página.')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(dateFormat),
            const SizedBox(height: 32),
            _buildSummary(currencyFormat),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Distribución de Ganancia Neta'),
            _buildProfitDistributionTable(currencyFormat),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Gastos por Categoría'),
            _buildExpenseCategoryTable(currencyFormat),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Desglose de Órdenes'),
            _buildSalesTable(currencyFormat, dateTimeFormat),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Desglose de Gastos'),
            _buildExpensesTable(currencyFormat, dateFormat),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DateFormat dateFormat) {
    return Center(
      child: Column(
        children: [
          Text(
            'Período del Reporte',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(NumberFormat currencyFormat) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2.5, // Adjust for better spacing
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricCard('Ingresos Totales', currencyFormat.format(totalRevenue), Colors.green.shade600, Icons.trending_up),
        _buildMetricCard('Costos de Productos', currencyFormat.format(totalCost), Colors.orange.shade600, Icons.shopping_cart),
        _buildMetricCard('Total de Gastos', currencyFormat.format(totalExpenses), Colors.red.shade600, Icons.receipt_long),
        _buildMetricCard('Ganancia Neta REAL', currencyFormat.format(netProfit), Colors.blue.shade600, Icons.attach_money, isHighlighted: true),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon, {bool isHighlighted = false}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isHighlighted ? color : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: isHighlighted ? Colors.white : color, size: 20),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontSize: 14, color: isHighlighted ? Colors.white70 : Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isHighlighted ? Colors.white : color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProfitDistributionTable(NumberFormat currencyFormat) {
    final Map<String, double> percentages = {
      'Rentas y servicios': 67,
      'Otros gastos': 17,
      'Losa': 8,
      'Transporte': 8,
    };
    
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.teal.shade50),
        columns: const [
          DataColumn(label: Text('Cuenta de Ganancia', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Porcentaje'), numeric: true),
          DataColumn(label: Text('Monto Asignado'), numeric: true),
        ],
        rows: profitDistribution.entries.map((entry) {
          return DataRow(
            cells: [
              DataCell(Text(entry.key)),
              DataCell(Text('${percentages[entry.key]?.toStringAsFixed(0)}%')),
              DataCell(Text(currencyFormat.format(entry.value))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpenseCategoryTable(NumberFormat currencyFormat) {
     return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade50),
        columns: const [
          DataColumn(label: Text('Categoría de Gasto', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Monto Total'), numeric: true),
        ],
        rows: expensesByCategory.entries.map((entry) {
          return DataRow(
            cells: [
              DataCell(Text(entry.key)),
              DataCell(Text(currencyFormat.format(entry.value))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSalesTable(NumberFormat currencyFormat, DateFormat dateTimeFormat) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
        columns: const [
          DataColumn(label: Text('Orden', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Ingreso'), numeric: true),
          DataColumn(label: Text('Costo'), numeric: true),
          DataColumn(label: Text('Ganancia'), numeric: true),
          DataColumn(label: Text('Fecha'), numeric: true),
        ],
        rows: salesDocs.map((sale) {
          final double orderRevenue = (sale['total_orden'] ?? 0.0).toDouble();
          final double orderCost = (sale['total_costo'] ?? 0.0).toDouble();
          final double orderProfit = orderRevenue - orderCost;
          final date = (sale['fecha_finalizacion'] as Timestamp?)?.toDate();
          final formattedDate = date != null ? dateTimeFormat.format(date) : 'N/A';
          return DataRow(
            cells: [
              DataCell(Text(sale['nombre_orden'] ?? 'N/A')),
              DataCell(Text(currencyFormat.format(orderRevenue))),
              DataCell(Text(currencyFormat.format(orderCost))),
              DataCell(Text(currencyFormat.format(orderProfit))),
              DataCell(Text(formattedDate)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpensesTable(NumberFormat currencyFormat, DateFormat dateFormat) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.red.shade50),
        columns: const [
          DataColumn(label: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Categoría')),
          DataColumn(label: Text('Monto'), numeric: true),
          DataColumn(label: Text('Fecha'), numeric: true),
        ],
        rows: expenseDocs.map((expense) {
          final date = (expense['fecha'] as Timestamp?)?.toDate();
          final formattedDate = date != null ? dateFormat.format(date) : 'N/A';
          return DataRow(
            cells: [
              DataCell(Text(expense['descripcion'] ?? 'N/A')),
              DataCell(Text(expense['categoria'] ?? 'N/A')),
              DataCell(Text(currencyFormat.format((expense['monto'] ?? 0.0).toDouble()))),
              DataCell(Text(formattedDate)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
