import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saturnotrc/drinks_menu_screen.dart';
import 'package:saturnotrc/payment_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final DocumentSnapshot order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final orderData = order.data() as Map<String, dynamic>;
    final List<dynamic> items = orderData['items'] ?? [];
    final double total = (orderData['total_orden'] ?? 0.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(orderData['nombre_orden'] ?? 'Detalle de Orden'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item['name'] ?? 'N/A'),
                  subtitle: Text('Cantidad: ${item['quantity']}'),
                  trailing: Text('\$${(item['price'] ?? 0.0).toStringAsFixed(2)}'),
                );
              },
            ),
          ),
          const Divider(thickness: 2),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total:', style: Theme.of(context).textTheme.headlineMedium),
                Text('\$${total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentScreen(order: order),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Proceder al Pago'),
            ),
          ),
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: OutlinedButton(
              onPressed: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DrinksMenuScreen(),
                  ),
                );
              },
               style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Añadir más productos'),
            ),
          )
        ],
      ),
    );
  }
}
