"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onClienteUpdated = exports.onOrderCompleted = void 0;
const admin = require("firebase-admin");
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_functions_1 = require("firebase-functions");
admin.initializeApp();
const db = admin.firestore();
// --- Constantes para el Sistema 2 (Logros) ---
const ACHIEVEMENT_EARLY_RISER = "Madrugador";
const ACHIEVEMENT_FLAVOR_EXPLORER = "Explorador de Sabores";
const ACHIEVEMENT_STAR_FREQUENCY = "Frecuencia Estelar";
const FLAVOR_EXPLORER_THRESHOLD = 5; // Número de bebidas diferentes para el logro
const STAR_FREQUENCY_THRESHOLD = 10; // Número de órdenes para el logro
// --- FUNCIÓN EXISTENTE: Sistema de Logros ---
exports.onOrderCompleted = (0, firestore_1.onDocumentCreated)("orders/{orderId}", async (event) => {
    firebase_functions_1.logger.info(`Nueva orden detectada: ${event.params.orderId}`);
    const snapshot = event.data;
    if (!snapshot) {
        firebase_functions_1.logger.info("No hay datos en el evento, terminando función.");
        return;
    }
    const order = snapshot.data();
    if (!order.completed || !order.userId || !order.items || order.items.length === 0) {
        firebase_functions_1.logger.info(`La orden ${event.params.orderId} no está lista para procesar.`);
        return;
    }
    const { userId, items, createdAt } = order;
    const userProfileRef = db.collection("customerProfiles").doc(userId);
    try {
        await db.runTransaction(async (transaction) => {
            const userProfileDoc = await transaction.get(userProfileRef);
            if (!userProfileDoc.exists) {
                const initialProfile = {
                    drinkCounts: {},
                    achievements: [],
                    totalOrders: 0,
                };
                transaction.set(userProfileRef, initialProfile);
            }
            const userProfile = (userProfileDoc.data() || { drinkCounts: {}, achievements: [], totalOrders: 0 });
            const lastDrink = items[0].name;
            userProfile.lastDrink = lastDrink;
            items.forEach(item => {
                userProfile.drinkCounts[item.name] = (userProfile.drinkCounts[item.name] || 0) + 1;
            });
            let favoriteDrink = "";
            let maxCount = 0;
            for (const drink in userProfile.drinkCounts) {
                if (userProfile.drinkCounts[drink] > maxCount) {
                    maxCount = userProfile.drinkCounts[drink];
                    favoriteDrink = drink;
                }
            }
            userProfile.favoriteDrink = favoriteDrink;
            userProfile.totalOrders = (userProfile.totalOrders || 0) + 1;
            const achievements = userProfile.achievements || [];
            const orderHour = createdAt.toDate().getHours();
            if (orderHour < 9 && !achievements.includes(ACHIEVEMENT_EARLY_RISER)) {
                achievements.push(ACHIEVEMENT_EARLY_RISER);
                firebase_functions_1.logger.info(`¡Logro desbloqueado para ${userId}: ${ACHIEVEMENT_EARLY_RISER}!`);
            }
            const uniqueDrinksCount = Object.keys(userProfile.drinkCounts).length;
            if (uniqueDrinksCount >= FLAVOR_EXPLORER_THRESHOLD && !achievements.includes(ACHIEVEMENT_FLAVOR_EXPLORER)) {
                achievements.push(ACHIEVEMENT_FLAVOR_EXPLORER);
                firebase_functions_1.logger.info(`¡Logro desbloqueado para ${userId}: ${ACHIEVEMENT_FLAVOR_EXPLORER}!`);
            }
            if (userProfile.totalOrders >= STAR_FREQUENCY_THRESHOLD && !achievements.includes(ACHIEVEMENT_STAR_FREQUENCY)) {
                achievements.push(ACHIEVEMENT_STAR_FREQUENCY);
                firebase_functions_1.logger.info(`¡Logro desbloqueado para ${userId}: ${ACHIEVEMENT_STAR_FREQUENCY}!`);
            }
            userProfile.achievements = achievements;
            transaction.update(userProfileRef, Object.assign({}, userProfile));
            firebase_functions_1.logger.info(`Perfil del usuario ${userId} actualizado correctamente.`);
        });
    }
    catch (error) {
        firebase_functions_1.logger.error(`Error al procesar la orden ${event.params.orderId} para el usuario ${userId}:`, error);
    }
});
// --- NUEVA FUNCIÓN: Sistema de Puntos y Cupones (Robusta y sin duplicación) ---
exports.onClienteUpdated = (0, firestore_1.onDocumentUpdated)("clientes/{clienteId}", async (event) => {
    var _a, _b;
    firebase_functions_1.logger.info(`INICIO de ejecución para cliente: ${event.params.clienteId}`);
    const beforeData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const afterData = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    // Comprobación de seguridad: nos aseguramos de tener los datos necesarios.
    if (!beforeData || !afterData || typeof afterData.puntos !== 'number' || typeof beforeData.puntos !== 'number') {
        firebase_functions_1.logger.warn("Datos incompletos o 'puntos' no es un número. Terminando función.");
        return;
    }
    const puntosAntes = beforeData.puntos;
    const puntosDespues = afterData.puntos;
    const PUNTOS_POR_CUPON = 7;
    // --- CONDICIÓN MEJORADA ---
    // La función solo actúa si los puntos AUMENTARON y cruzaron el umbral.
    // Esto evita que se ejecute en bucle o por otras actualizaciones.
    if (puntosDespues > puntosAntes && puntosDespues >= PUNTOS_POR_CUPON) {
        firebase_functions_1.logger.info(`Cliente ${event.params.clienteId} cruzó el umbral de ${PUNTOS_POR_CUPON} puntos. Puntos antes: ${puntosAntes}, Puntos después: ${puntosDespues}`);
        // Usaremos un "batch write" que funciona de forma similar a una transacción para este caso.
        const batch = db.batch();
        const cuponesAGenerar = Math.floor(puntosDespues / PUNTOS_POR_CUPON);
        const puntosRestantes = puntosDespues % PUNTOS_POR_CUPON;
        firebase_functions_1.logger.info(`Generando ${cuponesAGenerar} cupón(es) y estableciendo los puntos del cliente a ${puntosRestantes}.`);
        // 1. Generamos todos los cupones necesarios
        for (let i = 0; i < cuponesAGenerar; i++) {
            const nuevoCuponRef = db.collection("cupones_bebidas_gratis").doc();
            const fechaExpiracion = new Date();
            fechaExpiracion.setDate(fechaExpiracion.getDate() + 7); // El cupón expira en 7 días
            batch.set(nuevoCuponRef, {
                clienteId: event.params.clienteId,
                codigo: `SAT-${nuevoCuponRef.id.substring(0, 8).toUpperCase()}`,
                fechaCreacion: admin.firestore.FieldValue.serverTimestamp(),
                fechaExpiracion: admin.firestore.Timestamp.fromDate(fechaExpiracion),
                estado: "valido",
                origen: "Canje de Puntos (Cloud Fx)",
            });
        }
        // 2. Actualizamos los puntos del cliente a su nuevo total
        const clienteRef = db.collection("clientes").doc(event.params.clienteId);
        batch.update(clienteRef, { puntos: puntosRestantes });
        // 3. Ejecutamos todas las operaciones como un solo lote atómico.
        // Si algo falla, ninguna de las operaciones se aplica.
        try {
            await batch.commit();
            firebase_functions_1.logger.info(`Lote completado: ${cuponesAGenerar} cupón(es) creado(s) y puntos actualizados a ${puntosRestantes} para ${event.params.clienteId}.`);
        }
        catch (error) {
            firebase_functions_1.logger.error(`Error al ejecutar el lote para el cliente ${event.params.clienteId}:`, error);
        }
    }
    else {
        firebase_functions_1.logger.info(`No se cumplieron las condiciones para generar cupón para ${event.params.clienteId}. Puntos antes: ${puntosAntes}, Puntos después: ${puntosDespues}. Terminando ejecución.`);
    }
});
//# sourceMappingURL=index.js.map