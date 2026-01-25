import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderSummaryScreen extends StatefulWidget {
  final Map<String, int> orderItems;
  final String orderName;

  const OrderSummaryScreen({
    super.key,
    required this.orderItems,
    required this.orderName,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  bool _isLoading = false;

  Future<void> _placeOrder(double totalOrder, List<Map<String, dynamic>> orderDetails) async {
    if (widget.orderName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre de la orden no puede estar vacío.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('pedidos').add({
        'nombre_orden': widget.orderName,
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
          SnackBar(content: Text('Error al enviar la orden: $e')),
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

  Future<Map<String, dynamic>> _getOrderSummary() async {
    final details = <Map<String, dynamic>>[];
    double totalOrder = 0;
    final drinkIds = widget.orderItems.keys.toList();

    if (drinkIds.isEmpty) return {'details': [], 'total': 0.0};

    final drinksSnapshot = await FirebaseFirestore.instance
        .collection('bebidas')
        .where(FieldPath.documentId, whereIn: drinkIds)
        .get();
    final drinksData = {for (var doc in drinksSnapshot.docs) doc.id: doc.data()};

    for (var item in widget.orderItems.entries) {
      final drinkData = drinksData[item.key];
      if (drinkData != null) {
        final price = (drinkData['precio'] as num).toDouble();
        final quantity = item.value;
        final totalPrice = price * quantity;
        totalOrder += totalPrice;

        details.add({
          'id': item.key,
          'nombre': drinkData['nombre'],
          'cantidad': quantity,
          'precioUnitario': price,
          'precioTotal': totalPrice,
        });
      }
    }
    return {'details': details, 'total': totalOrder};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen de la Orden'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getOrderSummary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error al cargar el resumen.'));
          }

          final orderDetails = snapshot.data!['details'] as List<Map<String, dynamic>>;
          final total = snapshot.data!['total'] as double;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Nombre: ${widget.orderName}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: orderDetails.length,
                    itemBuilder: (context, index) {
                      final item = orderDetails[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          title: Text(item['nombre']),
                          subtitle: Text('Cantidad: ${item['cantidad']}'),
                          trailing: Text('\$${(item['precioTotal'] as double).toStringAsFixed(2)}'),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(thickness: 2, height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total:', style: Theme.of(context).textTheme.headlineMedium),
                    Text('\$${total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () => _placeOrder(total, orderDetails),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Enviar Orden'),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
