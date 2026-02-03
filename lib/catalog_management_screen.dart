import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_drink_screen.dart';

class CatalogManagementScreen extends StatefulWidget {
  const CatalogManagementScreen({super.key});

  @override
  State<CatalogManagementScreen> createState() => _CatalogManagementScreenState();
}

class _CatalogManagementScreenState extends State<CatalogManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _deleteDrink(String docId, String drinkName) async {
    final bool? confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar "$drinkName" del catálogo? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await _firestore.collection('bebidas').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$drinkName" fue eliminado.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar la bebida: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleInStock(String docId, bool currentStatus) async {
    try {
      await _firestore.collection('bebidas').doc(docId).update({'inStock': !currentStatus});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar la disponibilidad: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Catálogo'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('bebidas').orderBy('nombre').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar el catálogo.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No hay bebidas en el catálogo.\n\nPresiona el botón + para añadir una.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final nombre = data['nombre'] ?? 'Bebida sin nombre';
              final categoria = data['categoria'] ?? 'Sin categoría';
              final precio = (data['precio'] ?? 0.0).toDouble();
              final inStock = data['inStock'] ?? true;

              return Card(
                 margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                 elevation: inStock ? 2.0 : 0.5,
                 child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  leading: Switch(
                    value: inStock,
                    onChanged: (value) => _toggleInStock(doc.id, inStock),
                    activeColor: Colors.green,
                  ),
                  title: Text(
                    nombre,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: inStock ? null : Colors.grey,
                      decoration: inStock ? TextDecoration.none : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    '$categoria | Precio: \$${precio.toStringAsFixed(2)}',
                    style: TextStyle(color: inStock ? Colors.black54 : Colors.grey),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditDrinkScreen(drinkDoc: doc),
                          ),
                        );
                      } else if (value == 'delete') {
                        _deleteDrink(doc.id, nombre);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit, color: Colors.amber),
                          title: Text('Editar'),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.redAccent),
                          title: Text('Eliminar'),
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
      floatingActionButton: FloatingActionButton.large(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EditDrinkScreen()),
          );
        },
        tooltip: 'Añadir Bebida',
        child: const Icon(Icons.add),
      ),
    );
  }
}
