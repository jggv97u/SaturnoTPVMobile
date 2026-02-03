import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomerProfileScreen extends StatefulWidget {
  // This allows receiving data from the creation screen in the future,
  // but we will ignore it for now to focus on existing users.
  final Map<String, dynamic>? initialData;

  const CustomerProfileScreen({super.key, this.initialData});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DocumentSnapshot?>? _customerFuture;

  @override
  void initState() {
    super.initState();
    // Only fetch data if there's an authenticated user
    final user = _auth.currentUser;
    if (user != null) {
      _customerFuture = _fetchCustomerProfile(user);
    }
  }

  /// Hybrid fetch strategy to find a customer profile.
  Future<DocumentSnapshot?> _fetchCustomerProfile(User user) async {
    final phoneNumber = user.phoneNumber;
    if (phoneNumber == null) return null;

    // --- STRATEGY 1: Find OLD users by querying the 'telefono' field ---
    // This is the priority now, as per your request.
    final oldUserQuery = await _firestore
        .collection('clientes')
        .where('telefono', isEqualTo: phoneNumber.substring(3)) // Remove +52
        .limit(1)
        .get();

    if (oldUserQuery.docs.isNotEmpty) {
      // Found an existing user with the old data structure
      return oldUserQuery.docs.first;
    }

    // --- STRATEGY 2: Find NEW users by Document ID ---
    // If no old user was found, check if it's a new user whose ID is their phone number.
    final newUserDoc = await _firestore.collection('clientes').doc(phoneNumber).get();

    if (newUserDoc.exists) {
      // Found a user with the new data structure
      return newUserDoc;
    }
    
    // If neither strategy found a document, return null
    return null;
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      // Go back to the customer login portal after signing out.
      context.go('/customer-portal');
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there's no logged-in user, show an error.
    if (_customerFuture == null) {
      return _buildErrorScaffold('Error: No se pudo verificar tu sesión.');
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Tu Perfil Saturno'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot?>(
        future: _customerFuture,
        builder: (context, snapshot) {
          // While waiting for data, show a loading indicator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
          }

          // If there was an error or no document was found, show the error view
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return _buildNotFoundView();
          }

          final customerData = snapshot.data!.data() as Map<String, dynamic>;

          // If data is found, build the profile view
          return _buildProfileView(customerData);
        },
      ),
    );
  }

  // --- UI Building Methods ---

  Widget _buildProfileView(Map<String, dynamic> customerData) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildWelcomeCard(customerData),
        const SizedBox(height: 20),
        _buildLoyaltyCard(customerData),
        const SizedBox(height: 20),
        _buildStatsCard(customerData),
      ],
    );
  }

  Scaffold _buildErrorScaffold(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(message, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _logout, child: const Text('Volver al inicio')),
        ]),
      ),
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              '¡Ups! No pudimos encontrar tu perfil.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Parece que no estás registrado. Si crees que es un error, por favor, contacta a soporte.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _logout, child: const Text('Volver al inicio')),
          ],
        ),
      ),
    );
  }

  // --- "Bilingual" Data Getters ---

  String _getName(Map<String, dynamic> data) => data['name'] ?? data['nombre'] ?? 'Cliente';
  int _getPoints(Map<String, dynamic> data) => (data['points'] ?? data['puntos'] ?? 0) as int;

  Widget _buildWelcomeCard(Map<String, dynamic> data) {
    final name = _getName(data);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¡Hola, $name!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Qué bueno verte de nuevo.', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard(Map<String, dynamic> data) {
    final points = _getPoints(data);
    const pointsNeeded = 7;
    final progress = (points % pointsNeeded) / pointsNeeded;
    final drinksEarned = points ~/ pointsNeeded;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Progreso de Lealtad', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade700,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                  ),
                ),
                Text('${points % pointsNeeded} / $pointsNeeded', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              drinksEarned > 0
                  ? '¡Felicidades! Tienes $drinksEarned bebida(s) gratis para redimir.'
                  : 'Te faltan ${pointsNeeded - (points % pointsNeeded)} para tu próxima bebida gratis.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> data) {
    final favoriteDrink = data['favoriteDrink'] ?? 'Aún no registrada';
    final lastDrink = data['lastDrink'] ?? 'Ninguna';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tus Preferencias', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.redAccent),
              title: const Text('Tu Bebida Favorita'),
              subtitle: Text(favoriteDrink, style: const TextStyle(fontSize: 16, color: Colors.white70)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.coffee, color: Colors.brown),
              title: const Text('Tu Última Bebida'),
              subtitle: Text(lastDrink, style: const TextStyle(fontSize: 16, color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
