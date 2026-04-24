import * as admin from "firebase-admin";

// Representa la estructura de una orden en 'historial_compras'
export interface Order {
  completed: boolean;
  userId: string;
  // CORREGIDO: la propiedad es 'nombre', no 'name'.
  items: { nombre: string; cantidad: number; }[]; 
  createdAt: admin.firestore.Timestamp;
}

// Representa la estructura de un documento en la colección 'clientes'
export interface Cliente {
  puntos: number;
  visitas: number;
  ultima_visita?: admin.firestore.Timestamp;
  lastDrink?: string;
  favoriteDrink?: string;
  achievements?: string[];
}

// Este tipo ya no se usa activamente en la lógica principal, 
// pero se mantiene por si se reutiliza en futuros análisis o reportes.
export interface CustomerProfile {
  lastDrink?: string;
  favoriteDrink?: string;
  drinkCounts: { [drinkName: string]: number };
  achievements: string[];
  totalOrders: number;
}
