# Blueprint de la Aplicación Flutter de Lealtad

## Descripción General

Esta es una aplicación de Flutter diseñada como un programa de lealtad para una cafetería. Permite a los usuarios realizar pedidos, hacer un seguimiento de sus bebidas favoritas y desbloquear logros. La aplicación se integra con Firebase para la autenticación, la base de datos y la lógica del lado del servidor a través de Cloud Functions.

## Estilo y Diseño

- **Tema:** Moderno y limpio, utilizando Material 3.
- **Paleta de colores:** Centrada en un `primarySeedColor` (actualmente Morado Profundo) para generar esquemas de colores claros y oscuros armoniosos.
- **Tipografía:** `GoogleFonts` para una apariencia pulida y legible (Oswald, Roboto, Open Sans).
- **Componentes:** Estilos consistentes para `AppBar`, `ElevatedButton`, etc., definidos en el tema para garantizar la uniformidad.
- **Modo Oscuro:** Soporte completo para los modos claro y oscuro, con un interruptor para que el usuario elija.

## Características Implementadas

- **Gestión de Tema:**
  - Se utiliza el paquete `provider` para gestionar el estado del tema.
  - `ThemeProvider` permite cambiar entre los modos claro, oscuro y del sistema.
  - El tema se genera dinámicamente a partir de un color semilla (`ColorScheme.fromSeed`).

- **Navegación:**
  - Se implementó un sistema de navegación básico utilizando `Navigator.push`.
  - Se crearon rutas para una pantalla de inicio (`MyHomePage`) y una pantalla de perfil (`ProfileScreen`).

- **Pantallas y UI:**
  - **Pantalla de Inicio (`MyHomePage`):**
    - Muestra una lista de ejemplo de elementos de menú.
    - Contiene botones para navegar al perfil y para simular la adición de un pedido.
    - Incluye un carrusel de imágenes para mostrar ofertas o artículos destacados.
  - **Pantalla de Perfil (`ProfileScreen`):**
    - Muestra los detalles del perfil del usuario obtenidos de Firestore.
    - Muestra logros, bebida favorita y estadísticas de pedidos.
    - Se actualiza en tiempo real gracias a un `StreamBuilder`.

- **Integración con Firebase:**
  - **Firestore:**
    - Colección `customerProfiles`: Almacena los datos de lealtad de cada usuario.
    - Colección `orders`: Almacena los pedidos realizados por los usuarios.
    - Reglas de seguridad configuradas para permitir la lectura/escritura a usuarios autenticados.
  - **Autenticación:**
    - Configurada la autenticación con Google Sign-In.
    - La lógica de la aplicación maneja el estado de autenticación para mostrar la pantalla correcta (inicio de sesión o pantalla de inicio).
  - **Cloud Functions (¡NUEVO!):**
    - **`onOrderCompleted`**: Una función de fondo (background function) escrita en TypeScript que se activa (`onDocumentCreated`) cada vez que se añade un nuevo documento a la colección `/orders/{orderId}`.
    - **Lógica de la Función:**
      1. Lee los datos del nuevo pedido.
      2. Obtiene el `userId` y los `items` del pedido.
      3. Busca el documento correspondiente en la colección `customerProfiles`.
      4. Actualiza el perfil del cliente con:
         - La última bebida pedida.
         - Un recuento de cada tipo de bebida.
         - El número total de pedidos.
         - Desbloquea logros basados en la cantidad de pedidos (por ejemplo, "Primer Pedido", "Leal").
    - **Despliegue y Configuración:** Se ha configurado un pipeline de despliegue robusto con `eslint` para el análisis de código y `tsc` para la compilación de TypeScript.

- **Estructura del Proyecto:**
  - Código de la aplicación Flutter en la carpeta `lib`.
  - Código de las Cloud Functions en la carpeta `functions`, escrito en TypeScript.
  - Configuración de Firebase (`firebase.json`) y reglas de Firestore (`firestore.rules`) en la raíz del proyecto.
