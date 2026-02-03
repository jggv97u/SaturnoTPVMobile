
import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final int points;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.points,
    required this.createdAt,
  });

  /// A "bilingual" factory constructor that can create a Customer instance
  /// from either the old or the new data structure in Firestore.
  factory Customer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Handle "bilingual" fields with grace.
    // Prefers the new field name ('name', 'phone') but falls back to the old one ('nombre', 'telefono').
    final String name = data['name'] ?? data['nombre'] ?? 'Nombre no disponible';
    
    // For the phone number, the new structure saves it with '+52' but the old one doesn't.
    // We normalize it by ensuring it always has the prefix for consistency.
    String phone = data['phone'] ?? data['telefono'] ?? 'Teléfono no disponible';
    if (!phone.startsWith('+') && phone.length == 10) {
      phone = '+52$phone';
    }

    // Points and createdAt are consistent, but we provide defaults.
    final int points = (data['points'] ?? data['puntos'] ?? 0) as int;
    final Timestamp? timestamp = data['createdAt'] as Timestamp?;
    final DateTime createdAt = timestamp?.toDate() ?? DateTime.now();

    return Customer(
      id: doc.id,
      name: name,
      phone: phone,
      points: points,
      createdAt: createdAt,
    );
  }
}
