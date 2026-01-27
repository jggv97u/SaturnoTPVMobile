import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogManagementScreen extends StatefulWidget {
  const CatalogManagementScreen({super.key});

  @override
  State<CatalogManagementScreen> createState() => _CatalogManagementScreenState();
}

class _CatalogManagementScreenState extends State<CatalogManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Función de parseo robusta para aceptar comas y puntos
  double? _parseLenient(String value) {
    try {
      // Reemplaza comas por puntos para unificar el separador decimal
      final normalizedValue = value.replaceAll(',', '.');
      return double.parse(normalizedValue);
    } catch (e) {
      return null; // Retorna null si el parseo falla
    }
  }

  Future<void> _showProductDialog({DocumentSnapshot? product}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController();
    final categoryController = TextEditingController();

    bool isEditing = product != null;
    if (isEditing) {
      final data = product.data() as Map<String, dynamic>;
      nameController.text = data['nombre'] ?? '';
      priceController.text = (data['precio'] ?? 0.0).toString();
      costController.text = (data.containsKey('costo') ? data['costo'] : 0.0).toString();
      categoryController.text = data['categoria'] ?? '';
    } else {
      priceController.text = '0.0';
      costController.text = '0.0';
    }

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Producto' : 'Añadir Producto'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                  ),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Precio'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => _parseLenient(value!) == null ? 'Número inválido' : null,
                  ),
                  TextFormField(
                    controller: costController,
                    decoration: const InputDecoration(labelText: 'Costo'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => _parseLenient(value!) == null ? 'Número inválido' : null,
                  ),
                  TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final price = _parseLenient(priceController.text);
                    final cost = _parseLenient(costController.text);

                    if (price == null || cost == null) {
                      // Esto no debería pasar gracias al validador, pero es una doble seguridad
                      throw Exception('El formato del número no es válido a pesar de la validación.');
                    }

                    final data = {
                      'nombre': nameController.text,
                      'precio': price,
                      'costo': cost,
                      'categoria': categoryController.text,
                    };

                    if (isEditing) {
                      await _firestore.collection('bebidas').doc(product.id).update(data);
                    } else {
                      await _firestore.collection('bebidas').add(data);
                    }
                    Navigator.of(context).pop();
                  } catch (e, s) {
                    // **SISTEMA DE DIAGNÓSTICO AVANZADO**
                    // 1. Imprime el error real en la consola del desarrollador
                    developer.log(
                      'Error al guardar el producto.',
                      name: 'CatalogManagement',
                      error: e,
                      stackTrace: s,
                    );

                    // 2. Muestra un mensaje honesto al usuario
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error inesperado. Revisa la consola (F12) para detalles.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProduct(String productId) async {
    // ... (código de eliminación sin cambios)
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirmar Eliminación'),
            content: const Text('¿Estás seguro de que quieres eliminar este producto?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  await _firestore.collection('bebidas').doc(productId).delete();
                  Navigator.of(context).pop();
                },
                child: const Text('Eliminar'),
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Catálogo'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('bebidas').orderBy('categoria').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay productos en el catálogo.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final product = snapshot.data!.docs[index];
              final data = product.data() as Map<String, dynamic>;
              final cost = (data['costo'] ?? 0.0).toStringAsFixed(2);
              final price = (data['precio'] ?? 0.0).toStringAsFixed(2);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(data['nombre'] ?? 'Sin nombre'),
                  subtitle: Text('${data['categoria']} - Precio: \$$price - Costo: \$$cost'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showProductDialog(product: product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteProduct(product.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        tooltip: 'Añadir Producto',
        child: const Icon(Icons.add),
      ),
    );
  }
}
