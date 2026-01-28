import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/customer.dart';
import 'order_summary_screen.dart';

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
  Customer? _selectedCustomer;

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
      if (orderData.containsKey('cliente_id') && orderData['cliente_id'] != null) {
        _loadCustomer(orderData['cliente_id']);
      }
    }
  }

  Future<void> _loadCustomer(String customerId) async {
    final doc = await FirebaseFirestore.instance.collection('clientes').doc(customerId).get();
    if (doc.exists) {
      setState(() {
        _selectedCustomer = Customer.fromFirestore(doc);
      });
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

  Future<void> _showCustomerSearchDialog() async {
    final selected = await showDialog<Customer>(
      context: context,
      builder: (context) => const CustomerSearchDialog(),
    );

    if (selected != null) {
      setState(() {
        _selectedCustomer = selected;
      });
    }
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
        'cliente_id': _selectedCustomer?.id,
        'cliente_nombre': _selectedCustomer?.nombre,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _orderNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Orden',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // Customer Selector UI
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: InkWell(
              onTap: _showCustomerSearchDialog,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Cliente',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(_selectedCustomer?.nombre ?? 'Seleccionar un cliente'),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bebidas')
                  .where('inStock', isEqualTo: true)
                  .orderBy('nombre')
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
                final sortedEntries = groupedDrinks.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key));

                return ListView(
                  children: sortedEntries.map((entry) {
                    final sortedDrinks = entry.value..sort((a, b) {
                      final aName = (a.data() as Map<String, dynamic>)['nombre'] as String;
                      final bName = (b.data() as Map<String, dynamic>)['nombre'] as String;
                      return aName.compareTo(bName);
                    });

                    return Column(
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
                              customer: _selectedCustomer,
                            ),
                          ),
                        );
                      }
                    },
              label: Text(isEditing ? 'Guardar Cambios' : 'Ver Orden'),
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black))
                  : Icon(isEditing ? Icons.save : Icons.shopping_cart),
            )
          : null,
    );
  }
}

// Dialog for searching customers
class CustomerSearchDialog extends StatefulWidget {
  const CustomerSearchDialog({super.key});

  @override
  State<CustomerSearchDialog> createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<CustomerSearchDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar Cliente'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('clientes').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  var filteredDocs = snapshot.data!.docs.where((doc) {
                    final customerName = (doc.data() as Map<String, dynamic>)['nombre'].toString().toLowerCase();
                    return customerName.contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(child: Text('No se encontraron clientes.'));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final customer = Customer.fromFirestore(filteredDocs[index]);
                      return ListTile(
                        title: Text(customer.nombre),
                        subtitle: Text(customer.telefono),
                        onTap: () {
                          Navigator.of(context).pop(customer);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
