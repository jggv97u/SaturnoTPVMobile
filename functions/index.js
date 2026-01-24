const functions = require("firebase-functions");
const { MercadoPagoConfig, Preference } = require("mercadopago");

const client = new MercadoPagoConfig({
  accessToken: "TEST-4829399239846938-071317-a9a30b501c10d3a58e124c653d662b21-1892336336",
});

exports.createPaymentPreference = functions.https.onCall(async (data, context) => {
  const amount = data.amount;
  const title = data.title;
  const email = data.email;

  if (!amount || !title || !email) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'La función debe ser llamada con los argumentos "amount", "title" y "email".'
    );
  }

  const preferenceBody = {
    items: [
      {
        title: title,
        quantity: 1,
        currency_id: "MXN",
        unit_price: amount,
      },
    ],
    payer: {
      email: email,
    },
    // Agregamos URLs para que Mercado Pago sepa a dónde volver
    back_urls: {
        success: "https://console.firebase.google.com/project/saturnotrcventasdb/overview", // URL placeholder de éxito
        failure: "https://console.firebase.google.com/project/saturnotrcventasdb/overview", // URL placeholder de fallo
        pending: "https://console.firebase.google.com/project/saturnotrcventasdb/overview", // URL placeholder de pendiente
    },
    auto_return: "approved",
  };

  try {
    console.log("Creando preferencia con los datos:", JSON.stringify(preferenceBody));
    
    const preference = new Preference(client);
    const result = await preference.create({ body: preferenceBody });

    const preferenceId = result.id;
    const checkoutUrl = result.init_point; // <-- La URL de pago que necesitamos

    console.log(`Preferencia creada con ID: ${preferenceId}`);
    console.log(`URL de Checkout: ${checkoutUrl}`);

    // Devolvemos ambos valores al cliente
    return { preferenceId, checkoutUrl };

  } catch (error) {
    console.error("Error al crear la preferencia de Mercado Pago:", error);
    throw new functions.https.HttpsError('internal', 'No se pudo crear la preferencia de Mercado Pago.', error.message);
  }
});
