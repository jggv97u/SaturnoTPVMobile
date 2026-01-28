import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/customer.dart'; // Importamos nuestro modelo
import 'add_customer_screen.dart'; // Importamos la futura pantalla de registro

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Clientes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Apuntamos al stream de la colección 'clientes'
        stream: FirebaseFirestore.instance.collection('clientes').orderBy('nombre').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar los clientes.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No hay clientes registrados.\n\nPresiona el botón + para añadir el primero.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          // Si hay datos, construimos la lista
          return ListView( // Usamos ListView en lugar de ListView.builder para añadir un buscador más tarde
            padding: const EdgeInsets.all(8.0),
            children: snapshot.data!.docs.map((doc) {
              final customer = Customer.fromFirestore(doc);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(customer.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(customer.telefono),
                  trailing: Text('${customer.puntos} pts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                  onTap: () {
                    // TODO: Implementar edición o vista detallada del cliente
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navegamos a la pantalla para añadir un nuevo cliente
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddCustomerScreen()),
          );
        },
        tooltip: 'Añadir Cliente',
        child: const Icon(Icons.add),
      ),
    );
  }
}
