import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final int puntos; // Standardized to Spanish
  final int visitas; // Add visits
  final DateTime createdAt;
  final DateTime? ultimaVisita; // Add last visit

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.puntos,
    required this.visitas,
    required this.createdAt,
    this.ultimaVisita,
  });

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    final String name = data['name'] ?? data['nombre'] ?? 'Nombre no disponible';
    
    String phone = data['phone'] ?? data['telefono'] ?? 'Teléfono no disponible';
    if (!phone.startsWith('+') && phone.length == 10) {
      phone = '+52$phone';
    }

    // Prioritize Spanish field names, but fall back for older data
    final int puntos = (data['puntos'] ?? data['points'] ?? 0) as int;
    final int visitas = (data['visitas'] ?? 0) as int;
    
    final Timestamp? createdAtTimestamp = data['createdAt'] as Timestamp?;
    final DateTime createdAt = createdAtTimestamp?.toDate() ?? DateTime.now();
    
    final Timestamp? ultimaVisitaTimestamp = data['ultima_visita'] as Timestamp?;
    final DateTime? ultimaVisita = ultimaVisitaTimestamp?.toDate();

    return Customer(
      id: doc.id,
      name: name,
      phone: phone,
      puntos: puntos,
      visitas: visitas,
      createdAt: createdAt,
      ultimaVisita: ultimaVisita,
    );
  }
}
