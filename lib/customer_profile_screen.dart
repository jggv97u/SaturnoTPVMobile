import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class LoyaltyLevel {
  final String name;
  final Widget icon;

  const LoyaltyLevel({required this.name, required this.icon});

  factory LoyaltyLevel.fromVisits(int visits) {
    if (visits >= 50) {
      return const LoyaltyLevel(
        name: 'Comandante Galáctico',
        icon: Text('🏆', style: TextStyle(fontSize: 20)),
      );
    } else if (visits >= 15) {
      return const LoyaltyLevel(
        name: 'Navegante Estelar',
        icon: Text('🛰️', style: TextStyle(fontSize: 20)),
      );
    } else {
      return const LoyaltyLevel(
        name: 'Explorador Cósmico',
        icon: Text('🚀', style: TextStyle(fontSize: 20)),
      );
    }
  }
}

class Achievement {
  final String name;
  final String icon;
  final bool isUnlocked;

  const Achievement({
    required this.name,
    required this.icon,
    this.isUnlocked = false,
  });
}

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<DocumentSnapshot>? _customerStream;
  Stream<QuerySnapshot>? _couponsStream;
  DocumentReference? _customerDocRef;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      _initializeCustomerData(user);
    }
  }

  void _initializeCustomerData(User user) async {
    _customerDocRef = await _getCustomerDocRef(user);
    if (_customerDocRef != null) {
      setState(() {
        _customerStream = _customerDocRef!.snapshots();
        _couponsStream = _firestore
            .collection('cupones_bebidas_gratis')
            .where('clienteId', isEqualTo: _customerDocRef!.id)
            .where('estado', isEqualTo: 'valido')
            .where('fechaExpiracion', isGreaterThan: Timestamp.now())
            .snapshots();
      });
       _customerStream!.listen(_handleCustomerDataChanges);
    }
  }

  Future<DocumentReference?> _getCustomerDocRef(User user) async {
    final phoneNumber = user.phoneNumber;
    if (phoneNumber == null) return null;

    final oldUserQuery = await _firestore
        .collection('clientes')
        .where('telefono', isEqualTo: phoneNumber.substring(3))
        .limit(1)
        .get();

    if (oldUserQuery.docs.isNotEmpty) {
      return oldUserQuery.docs.first.reference;
    }

    final newUserDoc = _firestore.collection('clientes').doc(phoneNumber);
    final docSnapshot = await newUserDoc.get();
    return docSnapshot.exists ? newUserDoc : null;
  }

  void _handleCustomerDataChanges(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return;
    _handlePointsToCouponConversion(snapshot);
    _handleGalacticCommanderReward(snapshot);
  }

 void _handlePointsToCouponConversion(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    final points = (data['points'] ?? data['puntos'] ?? 0) as int;
    const pointsPerCoupon = 7;

    if (points >= pointsPerCoupon) {
      final couponsToGenerate = points ~/ pointsPerCoupon;
      final remainingPoints = points % pointsPerCoupon;

      for (int i = 0; i < couponsToGenerate; i++) {
        _generateFreeDrinkCoupon(snapshot.reference, 'Canje de Puntos');
      }

      snapshot.reference.update({'points': remainingPoints, 'puntos': remainingPoints});
    }
  }

  void _handleGalacticCommanderReward(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    final visits = (data['visits'] ?? 0) as int;
    final hasClaimedReward = (data['claimedCommanderReward'] ?? false) as bool;

    if (visits >= 50 && !hasClaimedReward) {
      _generateFreeDrinkCoupon(snapshot.reference, 'Recompensa Comandante');
      snapshot.reference.update({'claimedCommanderReward': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Felicidades, Comandante! Has ganado una bebida gratis.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _generateFreeDrinkCoupon(DocumentReference customerRef, String origin) async {
    final newCouponRef = _firestore.collection('cupones_bebidas_gratis').doc();
    final expirationDate = DateTime.now().add(const Duration(days: 7));

    await newCouponRef.set({
      'clienteId': customerRef.id,
      'codigo': 'SAT-${newCouponRef.id.substring(0, 8).toUpperCase()}',
      'fechaCreacion': FieldValue.serverTimestamp(),
      'fechaExpiracion': Timestamp.fromDate(expirationDate),
      'estado': 'valido',
      'origen': origin,
    });
  }


  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) context.go('/customer-portal');
  }

  @override
  Widget build(BuildContext context) {
    if (_customerStream == null) {
       return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: _auth.currentUser != null
              ? const CircularProgressIndicator(color: Color(0xFFFFD700)) 
              : _buildErrorScaffold('Error: Sesión no válida.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Tu Perfil Saturno'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Cerrar Sesión', onPressed: _logout),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _customerStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildNotFoundView();
          }
          final customerData = snapshot.data!.data() as Map<String, dynamic>;
          return _buildProfileView(customerData);
        },
      ),
    );
  }

  Widget _buildProfileView(Map<String, dynamic> customerData) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildWelcomeCard(customerData),
        const SizedBox(height: 20),
        _buildPointsCard(customerData),
        const SizedBox(height: 20),
        _buildCouponsSection(),
        const SizedBox(height: 20),
        _buildAchievementsCard(customerData),
        const SizedBox(height: 20),
        _buildStatsCard(customerData),
      ],
    );
  }

   Widget _buildCouponsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mis Cupones de Bebida Gratis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _couponsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text('No tienes cupones de bebidas gratis... ¡aún!', style: TextStyle(color: Colors.white70));
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var coupon = snapshot.data!.docs[index];
                return _buildCouponCard(coupon.data() as Map<String, dynamic>);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> couponData) {
    final code = couponData['codigo'] ?? 'N/A';
    final expiration = (couponData['fechaExpiracion'] as Timestamp).toDate();
    final formattedExpiration = DateFormat('dd/MM/yyyy, hh:mm a').format(expiration);

    return Card(
      color: const Color(0xFF2E2E2E),
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('¡BEBIDA GRATIS!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
            const SizedBox(height: 15),
            const Icon(Icons.coffee, size: 50, color: Color(0xFFFFD700)),
            const SizedBox(height: 15),
            Text('Usa este código en caja:', style: TextStyle(fontSize: 16, color: Colors.white70)),
            const SizedBox(height: 5),
            Text(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 15),
            Text('Válido hasta: $formattedExpiration', style: const TextStyle(fontSize: 14, color: Colors.amber)),
          ],
        ),
      )
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
              'Parece que no estás registrado. Si crees que es un error, contacta a soporte.',
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

  String _getName(Map<String, dynamic> data) => data['name'] ?? data['nombre'] ?? 'Cliente';
  int _getPoints(Map<String, dynamic> data) => (data['points'] ?? data['puntos'] ?? 0) as int;
  int _getVisits(Map<String, dynamic> data) => (data['visits'] ?? 0) as int;

  LoyaltyLevel _getLoyaltyLevel(Map<String, dynamic> data) {
    final visits = _getVisits(data);
    return LoyaltyLevel.fromVisits(visits);
  }

  List<Achievement> _getAchievements(Map<String, dynamic> data) {
    final Set<String> unlocked = Set<String>.from(data['achievements'] ?? []);
    return [
      Achievement(name: 'Explorador de Sabores', icon: '🌍', isUnlocked: unlocked.contains('flavor_explorer')),
      Achievement(name: 'Frecuencia Estelar', icon: '⭐', isUnlocked: unlocked.contains('star_frequency')),
      Achievement(name: 'Madrugador', icon: '☀️', isUnlocked: unlocked.contains('early_bird')),
    ];
  }

  Widget _buildWelcomeCard(Map<String, dynamic> data) {
    final name = _getName(data);
    final level = _getLoyaltyLevel(data);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text('¡Hola, $name!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                Chip(avatar: level.icon, label: Text(level.name), backgroundColor: Colors.blueGrey[700], labelStyle: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Qué bueno verte de nuevo.', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

 Widget _buildPointsCard(Map<String, dynamic> data) {
    final points = _getPoints(data);
    const pointsNeeded = 7;
    final progress = points / pointsNeeded;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Progreso para Próxima Bebida', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                Text('$points / $pointsNeeded', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              'Acumula 7 puntos para ganar una bebida gratis.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsCard(Map<String, dynamic> data) {
    final achievements = _getAchievements(data);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Logros Cósmicos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: achievements.map((ach) {
                return Column(
                  children: [
                    Opacity(
                      opacity: ach.isUnlocked ? 1.0 : 0.4,
                      child: Text(ach.icon, style: const TextStyle(fontSize: 40)),
                    ),
                    const SizedBox(height: 4),
                    Text(ach.name, style: TextStyle(fontSize: 12, color: ach.isUnlocked ? Colors.white : Colors.grey[600]), textAlign: TextAlign.center),
                  ],
                );
              }).toList(),
            ),
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
