import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saturnotrc/order_summary_screen.dart';

class DrinksMenuScreen extends StatefulWidget {
  final DocumentSnapshot? existingOrder;

  const DrinksMenuScreen({super.key, this.existingOrder});

  @override
  State<DrinksMenuScreen> createState() => _DrinksMenuScreenState();
}

class _DrinksMenuScreenState extends State<DrinksMenuScreen> {
  final Map<String, int> _orderItems = {};
  final _orderNameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingOrder != null) {
      final orderData = widget.existingOrder!.data() as Map<String, dynamic>;
      _orderNameController.text = orderData['nombre_orden'] ?? '';
      final List<dynamic> items = orderData['items'] ?? [];
      for (var item in items) {
        _orderItems[item['id']] = item['cantidad'];
      }
    }
  }

  @override
  void dispose() {
    _orderNameController.dispose();
    super.dispose();
  }

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

  Future<void> _updateOrder() async {
    if (_orderNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, asigna un nombre a la orden.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final drinksSnapshot = await FirebaseFirestore.instance.collection('bebidas').get();
      final allDrinks = {for (var doc in drinksSnapshot.docs) doc.id: doc.data()};

      double newTotal = 0;
      final List<Map<String, dynamic>> updatedItems = [];

      for (var entry in _orderItems.entries) {
        final drinkId = entry.key;
        final quantity = entry.value;
        final drinkData = allDrinks[drinkId];

        if (drinkData != null) {
          final price = (drinkData['precio'] as num).toDouble();
          final itemTotal = price * quantity;
          newTotal += itemTotal;
          updatedItems.add({
            'id': drinkId,
            'nombre': drinkData['nombre'],
            'cantidad': quantity,
            'precioUnitario': price,
            'precioTotal': itemTotal,
          });
        }
      }

      await widget.existingOrder!.reference.update({
        'nombre_orden': _orderNameController.text,
        'items': updatedItems,
        'total_orden': newTotal,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden actualizada con éxito')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar la orden: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingOrder != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modificar Orden' : 'Menú de Bebidas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _orderNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Orden',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                final groupedDrinks = groupBy(drinks, (doc) => (doc.data() as Map)['categoria']);

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
                            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
          ),
        ],
      ),
      floatingActionButton: _orderItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : () {
                      if (isEditing) {
                        _updateOrder();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderSummaryScreen(
                              orderItems: _orderItems,
                              orderName: _orderNameController.text,
                            ),
                          ),
                        );
                      }
                    },
              label: Text(isEditing ? 'Guardar Cambios' : 'Ver Orden'),
              icon: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Icon(isEditing ? Icons.save : Icons.shopping_cart),
            )
          : null,
    );
  }
}
