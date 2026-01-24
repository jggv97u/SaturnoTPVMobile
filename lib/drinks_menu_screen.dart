import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saturnotrc/order_summary_screen.dart';

class DrinksMenuScreen extends StatefulWidget {
  const DrinksMenuScreen({super.key});

  @override
  State<DrinksMenuScreen> createState() => _DrinksMenuScreenState();
}

class _DrinksMenuScreenState extends State<DrinksMenuScreen> {
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
        title: const Text('Menú de Bebidas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bebidas')
            .where('inStock', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar las bebidas.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final drinks = snapshot.data!.docs;
          final groupedDrinks =
              groupBy(drinks, (doc) => (doc.data() as Map)['categoria']);

          return ListView(
            children: groupedDrinks.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  ...entry.value.map((drink) {
                    final drinkId = drink.id;
                    final drinkData = drink.data() as Map<String, dynamic>;
                    final quantity = _orderItems[drinkId] ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  drinkData['nombre'],
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  '\$${drinkData['precio']}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _removeItem(drinkId),
                                ),
                                Text(
                                  '$quantity',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        OrderSummaryScreen(orderItems: _orderItems),
                  ),
                );
              },
              label: const Text('Ver Orden'),
              icon: const Icon(Icons.shopping_cart),
            )
          : null,
    );
  }
}
