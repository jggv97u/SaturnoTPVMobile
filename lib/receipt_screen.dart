import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptScreen extends StatelessWidget {
  final DocumentSnapshot order;

  const ReceiptScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final orderData = order.data() as Map<String, dynamic>?;

    if (orderData == null) {
      return const Scaffold(
        body: Center(
          child: Text('Error: No se pudieron cargar los datos de la orden.'),
        ),
      );
    }

    final items = (orderData['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final total = (orderData['total_orden'] ?? 0.0).toDouble();
    final Timestamp? openTimestamp = orderData['timestamp_apertura'] as Timestamp?;
    final Timestamp? closeTimestamp = orderData['timestamp_cierre'] as Timestamp?;

    return Scaffold(
      appBar: AppBar(
        title: Text(orderData['nombre_orden'] ?? 'Recibo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Detalle de la Orden',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            if (openTimestamp != null)
              Text('Abierta: ${openTimestamp.toDate().toLocal().toString().substring(0, 16)}'),
            if (closeTimestamp != null)
              Text('Cerrada: ${closeTimestamp.toDate().toLocal().toString().substring(0, 16)}'),
            const Divider(height: 20, thickness: 1),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final itemName = item['nombre'] ?? 'Artículo no encontrado';
                  final quantity = item['quantity'] ?? 0;
                  final price = (item['precio'] ?? 0.0).toDouble();
                  return ListTile(
                    title: Text(itemName),
                    subtitle: Text('Cantidad: $quantity'),
                    trailing: Text('\$${(price * quantity).toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
            const Divider(thickness: 2),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Pagado:', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
