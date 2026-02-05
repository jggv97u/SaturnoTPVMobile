import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OrderMenuScreen extends StatefulWidget {
  const OrderMenuScreen({super.key});

  @override
  State<OrderMenuScreen> createState() => _OrderMenuScreenState();
}

class _OrderMenuScreenState extends State<OrderMenuScreen> {
  final Map<String, int> _orderItems = {};

  void _addItem(String drinkId) {
    setState(() {
      _orderItems.update(drinkId, (value) => value + 1, ifAbsent: () => 1);
    });
  }

  void _removeItem(String drinkId) {
    setState(() {
      if (_orderItems.containsKey(drinkId)) {
        if (_orderItems[drinkId]! > 1) {
          _orderItems.update(drinkId, (value) => value - 1);
        } else {
          _orderItems.remove(drinkId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea tu Pedido Express'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bebidas')
            .where('inStock', isEqualTo: true)
            .orderBy('nombre')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar el menú.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final drinks = snapshot.data!.docs;
          final groupedDrinks = groupBy(drinks, (doc) => (doc.data() as Map)['categoria']);
          final sortedEntries = groupedDrinks.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          return ListView(
            children: sortedEntries.map((entry) {
              final sortedDrinks = entry.value
                ..sort((a, b) {
                  final aName = (a.data() as Map<String, dynamic>)['nombre'] as String;
                  final bName = (b.data() as Map<String, dynamic>)['nombre'] as String;
                  return aName.compareTo(bName);
                });

              return Column(
                key: ValueKey(entry.key),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  ...sortedDrinks.map((drink) {
                    final drinkId = drink.id;
                    final drinkData = drink.data() as Map<String, dynamic>;
                    final quantity = _orderItems[drinkId] ?? 0;

                    return Card(
                      key: ValueKey(drinkId),
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    drinkData['nombre'],
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '\$${drinkData['precio']}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                  onPressed: () => _removeItem(drinkId),
                                ),
                                Text(
                                  '$quantity',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
                                  onPressed: () => _addItem(drinkId),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: _orderItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                // Navegar a la pantalla de resumen, pasando el carrito.
                context.go('/order-summary', extra: _orderItems);
              },
              label: const Text('Ver Orden'),
              icon: const Icon(Icons.shopping_cart),
            )
          : null,
    );
  }
}
