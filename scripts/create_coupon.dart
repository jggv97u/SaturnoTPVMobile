
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/firebase_options.dart'; // Assuming the script is run from the project root

void main() async {
  print('Initializing Firebase...');
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Firebase Initialized.');

  final db = FirebaseFirestore.instance;

  // --- Coupon Data ---
  final customerId = '+525610725347';
  final customerName = 'Gaby Ortiz';
  final discountValue = 25.0;
  final description = 'Descuento de \$${discountValue.toStringAsFixed(2)} (Prueba)';
  // Set expiry date 30 days from now
  final expiryDate = Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));

  print('Creating coupon for: $customerName');

  // --- Create the coupon document ---
  try {
    await db.collection('cupones').add({
      'cliente_id': customerId,
      'cliente_nombre': customerName,
      'descripcion': description,
      'valor': discountValue,
      'fecha_creacion': FieldValue.serverTimestamp(),
      'vigente_hasta': expiryDate,
      'canjeado': false,
    });

    print('--------------------------------------------------');
    print('✅ Cupón de prueba creado exitosamente para $customerName.');
    print('--------------------------------------------------');

  } catch (e) {
    print('Error creating coupon: \$e');
  }
}
