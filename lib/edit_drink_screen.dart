import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditDrinkScreen extends StatefulWidget {
  final DocumentSnapshot? drinkDoc;

  const EditDrinkScreen({super.key, this.drinkDoc});

  @override
  State<EditDrinkScreen> createState() => _EditDrinkScreenState();
}

class _EditDrinkScreenState extends State<EditDrinkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _inStock = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.drinkDoc != null) {
      final data = widget.drinkDoc!.data() as Map<String, dynamic>;
      _nameController.text = data['nombre'] ?? '';
      _priceController.text = (data['precio'] ?? 0.0).toString();
      _costController.text = (data['costo'] ?? 0.0).toString();
      _categoryController.text = data['categoria'] ?? '';
      _inStock = data['inStock'] ?? true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveDrink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final nombre = _nameController.text;
    final precio = double.tryParse(_priceController.text);
    final costo = double.tryParse(_costController.text);
    final categoria = _categoryController.text;

    if (precio == null || costo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precio y costo deben ser números válidos.')),
      );
      setState(() => _isSaving = false);
      return;
    }

    final drinkData = {
      'nombre': nombre,
      'precio': precio,
      'costo': costo,
      'categoria': categoria,
      'inStock': _inStock,
    };

    try {
      if (widget.drinkDoc == null) {
        await FirebaseFirestore.instance.collection('bebidas').add(drinkData);
      } else {
        await widget.drinkDoc!.reference.update(drinkData);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Bebida guardada con éxito!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la bebida: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.drinkDoc == null ? 'Añadir Bebida' : 'Editar Bebida'),
        actions: [
          if (!_isSaving)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveDrink,
              tooltip: 'Guardar',
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Bebida',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_cafe),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'El nombre no puede estar vacío' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'La categoría no puede estar vacía' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio de Venta',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.monetization_on),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Ingresa un precio';
                        if (double.tryParse(value) == null) return 'Ingresa un número válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _costController,
                      decoration: const InputDecoration(
                        labelText: 'Costo de Producción',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.money_off),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Ingresa un número válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text('Disponible en el menú'),
                      value: _inStock,
                      onChanged: (bool value) {
                        setState(() {
                          _inStock = value;
                        });
                      },
                      secondary: _inStock ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.cancel, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _saveDrink,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.save_alt),
                      label: Text(widget.drinkDoc == null ? 'Añadir al Catálogo' : 'Guardar Cambios'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
