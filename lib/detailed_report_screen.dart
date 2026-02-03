import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetailedReportScreen extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final List<Map<String, dynamic>> salesDocs;
  final List<Map<String, dynamic>> expenseDocs;
  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;
  final Map<String, double> expensesByCategory;
  final Map<String, double> profitDistribution;

  const DetailedReportScreen({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.salesDocs,
    required this.expenseDocs,
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.expensesByCategory,
    required this.profitDistribution,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_MX');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Detallado'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // TODO: Implement printing functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reporte de Rentabilidad', 
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)
            ),
            Text(
              'Período: \${dateFormat.format(startDate)} - \${dateFormat.format(endDate)}',
              style: Theme.of(context).textTheme.titleMedium
            ),
            const Divider(height: 30),

            _buildSectionTitle(context, 'Resumen Financiero'),
            _buildSummaryTable(currencyFormat),
            const Divider(height: 30),

            _buildSectionTitle(context, 'Distribución de Presupuesto vs. Gasto'),
            _buildBudgetDistributionTable(context, currencyFormat),
            const Divider(height: 30),

            _buildSectionTitle(context, 'Detalle de Ventas (\${salesDocs.length} órdenes)'),
            _buildSalesTable(currencyFormat),
            const Divider(height: 30),

            _buildSectionTitle(context, 'Detalle de Gastos (\${expenseDocs.length} registros)'),
            _buildExpensesTable(currencyFormat),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSummaryTable(NumberFormat currencyFormat) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 1),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.5),
      },
      children: [
        _buildTableRow('Ingresos Totales', currencyFormat.format(totalRevenue), isHeader: true),
        _buildTableRow('Costos de Venta', currencyFormat.format(totalCost), isNegative: true),
        _buildTableRow('Ganancia Bruta', currencyFormat.format(grossProfit), isBold: true),
        _buildTableRow('Gastos Operativos', currencyFormat.format(totalExpenses), isNegative: true),
        _buildTableRow('Ganancia Neta REAL', currencyFormat.format(netProfit), isHeader: true, isBold: true),
      ],
    );
  }
  
  Widget _buildBudgetDistributionTable(BuildContext context, NumberFormat currencyFormat) {
    final rows = <TableRow>[];
    rows.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.grey.shade200),
        children: [
          _tableHeader('Categoría'),
          _tableHeader('Presupuesto'),
          _tableHeader('Gasto Real'),
          _tableHeader('Restante'),
        ],
      ),
    );

    profitDistribution.forEach((category, budget) {
      final spent = expensesByCategory[category] ?? 0;
      final remaining = budget - spent;
      rows.add(
        TableRow(
          children: [
            _tableCell(category),
            _tableCell(currencyFormat.format(budget), alignment: TextAlign.right),
            _tableCell(currencyFormat.format(spent), alignment: TextAlign.right, color: Colors.red.shade700),
            _tableCell(currencyFormat.format(remaining), alignment: TextAlign.right, color: remaining < 0 ? Colors.orange.shade800 : Colors.green.shade800),
          ],
        )
      );
    });

    return Table(border: TableBorder.all(color: Colors.grey.shade300), children: rows);
  }

  Widget _buildSalesTable(NumberFormat currencyFormat) {
    // Similar to _buildBudgetDistributionTable, creates a table for sales details
    final rows = <TableRow>[];
    rows.add(TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [_tableHeader('Fecha'), _tableHeader('Orden'), _tableHeader('Ingreso'), _tableHeader('Costo')],
    ));

    for (var sale in salesDocs) {
        final Timestamp? timestamp = sale['fecha_finalizacion'];
        final date = timestamp?.toDate();
        final formattedDate = date != null ? DateFormat('dd/MM/yy HH:mm').format(date) : 'N/A';

        rows.add(TableRow(
            children: [
                _tableCell(formattedDate),
                _tableCell(sale['nombre_orden'] ?? 'N/A'),
                _tableCell(currencyFormat.format(sale['total_orden'] ?? 0), alignment: TextAlign.right),
                _tableCell(currencyFormat.format(sale['total_costo'] ?? 0), alignment: TextAlign.right, color: Colors.orange.shade800),
            ],
        ));
    }

    return Table(border: TableBorder.all(color: Colors.grey.shade300), children: rows);
  }

  Widget _buildExpensesTable(NumberFormat currencyFormat) {
    // Similar to _buildBudgetDistributionTable, creates a table for expenses details
    final rows = <TableRow>[];
    rows.add(TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [_tableHeader('Fecha'), _tableHeader('Descripción'), _tableHeader('Categoría'), _tableHeader('Monto')],
    ));

    for (var expense in expenseDocs) {
        final Timestamp? timestamp = expense['fecha'];
        final date = timestamp?.toDate();
        final formattedDate = date != null ? DateFormat('dd/MM/yy').format(date) : 'N/A';

        rows.add(TableRow(
            children: [
                _tableCell(formattedDate),
                _tableCell(expense['descripcion'] ?? 'N/A'),
                _tableCell(expense['categoria'] ?? 'N/A'),
                _tableCell(currencyFormat.format(expense['monto'] ?? 0), alignment: TextAlign.right, color: Colors.red.shade700),
            ],
        ));
    }
    return Table(border: TableBorder.all(color: Colors.grey.shade300), children: rows);
  }
  
  TableRow _buildTableRow(String label, String value, {bool isHeader = false, bool isBold = false, bool isNegative = false}) {
    final style = TextStyle(
      fontWeight: isBold || isHeader ? FontWeight.bold : FontWeight.normal,
      color: isNegative ? Colors.red.shade700 : Colors.black,
      fontSize: isHeader ? 16 : 14
    );
    return TableRow(
      decoration: BoxDecoration(color: isHeader ? Colors.grey.shade100 : Colors.white),
      children: [
        Padding(padding: const EdgeInsets.all(8.0), child: Text(label, style: style)),
        Padding(padding: const EdgeInsets.all(8.0), child: Text(value, style: style, textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _tableHeader(String text) => Padding(padding: const EdgeInsets.all(10.0), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)));
  Widget _tableCell(String text, {TextAlign alignment = TextAlign.left, Color? color}) => Padding(padding: const EdgeInsets.all(8.0), child: Text(text, textAlign: alignment, style: TextStyle(color: color)));
}
