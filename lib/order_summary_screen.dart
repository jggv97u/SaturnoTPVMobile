import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderSummaryScreen extends StatefulWidget {
  final Map<String, int> orderItems;

  const OrderSummaryScreen({super.key, required this.orderItems});

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  final _orderNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _placeOrder() async {
    if (_orderNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un nombre para la orden.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final drinksCollection = FirebaseFirestore.instance.collection('bebidas');
      final orderDetails = <Map<String, dynamic>>[];
      double totalOrder = 0;

      for (var item in widget.orderItems.entries) {
        final drinkDoc = await drinksCollection.doc(item.key).get();
        final drinkData = drinkDoc.data() as Map<String, dynamic>;
        final price = drinkData['precio'];
        final quantity = item.value;
        final totalPrice = price * quantity;

        orderDetails.add({
          'nombre': drinkData['nombre'],
          'cantidad': quantity,
          'precioUnitario': price,
          'precioTotal': totalPrice,
        });

        totalOrder += totalPrice;
      }

      await FirebaseFirestore.instance.collection('pedidos').add({
        'nombre_orden': _orderNameController.text,
        'items': orderDetails,
        'total_orden': totalOrder,
        'fecha_hora': FieldValue.serverTimestamp(),
        'activa': true,
        'pagada': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden enviada con éxito.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar la orden.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen de la Orden'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _orderNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Orden',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _buildOrderDetails(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error al cargar los detalles de la orden.'));
                  }

                  final orderDetails = snapshot.data!;

                  return ListView.builder(
                    itemCount: orderDetails.length,
                    itemBuilder: (context, index) {
                      final item = orderDetails[index];
                      return ListTile(
                        title: Text(item['nombre']),
                        subtitle: Text('Cantidad: ${item['cantidad']}'),
                        trailing: Text('\$${item['precioTotal']}'),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _placeOrder,
                    child: const Text('Enviar Orden'),
                  ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _buildOrderDetails() async {
    final drinksCollection = FirebaseFirestore.instance.collection('bebidas');
    final details = <Map<String, dynamic>>[];

    for (var item in widget.orderItems.entries) {
      final drinkDoc = await drinksCollection.doc(item.key).get();
      final drinkData = drinkDoc.data() as Map<String, dynamic>;
      final price = drinkData['precio'];
      final quantity = item.value;
      final totalPrice = price * quantity;

      details.add({
        'nombre': drinkData['nombre'],
        'cantidad': quantity,
        'precioTotal': totalPrice,
      });
    }
    return details;
  }
}
