# Blueprint de la Aplicación TPV Saturno

## Visión General

**Saturno TPV** es una aplicación de Terminal de Punto de Venta (TPV) diseñada para ser rápida, intuitiva y robusta. Construida con Flutter y Firebase, la aplicación permite a los comerciantes gestionar órdenes de venta en tiempo real, desde su creación hasta su finalización y archivo.

El objetivo es proporcionar una herramienta que funcione de manera fluida tanto en dispositivos móviles como en la web, asegurando que los datos estén siempre sincronizados y accesibles gracias a la potencia de Firestore.

---

## Características y Diseño Implementados

Esta sección documenta el estado actual de la aplicación, reflejando las funcionalidades y decisiones de diseño que se han implementado.

### 1. **Gestión de Órdenes Activas**
   - **Pantalla Principal (`OrdersScreen`)**: Muestra una lista en tiempo real de todas las órdenes activas, obtenidas de la colección `ordenes_activas` de Firestore.
   - **Diseño de la Lista**: Se utiliza un `StreamBuilder` para una actualización automática. Cada orden se presenta en una `Card` con un `ListTile` que muestra el nombre de la orden y un botón de acción.
   - **Botón de Cobrar**: Cada orden tiene un botón que navega a la pantalla de pago (`PaymentScreen`), pasando la información completa de la orden seleccionada.
   - **Estilo Visual**: La pantalla principal utiliza un `AppBar` con el título "Órdenes Activas Saturno" y un color de fondo `inversePrimary` del tema de Material 3, proporcionando una apariencia moderna y limpia.

### 2. **Proceso de Pago y Finalización (`PaymentScreen`)**
   - **Navegación**: Al pulsar "Cobrar", el usuario es llevado a esta pantalla, que recibe el `DocumentSnapshot` de la orden.
   - **Visualización del Total**: La pantalla muestra de forma prominente el monto total a pagar, extraído del campo `total_orden` del documento.
   - **Métodos de Pago**: Se presentan botones para seleccionar el método de pago (Efectivo y Transferencia). El botón de Tarjeta está presente pero deshabilitado.
   - **Lógica de Finalización de Orden**:
     - Al seleccionar un método de pago, la aplicación ejecuta una transacción atómica (`WriteBatch` de Firestore).
     - **Paso 1: Archivar la Orden**: Se crea un nuevo documento en la colección `ordenes_archivadas`. Este nuevo documento contiene toda la información de la orden original, más campos adicionales como `metodo_pago` y `fecha_finalizacion`.
     - **Paso 2: Eliminar la Orden Activa**: El documento original de la colección `ordenes_activas` es eliminado.
     - **Feedback al Usuario**: Se muestra una `SnackBar` para confirmar que la operación fue exitosa (`Orden finalizada y archivada`).
   - **Manejo de Errores**: Se ha implementado un bloque `try-catch` robusto. Si la transacción falla, se muestra una `SnackBar` de error y se registra el error detallado en la consola del desarrollador usando `dart:developer` para facilitar la depuración.
   - **Control de Estado**: Un indicador de carga (`CircularProgressIndicator`) se muestra mientras se procesa el pago para evitar que el usuario realice acciones duplicadas.

### 3. **Pantalla de Nota de Venta y Compartir (`ReceiptScreen`)**
   - **Flujo de Navegación**: Después de que una orden es finalizada exitosamente en `PaymentScreen`, la aplicación navega a la `ReceiptScreen` utilizando `pushAndRemoveUntil` para limpiar el historial de navegación y evitar que el usuario vuelva a la pantalla de pago.
   - **Diseño de la Nota**: La pantalla presenta la información de la orden archivada en una `Card` con un diseño limpio y profesional. Muestra el nombre de la orden, la lista de artículos con sus precios, el total, y el método de pago.
   - **Formato de Moneda**: Se utiliza el paquete `intl` (`NumberFormat.simpleCurrency`) para formatear todos los montos en moneda local (MXN), mejorando la legibilidad.
   - **Botón de Compartir (`FloatingActionButton`)**: Un botón flotante con el ícono `share` permite al usuario volver a abrir el diálogo de compartición en cualquier momento.
   - **Generación de Texto para Compartir**: La nota de texto para compartir ha sido mejorada con un formato más atractivo, incluyendo emojis y una estructura clara, para ser enviada por WhatsApp u otros medios.
   - **Navegación de Cierre**: Un botón de "Cerrar" (`Icon(Icons.close)`) en el `AppBar` permite al usuario salir de la pantalla de la nota y volver a la pantalla principal (`OrderListScreen`) de una sola vez.

### 4. **Estructura y Arquitectura**
   - **Firebase Core**: El proyecto está configurado con `firebase_core` y `cloud_firestore` para la conectividad con la base de datos.
   - **Punto de Entrada (`main.dart`)**: Inicializa Firebase y define el `MaterialApp` con las rutas y el tema de la aplicación.
   - **Tema (Material 3)**: Se utiliza `ThemeData(useMaterial3: true)` con un `ColorScheme` generado a partir de un `seedColor` (actualmente `deepPurple`), lo que garantiza una estética consistente y moderna en toda la aplicación.

### 5. **Modelo de Datos en Firestore**
   - **`ordenes_activas`**: Colección que almacena las órdenes en curso.
     - `nombre_orden` (String)
     - `items` (Array de Maps)
     - `total_orden` (Number)
     - `timestamp` (Timestamp)
     - `activa` (Boolean: `true`)
   - **`ordenes_archivadas`**: Colección para el histórico de ventas.
     - Mismos campos que `ordenes_activas`, más:
     - `metodo_pago` (String)
     - `fecha_finalizacion` (Timestamp)
     - `id_original` (String)

---
