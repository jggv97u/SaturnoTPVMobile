import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomerOrderStatusScreen extends StatelessWidget {
  final String orderId;

  const CustomerOrderStatusScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estado de tu Pedido #${orderId.substring(0, 6)}'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pedidos_online')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String status = data['estado'] ?? 'Desconocido';

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildStatusIndicator(context, status),
              const SizedBox(height: 24),
              _buildOrderSummary(data),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, String status) {
    IconData icon;
    Color color;
    String message;

    switch (status) {
      case 'En preparación':
        icon = Icons.kitchen_outlined;
        color = Colors.orangeAccent;
        message = 'Tu café se está preparando con esmero.';
        break;
      case 'Listo para Recoger':
        icon = Icons.check_circle_outline;
        color = Colors.greenAccent;
        message = '¡Ya puedes pasar a recogerlo! Te esperamos.';
        break;
      case 'Completado':
        icon = Icons.coffee_maker_outlined;
        color = Colors.grey;
        message = 'Pedido entregado. ¡Que lo disfrutes!';
        break;
      case 'Cancelado':
        icon = Icons.cancel_outlined;
        color = Colors.redAccent;
        message = 'Este pedido ha sido cancelado.';
        break;
      default: // Recibido
        icon = Icons.receipt_long_outlined;
        color = Colors.blueAccent;
        message = 'Hemos recibido tu pedido correctamente.';
    }

    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 16),
            Text(
              status,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    final double total = (data['total_orden'] as num).toDouble();
    final Timestamp? timestamp = data['fecha_creacion'];
    final String dateTime = timestamp != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
        : '--:--';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumen de tu Compra', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Realizado el: $dateTime'),
            const Divider(height: 20),
            ...items.map((item) => ListTile(
                  title: Text(item['nombre']),
                  leading: Text('${item['cantidad']}x'),
                  trailing: Text('\$${(item['precioTotal'] as num).toStringAsFixed(2)}'),
            )),
            const Divider(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: \$${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
