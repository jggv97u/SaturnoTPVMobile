import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'active_orders_screen.dart';
import 'catalog_management_screen.dart';
import 'customer_management_screen.dart';
import 'expense_screen.dart';
import 'sales_report_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        childAspectRatio: 1.2,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        children: [
          _buildMenuCard(
            context,
            icon: Icons.point_of_sale,
            label: 'Punto de Venta',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ActiveOrdersScreen()),
              );
            },
          ),
           _buildMenuCard(
            context,
            icon: Icons.inventory,
            label: 'Gestionar Catálogo',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CatalogManagementScreen()),
              );
            },
          ),
          _buildMenuCard(
            context,
            icon: Icons.people,
            label: 'Clientes',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CustomerManagementScreen()),
              );
            },
          ),
          _buildMenuCard(
            context,
            icon: Icons.bar_chart,
            label: 'Reportes',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SalesReportScreen()),
              );
            },
          ),
          _buildMenuCard(
            context,
            icon: Icons.receipt_long,
            label: 'Gastos',
            onTap: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExpenseScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
