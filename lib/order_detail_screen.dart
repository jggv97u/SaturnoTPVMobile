import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'drinks_menu_screen.dart';
import 'payment_screen.dart'; // Import the payment screen

class OrderDetailScreen extends StatefulWidget {
  final DocumentSnapshot order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isProcessing = false;

  // Corrected function to navigate to the payment screen
  Future<void> _closeAndPayOrder() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(order: widget.order),
      ),
    );
  }

  Future<void> _cancelOrder() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Cancelación'),
        content: const Text('¿Estás seguro de que quieres cancelar esta orden? Esto la marcará como inactiva pero no pagada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, Cancelar'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await widget.order.reference.update({'activa': false});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden cancelada.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar la orden: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderData = widget.order.data() as Map<String, dynamic>;
    final items = orderData['items'] as List<dynamic>? ?? [];
    final total = (orderData['total_orden'] ?? 0.0).toDouble();
    final customerName = orderData['cliente_nombre'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(orderData['nombre_orden'] ?? 'Detalle de Orden'),
      ),
      body: Column(
        children: [
          if (customerName != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text('Cliente: ', style: Theme.of(context).textTheme.titleMedium),
                  Text(customerName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    title: Text(item['nombre'] ?? 'N/A'),
                    subtitle: Text('Cantidad: ${item['cantidad']}'),
                    trailing: Text('\$${(item['precioTotal'] ?? 0.0).toStringAsFixed(2)}'),
                  ),
                );
              },
            ),
          ),
          const Divider(thickness: 2, height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total:', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text('\$${total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _isProcessing
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _closeAndPayOrder,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green.shade700,
                        ),
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text('Cerrar y Pagar Orden', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DrinksMenuScreen(existingOrder: widget.order),
                            ),
                          );
                        },
                         style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.orange.shade700,
                        ),
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text('Modificar Orden', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _cancelOrder,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.red.shade400),
                          foregroundColor: Colors.red.shade400,
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancelar Orden'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
