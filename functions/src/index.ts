
import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { Order, Cliente } from "./types";

admin.initializeApp();
const db = admin.firestore();

// --- Constantes para Logros ---
const ACHIEVEMENT_EARLY_RISER = "Madrugador";
const ACHIEVEMENT_FLAVOR_EXPLORER = "Explorador de Sabores";
const ACHIEVEMENT_STAR_FREQUENCY = "Frecuencia Estelar";
const FLAVOR_EXPLORER_THRESHOLD = 5;
const STAR_FREQUENCY_THRESHOLD = 10;

/**
 * Función principal del sistema de lealtad. Se activa al crear un documento en 'historial_compras'.
 * Centraliza el cálculo de puntos, visitas, preferencias y logros.
 */
export const onOrderCompleted = onDocumentCreated("historial_compras/{orderId}", async (event) => {
  logger.info(`Iniciando procesamiento de orden completada: ${event.params.orderId}`);

  const snapshot = event.data;
  if (!snapshot) {
    logger.warn("El evento no contenía datos. Terminando función.");
    return;
  }

  const order = snapshot.data() as Order;
  if (!order.userId || !order.items || order.items.length === 0) {
    logger.info(`La orden ${event.params.orderId} no tiene 'userId' o 'items'. No se procesará.`);
    return;
  }

  const { userId, items, createdAt } = order;
  const clienteRef = db.collection("clientes").doc(userId);

  try {
    await db.runTransaction(async (transaction) => {
      const clienteDoc = await transaction.get(clienteRef);
      if (!clienteDoc.exists) {
        logger.error(`El cliente con ID: ${userId} no existe.`);
        return;
      }

      const clienteData = clienteDoc.data() as Cliente;

      // Cálculo de Puntos
      const basePoints = items.reduce((sum, item) => sum + (item.cantidad || 0), 0);
      let multiplier = 1.0;
      if (clienteData.visitas >= 50) multiplier = 1.5;
      else if (clienteData.visitas >= 15) multiplier = 1.25;
      const pointsEarned = Math.round(basePoints * multiplier);
      const newTotalPoints = (clienteData.puntos || 0) + pointsEarned;

      // Última Bebida
      const lastDrink = items.length > 0 ? items[items.length - 1].nombre : clienteData.lastDrink || "";

      // Bebida Favorita
      const historialSnapshot = await db.collection("historial_compras").where("userId", "==", userId).get();
      const allItemsEver = [...items];
      historialSnapshot.forEach(doc => {
          const pastOrder = doc.data() as Order;
          if (pastOrder.items) allItemsEver.push(...pastOrder.items);
      });
      const drinkCounts: { [key: string]: number } = {};
      allItemsEver.forEach(item => {
          if (item.nombre) drinkCounts[item.nombre] = (drinkCounts[item.nombre] || 0) + (item.cantidad || 1);
      });
      let favoriteDrink = clienteData.favoriteDrink || "";
      if (Object.keys(drinkCounts).length > 0) {
          favoriteDrink = Object.entries(drinkCounts).reduce((a, b) => a[1] > b[1] ? a : b)[0];
      }
      
      // Gestión de Logros
      const achievements: string[] = clienteData.achievements || [];
      const totalOrders = (clienteData.visitas || 0) + 1;
      if (createdAt.toDate().getHours() < 9 && !achievements.includes(ACHIEVEMENT_EARLY_RISER)) achievements.push(ACHIEVEMENT_EARLY_RISER);
      if (Object.keys(drinkCounts).length >= FLAVOR_EXPLORER_THRESHOLD && !achievements.includes(ACHIEVEMENT_FLAVOR_EXPLORER)) achievements.push(ACHIEVEMENT_FLAVOR_EXPLORER);
      if (totalOrders >= STAR_FREQUENCY_THRESHOLD && !achievements.includes(ACHIEVEMENT_STAR_FREQUENCY)) achievements.push(ACHIEVEMENT_STAR_FREQUENCY);

      // Actualización Atómica del Perfil
      const profileUpdateData = {
        puntos: newTotalPoints,
        visitas: admin.firestore.FieldValue.increment(1),
        ultima_visita: createdAt,
        lastDrink, favoriteDrink, achievements,
      };
      transaction.update(clienteRef, profileUpdateData);
      logger.info(`Perfil del cliente ${userId} actualizado con nuevos puntos, visitas y preferencias.`);
    });
  } catch (error) {
    logger.error(`Error al procesar la orden para el cliente ${userId}:`, error);
  }
});


/**
 * Se encarga EXCLUSIVAMENTE de canjear puntos por cupones Y REINICIAR LOS PUNTOS.
 */
export const onClienteUpdated = onDocumentUpdated("clientes/{clienteId}", async (event) => {
  logger.info(`Revisando puntos para posible cupón para el cliente: ${event.params.clienteId}`);
  
  const afterData = event.data?.after.data() as Cliente | undefined;
  if (!afterData || typeof afterData.puntos !== 'number') {
    logger.warn("Datos incompletos o 'puntos' no es un número. Terminando función de cupones.");
    return;
  }
  
  const puntosActuales = afterData.puntos;
  const PUNTOS_POR_CUPON = 7;

  if (puntosActuales >= PUNTOS_POR_CUPON) {
    const cuponesAGenerar = Math.floor(puntosActuales / PUNTOS_POR_CUPON);
    // *** LÓGICA CORREGIDA: Calcular los puntos restantes ***
    const puntosRestantes = puntosActuales % PUNTOS_POR_CUPON;

    logger.info(`Cliente ${event.params.clienteId} ha ganado ${cuponesAGenerar} cupón(es). Puntos restantes: ${puntosRestantes}.`);

    const batch = db.batch();

    for (let i = 0; i < cuponesAGenerar; i++) {
      const nuevoCuponRef = db.collection("cupones_bebidas_gratis").doc();
      const fechaExpiracion = new Date();
      fechaExpiracion.setDate(fechaExpiracion.getDate() + 7);

      batch.set(nuevoCuponRef, {
        clienteId: event.params.clienteId,
        codigo: `SAT-${nuevoCuponRef.id.substring(0, 8).toUpperCase()}`,
        fechaCreacion: admin.firestore.FieldValue.serverTimestamp(),
        fechaExpiracion: admin.firestore.Timestamp.fromDate(fechaExpiracion),
        estado: "valido",
        origen: "Canje de Puntos (Cloud Fx)",
      });
    }
    
    // *** LÓGICA CORREGIDA: Añadir la actualización de puntos al batch ***
    const clienteRef = db.collection("clientes").doc(event.params.clienteId);
    batch.update(clienteRef, { puntos: puntosRestantes });

    try {
      await batch.commit();
      logger.info(`Lote completado: ${cuponesAGenerar} cupón(es) creados y puntos reiniciados para ${event.params.clienteId}.`);
    } catch (error) {
      logger.error(`Error al ejecutar el lote de cupones y reinicio de puntos para ${event.params.clienteId}:`, error);
    }

  } else {
    logger.info(`Puntos insuficientes (${puntosActuales}) para generar cupón para ${event.params.clienteId}.`);
  }
});
