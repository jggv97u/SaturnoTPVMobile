import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/customer.dart'; // Corrected import path

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Clientes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchTerm = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                labelText: 'Buscar Cliente',
                hintText: 'Nombre o teléfono...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Query without sorting to fetch all documents
              stream: FirebaseFirestore.instance.collection('clientes').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Error al cargar los clientes.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay clientes registrados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                // Use the bilingual model and sort in-app
                List<Customer> customers = snapshot.data!.docs
                    .map((doc) => Customer.fromFirestore(doc))
                    .toList();
                
                // Sort alphabetically by name
                customers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                // Filter based on search term
                final filteredCustomers = customers.where((customer) {
                  final nameMatch = customer.name.toLowerCase().contains(_searchTerm);
                  final phoneMatch = customer.phone.contains(_searchTerm);
                  return nameMatch || phoneMatch;
                }).toList();

                if (filteredCustomers.isEmpty) {
                   return const Center(
                    child: Text(
                      'No se encontraron clientes con ese criterio de búsqueda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = filteredCustomers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 6.0, horizontal: 8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(customer.name.isNotEmpty ? customer.name[0] : '?', style: const TextStyle(color: Colors.white)),
                        ),
                        // Use the unified fields from the model
                        title: Text(customer.name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(customer.phone),
                        trailing: Text('${customer.points} pts',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary)),
                        onTap: () {
                          // Future: Implement edit or detailed view
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
