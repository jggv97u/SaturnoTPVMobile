import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'receipt_screen.dart';
import 'dart:developer' as developer;

class PaymentScreen extends StatefulWidget {
  final DocumentSnapshot order;

  const PaymentScreen({super.key, required this.order});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;

  Future<void> _showErrorDialog(String errorMessage) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error Crítico en el Pago'),
          content: SingleChildScrollView(
            child: Text(
              'No se pudo archivar la venta. La orden no ha sido modificada y sigue activa.\n\nDetalle del error:\n$errorMessage',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Aceptar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _finalizePayment(String paymentMethod) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final orderData = widget.order.data() as Map<String, dynamic>;
      final List<dynamic> items = List.from(orderData['items'] ?? []);
      final customerId = orderData['cliente_id'];

      if (items.isEmpty) {
        throw Exception('La orden no tiene productos para procesar.');
      }

      await _firestore.runTransaction((transaction) async {
        final DocumentReference orderRef = widget.order.reference;
        DocumentReference? customerRef;
        DocumentSnapshot? customerDoc;

        // 1. Calculate points and costs
        int pointsEarned = 0;
        double totalCosto = 0.0;
        List<Map<String, dynamic>> itemsConCosto = [];

        for (var item in items) {
          final itemMap = Map<String, dynamic>.from(item as Map);
          final productId = itemMap['id'];
          final cantidad = (itemMap['cantidad'] ?? 0) as int; // Each drink is a point
          pointsEarned += cantidad;
          double costoUnitario = 0.0;

          if (productId != null) {
             final productDocRef = _firestore.collection('bebidas').doc(productId);
             final productDoc = await transaction.get(productDocRef); // Get product within transaction
            if (productDoc.exists) {
              final productData = productDoc.data() as Map<String, dynamic>;
              costoUnitario = (productData['costo'] ?? 0.0).toDouble();
            } else {
              developer.log('Producto con ID: $productId no encontrado.', name: 'saturnotrc.payment');
            }
          }
          itemMap['costo_unitario'] = costoUnitario;
          itemsConCosto.add(itemMap);
          totalCosto += costoUnitario * cantidad;
        }

        // 2. Handle customer points if a customer is linked
        if (customerId != null) {
          customerRef = _firestore.collection('clientes').doc(customerId);
          customerDoc = await transaction.get(customerRef); // Get customer within transaction

          if (customerDoc.exists) {
            final customerData = customerDoc!.data() as Map<String, dynamic>;
            final currentPoints = (customerData['puntos'] ?? 0) as int;
            final newTotalPoints = currentPoints + pointsEarned;

            if (newTotalPoints >= 7) {
              // Reward achieved
              transaction.update(customerRef, {
                'puntos': 0, // Reset points
                'recompensas': FieldValue.increment(1),
                'ultima_recompensa': FieldValue.serverTimestamp(),
              });
            } else {
              // Just increment points
              transaction.update(customerRef, {'puntos': newTotalPoints});
            }
          }
        }
        
        // 3. Archive the order
        final newArchivedOrderRef = _firestore.collection('ordenes_archivadas').doc(orderRef.id);
        final archivedOrderData = {
          ...orderData,
          'pagada': true,
          'activa': false,
          'metodo_pago': paymentMethod,
          'fecha_finalizacion': FieldValue.serverTimestamp(),
          'items': itemsConCosto,
          'total_costo': totalCosto,
          'puntos_ganados': pointsEarned,
        };
        transaction.set(newArchivedOrderRef, archivedOrderData);

        // 4. Delete the original active order
        transaction.delete(orderRef);
      });

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(orderId: widget.order.id),
          ),
          (Route<dynamic> route) => route.isFirst,
        );
      }
    } catch (e, s) {
      developer.log(
        'Error al archivar la venta.',
        name: 'saturnotrc.payment.archive',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        await _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final orderData = widget.order.data() as Map<String, dynamic>;
    final double total = (orderData['total_orden'] ?? 0.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Realizar Pago'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Total a Pagar:',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            Text(
              '\$${total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _finalizePayment('Efectivo'),
                    icon: const Icon(Icons.money),
                    label: const Text('Pagar con Efectivo'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      textStyle: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _finalizePayment('Tarjeta'),
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Pagar con Tarjeta'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      textStyle: const TextStyle(fontSize: 20),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
