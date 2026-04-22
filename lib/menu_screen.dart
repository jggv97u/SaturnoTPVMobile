
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

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
            .orderBy('nombre')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No hay bebidas en el menú en este momento.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final bebidas = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: bebidas.length,
            itemBuilder: (context, index) {
              final bebida = bebidas[index].data() as Map<String, dynamic>;
              final String nombre = bebida['nombre'] ?? 'Bebida sin nombre';
              final String descripcion = bebida['descripcion'] ?? '';
              final double precio = (bebida['precio'] ?? 0.0).toDouble();
              final bool disponible = bebida['disponible'] ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              nombre,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              disponible ? 'Disponible' : 'Agotado',
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor:
                                disponible ? Colors.green : Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (descripcion.isNotEmpty)
                        Text(
                          descripcion,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '\$${precio.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
