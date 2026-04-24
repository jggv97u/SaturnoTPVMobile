import 'package:flutter/material.dart';
import 'customer_profile_screen.dart';

class CustomerPortalHostScreen extends StatefulWidget {
  const CustomerPortalHostScreen({super.key});

  @override
  State<CustomerPortalHostScreen> createState() => _CustomerPortalHostScreenState();
}

class _CustomerPortalHostScreenState extends State<CustomerPortalHostScreen> {
  @override
  Widget build(BuildContext context) {
    // Se restaura la pantalla para mostrar únicamente el perfil del cliente.
    return const CustomerProfileScreen();
  }
}
