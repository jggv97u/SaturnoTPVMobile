import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha
import 'order_detail_screen.dart'; // Importa la nueva pantalla de detalle

class OnlineOrdersScreen extends StatefulWidget {
  const OnlineOrdersScreen({super.key});

  @override
  State<OnlineOrdersScreen> createState() => _OnlineOrdersScreenState();
}

class _OnlineOrdersScreenState extends State<OnlineOrdersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos Online para Recoger'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pedidos_online')
            .orderBy('fecha_creacion', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar los pedidos.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.coffee, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text('No hay pedidos pendientes.', style: TextStyle(fontSize: 22, color: Colors.grey)),
                ],
              ),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;

              final String orderId = order.id;
              final String customerName = data['cliente_nombre'] ?? 'N/A';
              final String status = data['estado'] ?? 'Desconocido';
              final double total = (data['total_orden'] as num).toDouble();
              final Timestamp? timestamp = data['fecha_creacion'];
              final String time = timestamp != null 
                  ? DateFormat('HH:mm').format(timestamp.toDate())
                  : '--:--';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                elevation: 5,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16.0),
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(status),
                    child: Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  title: Text(
                    '#${orderId.substring(0, 6)} - $customerName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Text(
                    'Estado: $status',
                    style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  onTap: () {
                    // Navegar a la pantalla de detalle del pedido
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailScreen(orderId: orderId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Recibido':
        return Colors.blueAccent;
      case 'En preparación':
        return Colors.orangeAccent;
      case 'Listo para Recoger':
        return Colors.greenAccent;
      case 'Completado':
        return Colors.grey;
      case 'Cancelado':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
