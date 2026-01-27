import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'admin_panel_screen.dart';
import 'drinks_menu_screen.dart';
import 'order_detail_screen.dart';
import 'expense_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data()!['isAdmin'] == true) {
        if (mounted) {
          setState(() {
            _isAdmin = true;
          });
        }
      }
    }
  }

  Future<void> _showPinDialog(BuildContext context) async {
    final pinController = TextEditingController();
    const String adminPin = '1234'; // This should be more secure in a real app

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Acceso de Administrador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Por favor, ingresa el PIN para continuar.'),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  counterText: "",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Aceptar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (pinController.text == adminPin) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminPanelScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN incorrecto.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/logo.svg',
              height: 30,
            ),
            const SizedBox(width: 10),
            const Text('Saturno TPV'),
          ],
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Panel de Administración',
              onPressed: () {
                _showPinDialog(context);
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pedidos').where('activa', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar las órdenes.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay órdenes activas.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final order = snapshot.data!.docs[index];
              final orderData = order.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(orderData['nombre_orden'] ?? 'Orden sin nombre'),
                  subtitle: Text(
                    'Total: \$${(orderData['total_orden'] ?? 0.0).toStringAsFixed(2)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailScreen(order: order),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isAdmin)
            FloatingActionButton.small(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExpenseScreen()),
                );
              },
              tooltip: 'Registrar Gasto',
              heroTag: 'expense_fab',
              child: const Icon(Icons.note_add_outlined),
            ),
          if (_isAdmin)
            const SizedBox(height: 16),
          FloatingActionButton.large(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DrinksMenuScreen()),
              );
            },
            tooltip: 'Nueva Orden',
            heroTag: 'order_fab',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
