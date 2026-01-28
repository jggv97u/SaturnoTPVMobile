# Blueprint de SaturnoTPV

## Descripción General

Este documento detalla el estado actual y las características de la aplicación SaturnoTPV, un punto de venta y sistema de gestión desarrollado en Flutter.

## Estilo, Diseño y Características (Versión Inicial)

Esta sección documenta el estado del proyecto después de los cambios iniciales de branding.

*   **Nombre de la Aplicación:** `SaturnoTPV`
*   **Descripción:** "Punto de venta y sistema de gestión para Saturno."
*   **Ícono Principal:** Se utiliza un logo vectorial (`logo.svg`) ubicado en la carpeta `web/`. Este ícono se emplea como favicon y como ícono de la aplicación web instalable (PWA).
*   **Plataforma Principal:** Aplicación web.

### Cambios Realizados:

1.  **Renombrado del Proyecto:**
    *   Se actualizó `pubspec.yaml` para reflejar el nuevo nombre `SaturnoTPV`.
    *   Se modificó `web/index.html` para cambiar el título de la página.
    *   Se ajustó `web/manifest.json` para establecer el `name` y `short_name` a `SaturnoTPV`.

2.  **Personalización del Ícono:**
    *   Se subió el archivo `logo.svg` a la carpeta `web/`.
    *   Se actualizó `web/index.html` para usar `logo.svg` como favicon.
    *   Se reconfiguró `web/manifest.json` para que el `logo.svg` sea el ícono principal de la aplicación, reemplazando los íconos PNG por defecto.
    *   Se eliminaron los archivos de íconos PNG genéricos (`Icon-192.png`, `Icon-512.png`, etc.) y `favicon.png` para limpiar el proyecto.

3.  **Corrección de Errores y Despliegue:**
    *   Se corrigieron múltiples errores de importación en toda la aplicación que impedían la compilación.
    *   Se realizó el despliegue inicial de la aplicación en Firebase Hosting.
    *   Se inicializó el repositorio de Git y se guardó el estado del proyecto.

## Plan de Cambios Actual: Programa de Lealtad

Se implementará un sistema de lealtad para recompensar a los clientes recurrentes. El sistema se basa en la acumulación de puntos por compras.

**Concepto:** Por cada **7 bebidas** que un cliente compre, la siguiente será **gratis**.

### Fases de Implementación:

#### **Fase 1: Modelo de Datos y Base de Datos**
1.  **Nueva Colección en Firestore:** Crear una colección `clientes` para almacenar el nombre, teléfono (identificador único), puntos y fecha de registro de cada cliente.
2.  **Modelo en Dart:** Crear un archivo `lib/models/customer.dart` con la clase `Customer` para manejar los datos de forma segura.

#### **Fase 2: Interfaz de Gestión de Clientes**
1.  **Pantalla de Administración:** Desarrollar `lib/customer_management_screen.dart` para listar y buscar clientes.
2.  **Formulario de Registro/Edición:** Crear un formulario para dar de alta y modificar la información de los clientes.

#### **Fase 3: Integración con el Flujo de Venta**
1.  **Asociar Cliente a Orden:** En `lib/drinks_menu_screen.dart`, añadir una función para seleccionar un cliente al iniciar una orden.
2.  **Acumulación de Puntos:** En `lib/payment_screen.dart`, al finalizar un pago, incrementar los puntos del cliente asociado según la cantidad de bebidas compradas.

#### **Fase 4: Canje de Recompensas**
1.  **Notificación de Recompensa:** En `lib/drinks_menu_screen.dart`, mostrar un aviso visible si el cliente tiene 7 o más puntos.
2.  **Lógica de Canje:** Implementar un botón "Canjear" que permita aplicar un descuento del 100% a una bebida y que reste 7 puntos del saldo del cliente al completar la venta.
