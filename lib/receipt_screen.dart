import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ReceiptScreen extends StatelessWidget {
  final String orderId;

  const ReceiptScreen({super.key, required this.orderId});

  Future<void> _shareReceipt(BuildContext context, Map<String, dynamic> orderData) async {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'es_MX');
    final items = (orderData['items'] as List)
        .map((item) => '- ${item['nombre']} x${item['cantidad']}: ${currencyFormat.format(item['precioTotal'])}')
        .join('\n');
    final total = currencyFormat.format(orderData['total_orden']);
    final paymentMethod = orderData['metodo_pago'] ?? 'No especificado';
    final date = (orderData['fecha_finalizacion'] as Timestamp?)?.toDate();
    final formattedDate = date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : 'N/A';

    final receiptText = '''
*Recibo de Venta - Saturno TPV*

*Orden:* ${orderData['nombre_orden']}
*Fecha:* $formattedDate

*Detalles:*
$items

*Total:* *$total*
*Pagado con:* $paymentMethod

¡Gracias por tu compra!
''';

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    Share.share(
      receiptText,
      subject: 'Recibo de tu compra en Saturno TPV',
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recibo de Venta'),
        automaticallyImplyLeading: false, // Oculta el botón de regreso
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('ordenes_archivadas').doc(orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar el recibo.'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('El recibo no fue encontrado.'));
          }

          final orderData = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> items = orderData['items'] ?? [];
          final total = orderData['total_orden'] ?? 0.0;
          final paymentMethod = orderData['metodo_pago'] ?? 'No especificado';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderData['nombre_orden'] ?? 'Orden',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Divider(),
                        ...items.map((item) => ListTile(
                              title: Text(item['nombre'] ?? 'N/A'),
                              subtitle: Text('Cantidad: ${item['cantidad']}'),
                              trailing: Text(NumberFormat.simpleCurrency(
                                      locale: 'es_MX')
                                  .format(item['precioTotal'] ?? 0.0)),
                            )),
                        const Divider(),
                        ListTile(
                          title: Text('Método de pago', style: Theme.of(context).textTheme.titleMedium),
                          trailing: Text(paymentMethod, style: Theme.of(context).textTheme.bodyLarge),
                        ),
                        ListTile(
                          title: Text('Total Pagado', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold
                          )),
                          trailing: Text(
                            NumberFormat.simpleCurrency(locale: 'es_MX')
                                .format(total),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold
                          )
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _shareReceipt(context, orderData),
                  icon: const Icon(Icons.share),
                  label: const Text('Compartir Recibo'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Volver al inicio'),
                   style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
