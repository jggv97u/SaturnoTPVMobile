import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saturnotrc/payment_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final DocumentSnapshot order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isCancelling = false;

  Future<void> _cancelOrder() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Cancelación'),
        content: const Text('¿Estás seguro de que quieres cancelar esta orden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isCancelling = true;
      });

      try {
        await widget.order.reference.update({'activa': false});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Orden cancelada con éxito.')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cancelar la orden.')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isCancelling = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderData = widget.order.data() as Map<String, dynamic>;
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
                  title: Text(item['nombre'] ?? 'N/A'), // Corregido
                  subtitle: Text('Cantidad: ${item['cantidad']}'), // Corregido
                  trailing: Text(
                      '\$${(item['precioTotal'] ?? 0.0).toStringAsFixed(2)}'), // Corregido
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
                Text('\$${total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(order: widget.order),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Proceder al Pago'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _isCancelling ? null : _cancelOrder,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    foregroundColor: Colors.red,
                  ),
                  child: _isCancelling
                      ? const CircularProgressIndicator()
                      : const Text('Cancelar Orden'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
