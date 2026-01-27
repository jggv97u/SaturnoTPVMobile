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

      if (items.isEmpty) {
        throw Exception('La orden no tiene productos para procesar.');
      }
      
      double totalCosto = 0.0;
      List<Map<String, dynamic>> itemsConCosto = [];

      for (var item in items) {
        final itemMap = Map<String, dynamic>.from(item as Map);
        final productId = itemMap['id'];
        final cantidad = (itemMap['cantidad'] ?? 0) as num;
        double costoUnitario = 0.0;

        if (productId != null) {
          final productDoc = await _firestore.collection('bebidas').doc(productId).get();
          if (productDoc.exists) {
            final productData = productDoc.data() as Map<String, dynamic>;
            costoUnitario = (productData['costo'] ?? 0.0).toDouble();
          } else {
            developer.log('Producto con ID: $productId no encontrado en el catálogo.', name: 'saturnotrc.payment');
          }
        }
        
        itemMap['costo_unitario'] = costoUnitario;
        itemsConCosto.add(itemMap);
        totalCosto += costoUnitario * cantidad;
      }
      
      // --- ATOMIC TRANSACTION: Move order from 'pedidos' to 'ordenes_archivadas' ---
      final WriteBatch batch = _firestore.batch();

      // 1. Create a reference for the new document in 'ordenes_archivadas'
      final newArchivedOrderRef = _firestore.collection('ordenes_archivadas').doc(widget.order.id);

      // 2. Prepare the complete data for the archived order
      final archivedOrderData = {
        ...orderData, // Copy all original data
        'pagada': true,
        'activa': false,
        'metodo_pago': paymentMethod,
        'fecha_finalizacion': FieldValue.serverTimestamp(),
        'items': itemsConCosto,
        'total_costo': totalCosto,
      };

      // 3. Set the data for the new archived order in the batch
      batch.set(newArchivedOrderRef, archivedOrderData);

      // 4. Delete the original order from 'pedidos' in the batch
      batch.delete(widget.order.reference);

      // 5. Commit the atomic operation
      await batch.commit();

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
