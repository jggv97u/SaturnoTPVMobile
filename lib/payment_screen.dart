import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saturnotrc/receipt_screen.dart';

class PaymentScreen extends StatefulWidget {
  final DocumentSnapshot order;

  const PaymentScreen({super.key, required this.order});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;

  Future<void> _finalizePayment(String paymentMethod) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await widget.order.reference.update({
        'pagada': true,
        'activa': false, 
        'metodo_pago': paymentMethod,
        'fecha_finalizacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(orderId: widget.order.id),
          ),
          (Route<dynamic> route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al finalizar el pago.')),
        );
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
