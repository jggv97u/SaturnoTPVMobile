import * as admin from "firebase-admin";

export interface Order {
  completed: boolean;
  userId: string;
  items: { name: string; }[];
  createdAt: admin.firestore.Timestamp;
}

export interface CustomerProfile {
  lastDrink?: string;
  favoriteDrink?: string;
  drinkCounts: { [drinkName: string]: number };
  achievements: string[];
  totalOrders: number;
}
