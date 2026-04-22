import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:saturnotpv/coupon_scanner_screen.dart';
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
  final ValueNotifier<String> _selectedCategory = ValueNotifier('Todas');
  bool _isSaving = false;
  bool _isFreeDrinkCouponApplied = false;
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
         if (item['id'] == 'free-drink-coupon') {
          _isFreeDrinkCouponApplied = true;
        }
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
    _selectedCategory.dispose();
    super.dispose();
  }

  void _addItem(String drinkId) {
    setState(() {
      _orderItems.update(drinkId, (value) => value + 1, ifAbsent: () => 1);
    });
  }

  void _removeItem(String drinkId) {
    setState(() {
      if (_orderItems.containsKey(drinkId) && _orderItems[drinkId]! > 0) {
        setState(() {
           if (_orderItems[drinkId]! > 1) {
            _orderItems.update(drinkId, (value) => value - 1);
          } else {
            _orderItems.remove(drinkId);
            if (drinkId == 'free-drink-coupon') {
              _isFreeDrinkCouponApplied = false;
            }
          }
        });
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

  Future<void> _scanAndProcessCoupon() async {
    if (_isFreeDrinkCouponApplied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya se ha aplicado un cupón a esta orden.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Navigate to the scanner screen and wait for a result
    final couponId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const CouponScannerScreen()),
    );

    if (couponId != null && mounted) {
      await _validateAndApplyCoupon(couponId);
    }
  }

  Future<void> _validateAndApplyCoupon(String couponId) async {
    if (_isFreeDrinkCouponApplied) return;

    setState(() => _isSaving = true);

    try {
      final couponRef = FirebaseFirestore.instance.collection('cupones_bebidas_gratis').doc(couponId);
      final couponDoc = await couponRef.get();

      if (!couponDoc.exists) {
        throw 'Cupón no encontrado.';
      }

      final data = couponDoc.data() as Map<String, dynamic>;

      if (data['estado'] != 'valido') {
        throw 'Este cupón ya fue utilizado o ha sido invalidado.';
      }

      if ((data['fechaExpiracion'] as Timestamp).toDate().isBefore(DateTime.now())) {
        throw 'Este cupón ha expirado.';
      }
      
      await couponRef.update({'estado': 'canjeado', 'fechaCanje': FieldValue.serverTimestamp()});
      
      setState(() {
        _orderItems.update('free-drink-coupon', (value) => value + 1, ifAbsent: () => 1);
        _isFreeDrinkCouponApplied = true;
      });

       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Bebida de cortesía añadida!'), backgroundColor: Colors.green),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
    finally {
      setState(() => _isSaving = false);
    }
  }
  
  Future<void> _updateOrder() async {
    if (_orderNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, asigna un nombre a la orden.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final drinksSnapshot = await FirebaseFirestore.instance.collection('bebidas').get();
      final allDrinks = {for (var doc in drinksSnapshot.docs) doc.id: doc.data()};

      allDrinks['free-drink-coupon'] = {
        'nombre': 'Bebida de Cortesía (Cupón)',
        'precio': 0.0,
        'categoria': 'Especial'
      };

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
        'cliente_nombre': _selectedCustomer?.name,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orden actualizada con éxito')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar la orden: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingOrder != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modificar Orden' : 'Crear Nueva Orden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear Cupón QR',
            onPressed: _scanAndProcessCoupon, // Changed to the new method
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _orderNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Orden',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_long),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: InkWell(
              onTap: _showCustomerSearchDialog,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Cliente',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(_selectedCustomer?.name ?? 'Cliente General'),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bebidas').where('inStock', isEqualTo: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar las bebidas.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No hay bebidas disponibles.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final drinks = snapshot.data!.docs;
                final categories = ['Todas', ...drinks.map((d) => (d.data() as Map<String, dynamic>)['categoria']?.toString() ?? 'Sin categoría').toSet().sorted((a, b) => a.compareTo(b))];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryChips(categories),
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: _selectedCategory,
                        builder: (context, category, child) {
                          var filteredDrinks = (category == 'Todas')
                              ? drinks
                              : drinks.where((d) => ((d.data() as Map<String, dynamic>)['categoria']?.toString() ?? 'Sin categoría') == category).toList();

                          filteredDrinks.sort((a, b) {
                            final aName = (a.data() as Map<String, dynamic>)['nombre'] as String;
                            final bName = (b.data() as Map<String, dynamic>)['nombre'] as String;
                            return aName.toLowerCase().compareTo(bName.toLowerCase());
                          });

                          return _buildDrinksGrid(filteredDrinks);
                        },
                      ),
                    ),
                  ],
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
                              orderName: _orderNameController.text.isNotEmpty ? _orderNameController.text : 'Orden sin nombre',
                              customer: _selectedCustomer,
                            ),
                          ),
                        );
                      }
                    },
              label: Text(isEditing ? 'Guardar Cambios' : 'Ver Orden (${_orderItems.values.sum})'),
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black))
                  : Icon(isEditing ? Icons.save : Icons.shopping_cart),
            )
          : null,
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = categories[index];
            return ValueListenableBuilder<String>(
              valueListenable: _selectedCategory,
              builder: (context, selected, child) {
                return ChoiceChip(
                  label: Text(category),
                  selected: selected == category,
                  onSelected: (isSelected) {
                    if (isSelected) {
                      _selectedCategory.value = category;
                    }
                  },
                  selectedColor: Theme.of(context).colorScheme.secondary,
                  labelStyle: TextStyle(
                    color: selected == category ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                    side: BorderSide(
                      color: selected == category ? Theme.of(context).colorScheme.secondary : Colors.grey[700]!,
                    )
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrinksGrid(List<DocumentSnapshot> drinks) {
    return GridView.builder(
      key: PageStorageKey<String>(_selectedCategory.value),
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 2 / 2.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: drinks.length,
      itemBuilder: (context, index) {
        final drink = drinks[index];
        final drinkId = drink.id;
        final drinkData = drink.data() as Map<String, dynamic>;
        final quantity = _orderItems[drinkId] ?? 0;

        return Card(
          key: ValueKey(drinkId),
          clipBehavior: Clip.antiAlias, 
          child: InkWell(
            onTap: () => _addItem(drinkId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(drinkData['nombre'], textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                         if (drinkId != 'free-drink-coupon')
                          Text('\$${drinkData['precio']}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
                Container(
                  color: Colors.black.withOpacity(0.2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 20, color: Colors.amberAccent),
                        onPressed: () => _removeItem(drinkId),
                        style: IconButton.styleFrom(backgroundColor: Colors.black38),
                      ),
                      Text('$quantity', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add, size: 20, color: Colors.black),
                        onPressed: () => _addItem(drinkId),
                        style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

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
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o teléfono...',
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

                  final allCustomers = snapshot.data!.docs.map((doc) => Customer.fromFirestore(doc)).toList();
                  final filteredCustomers = allCustomers.where((customer) {
                    final nameMatch = customer.name.toLowerCase().contains(_searchQuery);
                    final phoneMatch = customer.phone.contains(_searchQuery);
                    return nameMatch || phoneMatch;
                  }).toList();

                  if (filteredCustomers.isEmpty) {
                    return const Center(child: Text('No se encontraron clientes.'));
                  }

                  filteredCustomers.sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      return ListTile(
                        title: Text(customer.name),
                        subtitle: Text(customer.phone),
                        onTap: () => Navigator.of(context).pop(customer),
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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
