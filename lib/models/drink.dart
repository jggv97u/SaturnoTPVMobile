
import 'package:cloud_firestore/cloud_firestore.dart';

class Drink {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool inStock;
  final String category;

  Drink({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.inStock,
    required this.category,
  });

  factory Drink.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Drink(
      id: doc.id,
      name: data['name'] ?? 'Nombre no disponible',
      description: data['description'] ?? 'Descripción no disponible.',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'] ?? 'https://firebasestorage.googleapis.com/v0/b/saturnotrcventasdb.appspot.com/o/drink_placeholder.png?alt=media&token=a72d3b95-5c5c-4f5a-8b1a-9e9b0b4e4b6d', // Placeholder image
      inStock: data['inStock'] ?? false,
      category: data['category'] ?? 'General',
    );
  }
}
