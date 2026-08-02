# PrestaMesta — Diseño de app (Flutter)

Este proyecto contiene **solo el diseño / UI** de la app móvil de PrestaMesta,
basado en el mockup mostrado en [prestamesta.fun](https://www.prestamesta.fun/)
y en la pantalla "Resumen de tu préstamo" del sitio.

Todos los datos (nombre, montos, fechas, estado de solicitud) están
**hardcodeados** en `lib/data/demo_data.dart` — no hay backend conectado
todavía. Cuando quieras conectar el servidor real
([PrestaMesta_Server](https://github.com/PrestaMesta/PrestaMesta_Server)),
ese es el único archivo que necesitas reemplazar por llamadas a la API.

## Estructura

```
lib/
  main.dart                 # entrypoint
  theme/app_theme.dart      # colores de marca (#0C222F navy + verde)
  data/demo_data.dart       # TODOS los datos hardcodeados
  widgets/
    pm_logo.dart            # wordmark "P PrestaMesta"
    demo_banner.dart        # aviso "datos ficticios"
    pm_bottom_nav.dart      # barra inferior (Inicio/Simulación/Calendario/Estado/Perfil)
  screens/
    root_shell.dart         # Scaffold + AppBar + bottom nav
    home_screen.dart        # Resumen de préstamo (pantalla del mockup)
    simulation_screen.dart  # Opciones de préstamo
    calendar_screen.dart    # Historial y próximos pagos
    status_screen.dart      # Línea de tiempo de la solicitud
    profile_screen.dart     # Perfil de usuario
```

## Cómo correrlo

1. Instala el [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Desde esta carpeta:
   ```bash
   flutter pub get
   flutter run
   ```
   (usa un emulador Android/iOS o Chrome con `flutter run -d chrome`).

## Paleta

| Uso                 | Color     |
|----------------------|-----------|
| Navy (marca)          | `#0C222F` |
| Verde inicio gradiente | `#0E7C61` |
| Verde fin gradiente    | `#1DA679` |
| Fondo                  | `#F4F7F8` |

## Siguientes pasos sugeridos

- Conectar `demo_data.dart` a `PrestaMesta_Server` vía HTTP/REST.
- Agregar autenticación real (login/registro).
- Reemplazar el `IndexedStack` simple por `go_router` si crece la navegación.
