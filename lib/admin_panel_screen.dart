import 'package:flutter/material.dart';
import 'catalog_management_screen.dart';
import 'sales_report_screen.dart';
import 'user_management_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildAdminCard(
            context,
            icon: Icons.analytics,
            title: 'Análisis de Rentabilidad',
            subtitle: 'Ingresos, costos, gastos y ganancias.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SalesReportScreen(),
                ),
              );
            },
          ),
          _buildAdminCard(
            context,
            icon: Icons.fastfood,
            title: 'Gestión de Catálogo',
            subtitle: 'Añade, edita o elimina productos del menú.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CatalogManagementScreen(),
                ),
              );
            },
          ),
          _buildAdminCard(
            context,
            icon: Icons.people,
            title: 'Gestión de Cuentas',
            subtitle: 'Administra los roles y permisos de los usuarios.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              );
            },
          ),
          _buildAdminCard(
            context,
            icon: Icons.settings,
            title: 'Configuración General',
            subtitle: 'Ajusta parámetros generales de la aplicación.',
            onTap: () {
              // TODO: Navigate to Settings Screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Próximamente: Configuración General.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ListTile(
        leading: Icon(icon, size: 40, color: Theme.of(context).colorScheme.secondary),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'LemonMilk',
              ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
