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
              'No se pudo procesar la venta. La orden no ha sido modificada y sigue activa.\n\nDetalle del error:\n$errorMessage',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Aceptar'),
              onPressed: () => Navigator.of(context).pop(),
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

      await _firestore.runTransaction((transaction) async {
        final orderRef = widget.order.reference;
        final customerId = orderData['cliente_id'];

        // --- INICIO DE LA SIMPLIFICACIÓN ---
        // La app ya no calcula puntos ni actualiza el perfil del cliente directamente.
        // Su única responsabilidad es archivar la orden y registrarla en el historial.
        // La Cloud Function 'onOrderCompleted' se encargará del resto.

        // 1. Crear el registro en 'historial_compras' (si hay cliente).
        // Esto activará la Cloud Function que actualiza el perfil del cliente.
        if (customerId != null) {
          final historialCompraRef = _firestore.collection('historial_compras').doc(orderRef.id);
          final historialData = {
            'userId': customerId,
            'items': orderData['items'],
            'createdAt': orderData['fecha_hora'] ?? FieldValue.serverTimestamp(),
            'completed': true,
            'total': orderData['total_orden'],
            'paymentMethod': paymentMethod,
          };
          transaction.set(historialCompraRef, historialData);
        }

        // 2. Archivar la orden (lógica de costos se mantiene por ahora para reportes).
        double totalCosto = 0.0;
        List<Map<String, dynamic>> itemsConCosto = [];
        for (var item in items) {
            final itemMap = Map<String, dynamic>.from(item as Map);
            final productId = itemMap['id'];
            final cantidad = (itemMap['cantidad'] ?? 0) as int;
            double costoUnitario = 0.0;

            if (productId != null) {
                final productDocRef = _firestore.collection('bebidas').doc(productId);
                // Usamos una lectura directa en lugar de en la transacción para evitar contención.
                final productDoc = await productDocRef.get(); 
                if (productDoc.exists) {
                    final productData = productDoc.data() as Map<String, dynamic>;
                    costoUnitario = (productData['costo'] ?? 0.0).toDouble();
                }
            }
            itemMap['costo_unitario'] = costoUnitario;
            itemsConCosto.add(itemMap);
            totalCosto += costoUnitario * cantidad;
        }
        
        final newArchivedOrderRef = _firestore.collection('ordenes_archivadas').doc(orderRef.id);
        final archivedOrderData = {
          ...orderData,
          'pagada': true,
          'activa': false,
          'metodo_pago': paymentMethod,
          'fecha_finalizacion': FieldValue.serverTimestamp(),
          'items': itemsConCosto, 
          'total_costo': totalCosto,
          // Los campos de puntos se eliminan de aquí.
        };
        transaction.set(newArchivedOrderRef, archivedOrderData);

        // 3. Borrar la orden activa original.
        transaction.delete(orderRef);

        // --- FIN DE LA SIMPLIFICACIÓN ---
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
        'Error al finalizar el pago desde el cliente.',
        name: 'saturnotrc.payment.finalize',
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
