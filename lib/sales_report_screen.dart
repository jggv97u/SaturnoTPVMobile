import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalesReportScreen extends StatelessWidget {
  const SalesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Ventas'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ordenes_archivadas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar los datos.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay ventas registradas todavía.'));
          }

          final salesDocs = snapshot.data!.docs;

          // Calculate metrics
          double totalRevenue = salesDocs.fold(0.0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            return sum + (data['total_orden'] ?? 0.0);
          });
          int totalOrders = salesDocs.length;
          double averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen General',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFamily: 'LemonMilk',
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        label: 'Ingresos Totales',
                        value: currencyFormat.format(totalRevenue),
                        icon: Icons.attach_money,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        label: 'Órdenes Finalizadas',
                        value: totalOrders.toString(),
                        icon: Icons.receipt_long,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMetricCard(
                  context,
                  label: 'Valor Promedio por Orden',
                  value: currencyFormat.format(averageOrderValue),
                  icon: Icons.pie_chart,
                  color: Colors.orange,
                  isFullWidth: true,
                ),
                const SizedBox(height: 24),
                Text(
                  'Ventas Recientes',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFamily: 'LemonMilk',
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: salesDocs.length > 5 ? 5 : salesDocs.length, // Show last 5
                  itemBuilder: (context, index) {
                    final doc = salesDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(data['nombre_orden'] ?? 'Orden sin nombre'),
                        subtitle: Text(
                          'Pagado con: ${data['metodo_pago'] ?? 'N/A'}',
                        ),
                        trailing: Text(
                          currencyFormat.format(data['total_orden'] ?? 0.0),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Card(
      elevation: 4,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
