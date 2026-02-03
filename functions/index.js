const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const functions = require("firebase-functions");

admin.initializeApp();

exports.updateCustomerStatsOnSale = onDocumentCreated("ventas/{ventaId}", async (event) => {
    const snap = event.data;
    if (!snap) {
        console.log("No data associated with the event");
        return;
    }
    const saleData = snap.data();

    if (!saleData.clienteId) {
        return;
    }

    const clienteId = saleData.clienteId;
    const customerRef = admin.firestore().collection("clientes").doc(clienteId);

    try {
        const customerDoc = await customerRef.get();
        if (!customerDoc.exists) {
            console.log(`Cliente con ID ${clienteId} no encontrado.`);
            return;
        }

        const customerData = customerDoc.data();
        const saleTimestamp = saleData.timestamp.toDate();

        const updateData = {
            lastVisit: saleTimestamp,
            lastDrink: saleData.productoNombre,
        };

        if (!customerData.firstVisit) {
            updateData.firstVisit = saleTimestamp;
        }

        const salesSnapshot = await admin.firestore().collection("ventas")
            .where("clienteId", "==", clienteId)
            .get();
        
        const drinkCounts = {};
        salesSnapshot.forEach(doc => {
            const drink = doc.data().productoNombre;
            drinkCounts[drink] = (drinkCounts[drink] || 0) + 1;
        });

        if (Object.keys(drinkCounts).length > 0) {
            const favoriteDrink = Object.keys(drinkCounts).reduce((a, b) => 
                drinkCounts[a] > drinkCounts[b] ? a : b
            );
            updateData.favoriteDrink = favoriteDrink;
        }

        await customerRef.update(updateData);
        console.log(`Estadísticas actualizadas para el cliente ${clienteId}`);

    } catch (error) {
        console.error("Error al actualizar estadísticas del cliente:", error);
    }
});
