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

## Plan de Cambios Actual

*No hay cambios pendientes en este momento.*