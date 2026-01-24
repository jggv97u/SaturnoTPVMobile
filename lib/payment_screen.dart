import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentScreen extends StatelessWidget {
  final DocumentSnapshot order;

  const PaymentScreen({super.key, required this.order});

  Future<void> _processPayment(BuildContext context, double total) async {
    final orderData = order.data() as Map<String, dynamic>;

    final newClosedOrder = {
      'nombre_orden': orderData['nombre_orden'] ?? 'N/A',
      'items': orderData['items'] ?? [],
      'total_orden': total,
      'timestamp_apertura': orderData['timestamp'] ?? FieldValue.serverTimestamp(),
      'timestamp_cierre': FieldValue.serverTimestamp(),
      'pagado': true,
    };

    await FirebaseFirestore.instance.collection('ordenes_cerradas').add(newClosedOrder);
    await FirebaseFirestore.instance.collection('ordenes_activas').doc(order.id).delete();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Pago completado! Orden cerrada.'), backgroundColor: Colors.green),
    );
    // Navegar hacia atrás 2 veces para volver a la pantalla principal de órdenes
    int count = 0;
    Navigator.of(context).popUntil((_) => count++ >= 2);
  }

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar y Pagar'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recibo de la Orden', 
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
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
                  Text('Total a Pagar:', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.payment),
              label: const Text('Pagar Ahora'),
              onPressed: () => _processPayment(context, total),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
