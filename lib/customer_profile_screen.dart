import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'models/customer.dart'; // Import the unified Customer model

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

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<Customer>? _customerStream;
  Stream<QuerySnapshot>? _couponsStream;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      _initializeCustomerData(user);
    }
  }

  void _initializeCustomerData(User user) async {
    final customerDocRef = await _getCustomerDocRef(user);
    if (customerDocRef != null) {
      setState(() {
        // Use a stream of the unified Customer model
        _customerStream = customerDocRef.snapshots().map((doc) => Customer.fromFirestore(doc));
        
        _couponsStream = _firestore
            .collection('cupones_bebidas_gratis')
            .where('clienteId', isEqualTo: customerDocRef.id)
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

    final querySnapshot = await _firestore
        .collection('clientes')
        .where('phone', isEqualTo: phoneNumber) // Search by the full phone number
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.reference;
    } else {
      // Fallback for old data structure
      final oldUserQuery = await _firestore
        .collection('clientes')
        .where('telefono', isEqualTo: phoneNumber.substring(3))
        .limit(1)
        .get();
       if (oldUserQuery.docs.isNotEmpty) {
         return oldUserQuery.docs.first.reference;
       }
    }
    return null; // No customer found
  }

  void _handleCustomerDataChanges(Customer customer) {
    if (!mounted) return;
    _handlePointsToCouponConversion(customer);
    _handleGalacticCommanderReward(customer);
  }

  void _handlePointsToCouponConversion(Customer customer) {
    const pointsPerCoupon = 7;
    if (customer.puntos >= pointsPerCoupon) {
      final couponsToGenerate = customer.puntos ~/ pointsPerCoupon;
      final remainingPoints = customer.puntos % pointsPerCoupon;

      for (int i = 0; i < couponsToGenerate; i++) {
        _generateFreeDrinkCoupon(customer.id, 'Canje de Puntos');
      }

      _firestore.collection('clientes').doc(customer.id).update({'puntos': remainingPoints});
    }
  }

  void _handleGalacticCommanderReward(Customer customer) {
    final hasClaimedReward = (customer.visitas >= 50) && (customer.ultimaVisita != null); // Simple logic
    //This should query a specific field in firestore, but we simplify for now

    if (customer.visitas >= 50 && !hasClaimedReward) {
      _generateFreeDrinkCoupon(customer.id, 'Recompensa Comandante');
       _firestore.collection('clientes').doc(customer.id).update({'claimedCommanderReward': true});

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

  Future<void> _generateFreeDrinkCoupon(String customerId, String origin) async {
    final newCouponRef = _firestore.collection('cupones_bebidas_gratis').doc();
    final expirationDate = DateTime.now().add(const Duration(days: 7));

    await newCouponRef.set({
      'clienteId': customerId,
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Tu Perfil Saturno'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Cerrar Sesión', onPressed: _logout),
        ],
      ),
      body: StreamBuilder<Customer>(
        stream: _customerStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildNotFoundView(); // Handle error or no data case
          }
          final customer = snapshot.data!;
          return _buildProfileView(customer);
        },
      ),
    );
  }
  
    Widget _buildProfileView(Customer customer) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildWelcomeCard(customer),
        const SizedBox(height: 20),
        _buildPointsCard(customer),
        const SizedBox(height: 20),
        _buildCouponsSection(),
        const SizedBox(height: 20),
        _buildStatsCard(customer),
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
                return _buildCouponCard(coupon);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCouponCard(DocumentSnapshot coupon) {
    final couponData = coupon.data() as Map<String, dynamic>;
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: coupon.id,
                version: QrVersions.auto,
                size: 180.0,
              ),
            ),
            const SizedBox(height: 15),
            const Text('Presenta este QR al barista para canjear', style: TextStyle(fontSize: 16, color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 15),
            Text('Válido hasta: $formattedExpiration', style: const TextStyle(fontSize: 14, color: Colors.amber)),
          ],
        ),
      )
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
              'Parece que tu número no está registrado. Si crees que es un error, contacta a soporte.',
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

  Widget _buildWelcomeCard(Customer customer) {
    final level = LoyaltyLevel.fromVisits(customer.visitas);
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
                  child: Text('¡Hola, ${customer.name}!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                Chip(avatar: level.icon, label: Text(level.name), backgroundColor: Colors.blueGrey[700], labelStyle: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
             if (customer.ultimaVisita != null)
              Text('Última visita: ${DateFormat.yMMMd('es_MX').add_jm().format(customer.ultimaVisita!)}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard(Customer customer) {
    const pointsNeeded = 7;
    final progress = customer.puntos / pointsNeeded;

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
                Text('${customer.puntos} / $pointsNeeded', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              'Acumula $pointsNeeded puntos para ganar una bebida gratis.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatsCard(Customer customer) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estadísticas de Lealtad', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ListTile(
              leading: const Icon(Icons.star_rate_rounded, color: Colors.amber),
              title: const Text('Puntos Acumulados'),
              trailing: Text(customer.puntos.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.local_bar_rounded, color: Colors.lightBlueAccent),
              title: const Text('Visitas Totales'),
              trailing: Text(customer.visitas.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

