"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onOrderCompleted = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_functions_1 = require("firebase-functions");
admin.initializeApp();
const db = admin.firestore();
// Constantes para los logros
const ACHIEVEMENT_EARLY_RISER = "Madrugador";
const ACHIEVEMENT_FLAVOR_EXPLORER = "Explorador de Sabores";
const ACHIEVEMENT_STAR_FREQUENCY = "Frecuencia Estelar";
const FLAVOR_EXPLORER_THRESHOLD = 5; // Número de bebidas diferentes para el logro
const STAR_FREQUENCY_THRESHOLD = 10; // Número de órdenes para el logro
exports.onOrderCompleted = (0, firestore_1.onDocumentCreated)("orders/{orderId}", async (event) => {
    firebase_functions_1.logger.info(`Nueva orden detectada: ${event.params.orderId}`);
    const snapshot = event.data;
    if (!snapshot) {
        firebase_functions_1.logger.info("No hay datos en el evento, terminando función.");
        return;
    }
    const order = snapshot.data();
    // 1. Solo procesar si la orden está marcada como completada
    if (!order.completed || !order.userId || !order.items || order.items.length === 0) {
        firebase_functions_1.logger.info(`La orden ${event.params.orderId} no está lista para procesar.`);
        return;
    }
    const { userId, items, createdAt } = order;
    const userProfileRef = db.collection("customerProfiles").doc(userId);
    try {
        await db.runTransaction(async (transaction) => {
            const userProfileDoc = await transaction.get(userProfileRef);
            // Si no existe perfil, lo creamos vacío
            if (!userProfileDoc.exists) {
                const initialProfile = {
                    drinkCounts: {},
                    achievements: [],
                    totalOrders: 0,
                };
                transaction.set(userProfileRef, initialProfile);
            }
            const userProfile = (userProfileDoc.data() || { drinkCounts: {}, achievements: [], totalOrders: 0 });
            // 2. Actualizar preferencias del cliente
            const lastDrink = items[0].name;
            userProfile.lastDrink = lastDrink;
            // Actualizar conteo de bebidas
            items.forEach(item => {
                userProfile.drinkCounts[item.name] = (userProfile.drinkCounts[item.name] || 0) + 1;
            });
            // Determinar bebida favorita
            let favoriteDrink = "";
            let maxCount = 0;
            for (const drink in userProfile.drinkCounts) {
                if (userProfile.drinkCounts[drink] > maxCount) {
                    maxCount = userProfile.drinkCounts[drink];
                    favoriteDrink = drink;
                }
            }
            userProfile.favoriteDrink = favoriteDrink;
            // Incrementar el total de órdenes
            userProfile.totalOrders = (userProfile.totalOrders || 0) + 1;
            // 3. Otorgar logros
            const achievements = userProfile.achievements || [];
            // Logro: Madrugador (antes de las 9 AM)
            const orderHour = createdAt.toDate().getHours();
            if (orderHour < 9 && !achievements.includes(ACHIEVEMENT_EARLY_RISER)) {
                achievements.push(ACHIEVEMENT_EARLY_RISER);
                firebase_functions_1.logger.info(`¡Logro desbloqueado para ${userId}: ${ACHIEVEMENT_EARLY_RISER}!`);
            }
            // Logro: Explorador de Sabores
            const uniqueDrinksCount = Object.keys(userProfile.drinkCounts).length;
            if (uniqueDrinksCount >= FLAVOR_EXPLORER_THRESHOLD && !achievements.includes(ACHIEVEMENT_FLAVOR_EXPLORER)) {
                achievements.push(ACHIEVEMENT_FLAVOR_EXPLORER);
                firebase_functions_1.logger.info(`¡Logro desbloqueado para ${userId}: ${ACHIEVEMENT_FLAVOR_EXPLORER}!`);
            }
            // Logro: Frecuencia Estelar
            if (userProfile.totalOrders >= STAR_FREQUENCY_THRESHOLD && !achievements.includes(ACHIEVEMENT_STAR_FREQUENCY)) {
                achievements.push(ACHIEVEMENT_STAR_FREQUENCY);
                firebase_functions_1.logger.info(`¡Logro desbloqueado para ${userId}: ${ACHIEVEMENT_STAR_FREQUENCY}!`);
            }
            userProfile.achievements = achievements;
            // Guardar todos los cambios en el perfil del usuario
            transaction.update(userProfileRef, Object.assign({}, userProfile));
            firebase_functions_1.logger.info(`Perfil del usuario ${userId} actualizado correctamente.`);
        });
    }
    catch (error) {
        firebase_functions_1.logger.error(`Error al procesar la orden ${event.params.orderId} para el usuario ${userId}:`, error);
    }
});
//# sourceMappingURL=index.js.map