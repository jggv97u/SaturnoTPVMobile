import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String nombre;
  final String telefono;
  final int puntos;
  final DateTime fechaRegistro;

  Customer({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.puntos,
    required this.fechaRegistro,
  });

  // Factory constructor para crear un Customer desde un DocumentSnapshot de Firestore
  factory Customer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      telefono: data['telefono'] ?? '',
      puntos: data['puntos'] ?? 0,
      // El Timestamp de Firestore se convierte a DateTime de Dart
      fechaRegistro: (data['fecha_registro'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Método para convertir un Customer a un mapa para guardarlo en Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'puntos': puntos,
      'fecha_registro': Timestamp.fromDate(fechaRegistro),
    };
  }
}
