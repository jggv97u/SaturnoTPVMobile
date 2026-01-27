import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  final List<String> _expenseCategories = [
    'Rentas y Servicios',
    'Losa',
    'Transporte',
    'Otros Gastos',
  ];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
       locale: const Locale('es', 'MX'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      final description = _descriptionController.text;
      final amount = double.tryParse(_amountController.text);
      final category = _selectedCategory;

      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, introduce un monto válido.')),
        );
        return;
      }

      try {
        await FirebaseFirestore.instance.collection('gastos').add({
          'descripcion': description,
          'monto': amount,
          'categoria': category,
          'fecha': Timestamp.fromDate(_selectedDate),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gasto guardado con éxito.')),
        );

        // Clear the form
        _formKey.currentState!.reset();
        _descriptionController.clear();
        _amountController.clear();
        setState(() {
            _selectedCategory = null;
            _selectedDate = DateTime.now();
        });

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el gasto: $e')),
        );
      }
    }
  }

    @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Nuevo Gasto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Detalles del Gasto',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción del Gasto',
                  hintText: 'Ej: Pago de luz, gasolina, etc.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce una descripción.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce un monto.';
                  }
                  if (double.tryParse(value) == null) {
                     return 'Por favor, introduce un número válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                   prefixIcon: Icon(Icons.category),
                ),
                hint: const Text('Selecciona una categoría'),
                isExpanded: true,
                items: _expenseCategories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                validator: (value) => value == null ? 'Por favor, selecciona una categoría' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3))),
                leading: const Padding(
                  padding: EdgeInsets.only(left: 12.0),
                  child: Icon(Icons.calendar_today),
                ),
                title: Text('Fecha del Gasto: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                icon: const Icon(Icons.save_alt),
                label: const Text('Guardar Gasto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
