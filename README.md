# PrestaMesta — App móvil (Flutter)

Este proyecto es la app móvil de clientes de PrestaMesta. Empezó como solo diseño/UI (mockup de
[prestamesta.fun](https://www.prestamesta.fun/)) y se está conectando de forma incremental al
backend real ([PrestaMesta_Server](https://github.com/PrestaMesta/PrestaMesta_Server)).

**Autenticación de clientes**, el **catálogo de créditos + estimación local no autoritativa**, la
**solicitud real de préstamo** (`POST /prestamos/solicitar`, con aval opcional) y, desde este
checkpoint, **Inicio/Estado/Calendario/Perfil basados únicamente en datos reales** ya están
implementados contra el contrato exacto de `PrestaMesta_Server` — no queda ningún dato ficticio en
el flujo normal de la app; `demo_data.dart`/`DemoBanner` se eliminaron por completo (ver "Inicio,
Estado, Calendario y Perfil" más abajo).

Esta integración refleja el contrato actual del backend, pero **todavía no es un flujo productivo
completo**: el backend no tiene MFA, autorización reforzada ("step-up") para operaciones sensibles,
idempotencia de solicitudes, verificación de identidad, destino de desembolso configurable, pagos,
ni una forma de consultar solicitudes propias después de enviarlas. Ver `docs/mobile-api-gaps.md`
para el diseño propuesto (no implementado) de esas piezas.

Ver `docs/mobile-api-gaps.md` para el contrato real disponible en el backend y qué falta.

## Estructura

```
lib/
  main.dart                 # entrypoint; valida la configuración de entorno al arrancar
  app/
    app.dart                # MaterialApp.router
    router.dart             # go_router: rutas, authRedirect (guardas), StatefulShellRoute
    providers.dart          # wiring Riverpod de config/red/almacenamiento (cross-cutting)
    splash_screen.dart      # se muestra solo mientras se restaura la sesión
  core/
    config/                 # EnvConfig: valida APP_ENV/API_BASE_URL desde --dart-define
    network/                 # ApiClient (Dio), interceptores de auth/logging, mapeo de errores
    storage/                 # SecureStorage + SessionLocalStorage (token y perfil por separado)
    errors/                  # AppException y el envelope de error del backend
    utils/                   # jwt_utils: chequeo local (no criptográfico) de expiración del JWT
  features/
    auth/
      data/                  # auth_models, auth_repository (POST register/login), auth_validators
      presentation/          # auth_controller (AuthState), register_controller, login/register screens
    credits/
      data/                  # credit_model (Decimal, nunca double), credits_repository (GET),
                              # loan_estimate (calculateEstimate, mismo redondeo que el backend),
                              # amount_input_parser (monto tecleado por el usuario)
      presentation/          # credits_controller (CreditsState), widgets/ (CreditCard, catálogo)
    loans/
      data/                  # guarantor, loan_request, loan_submission_response (POST solicitar),
                              # loans_repository (LoanSubmissionAmbiguousException incluida)
      presentation/          # loan_draft (borrador en memoria), loan_submission_controller,
                              # session_loan_summary (última respuesta exitosa, solo en memoria),
                              # loan_status_label (formateo de estado/fecha compartido),
                              # loan_review_screen, loan_confirmation_screen, widgets/GuarantorForm
  theme/app_theme.dart      # colores de marca (#0C222F navy + verde)
  widgets/
    pm_logo.dart            # wordmark "P PrestaMesta"
    pm_bottom_nav.dart      # barra inferior (Inicio/Simulación/Calendario/Estado/Perfil)
    empty_state.dart        # shell compartido para estados vacíos honestos (icono+título+mensaje+CTA)
  screens/
    root_shell.dart         # shell de go_router (StatefulShellRoute): AppBar + bottom nav
    home_screen.dart        # Saludo real + CTA a Simulación + última solicitud de la sesión
    simulation_screen.dart  # Catálogo real + estimación local
    calendar_screen.dart    # Estado vacío honesto (el backend no tiene pagos implementados)
    status_screen.dart      # Última solicitud de la sesión, o estado vacío honesto
    profile_screen.dart     # Nombre/correo reales + acción de cerrar sesión
```

No hay ningún archivo de datos ficticios en `lib/` — `lib/data/demo_data.dart` y
`lib/widgets/demo_banner.dart` se eliminaron en este checkpoint; no había una necesidad concreta de
mantener un modo demo explícito para presentaciones, así que no se conservó ninguno.

## Autenticación

Implementada contra el contrato real y exacto de `PrestaMesta_Server` (`openapi.yaml`):
`POST /client/auth/register` y `POST /client/auth/login`. No hay MFA, step-up, biometría,
verificación de identidad ni destino de desembolso — eso sigue siendo solo diseño/documentación en
`docs/mobile-api-gaps.md`.

**Rutas** (`lib/app/router.dart`): `/splash → /login ⇄ /register → /app/*` (cinco pestañas vía
`StatefulShellRoute.indexedStack`, mismo comportamiento de "no perder el estado de la pestaña" que
el `IndexedStack` original). La función pura `authRedirect(status, location)` decide toda la
navegación por sesión — está testeada exhaustivamente en `test/app/router_redirect_test.dart` sin
necesidad de levantar la app.

**Registro**: solo pide `nombre`, `email`, `password` y `telefono` (opcional) — exactamente
`ClienteRegistroInput`. El backend **no** devuelve un token en el registro, así que no hay
auto-login: tras un registro exitoso la app limpia la contraseña, vuelve a `/login` con el correo
prellenado, y nunca lleva la contraseña entre pantallas.

**Login**: envía `email`/`password`, y solo tras una respuesta `200` válida guarda el JWT y el
`ClienteSummary` (`{id, nombre, email}` — exactamente lo que el backend devuelve, nada inventado)
en `flutter_secure_storage`, en dos entradas separadas. `INVALID_CREDENTIALS` se muestra como el
mensaje genérico real del servidor (no distingue correo/contraseña); `429` avisa que hay que
esperar; errores de red permiten reintentar manualmente — nunca hay reintento automático de un
login o registro.

**Restauración de sesión — local únicamente**: al arrancar, `AuthController` lee el token y el
`ClienteSummary` guardados. Si falta alguno, o si el JWT ya luce expirado según su propio claim
`exp` (decodificado localmente, sin verificar firma — solo una pista de UX), limpia la sesión y
pasa a "no autenticado". **No existe `GET /client/me`** en el backend, así que esto nunca es una
revalidación real contra el servidor — solo una respuesta 401 `TOKEN_EXPIRED`/`TOKEN_INVALID` en
una llamada posterior es la verdadera fuente de verdad, y sí limpia la sesión cuando ocurre
(`core/network/auth_interceptor.dart` → `AuthController.sessionRejectedByServer`, idempotente ante
llamadas concurrentes). Un timeout, un 403 o un 500 nunca cierran la sesión.

**Logout**: el backend no tiene revocación de JWT (stateless). "Cerrar sesión" solo borra el token y
el perfil del almacenamiento local del dispositivo — el JWT sigue siendo técnicamente válido en el
servidor hasta su expiración natural si alguien ya lo hubiera copiado. Disponible desde
`ProfileScreen` con una confirmación previa.

## Catálogo de créditos y estimación

`GET /prestamos/creditos` (autenticado — cliente **o** admin, primer endpoint de negocio real de la
app) devuelve un arreglo plano de créditos: `{id, nombre, monto_minimo, monto_maximo,
tasa_interes_anual, plazo_meses, creado_en}`. `monto_minimo`/`monto_maximo`/`tasa_interes_anual`
llegan como **strings decimales** (`"1000.00"`, `"24.00"` — así es como `mysql2` serializa
`DECIMAL`, confirmado en `repositories/prestamoRepository.js`), nunca como `double`: se parsean con
el paquete `decimal` (`Credito.montoMinimo` etc. son `Decimal`).

**La estimación es local y explícitamente no autoritativa.** No existe un endpoint de simulación en
el backend — `calculateEstimate` (`lib/features/credits/data/loan_estimate.dart`) replica, byte por
byte, la fórmula real de `PrestaMesta_Server/utils/money.js` (interés simple anual prorrateado por
plazo, sin capitalización, redondeo `ROUND_HALF_UP` a 2 decimales) usando `Decimal`/`Rational`
exactos — nunca `double` — con los mismos vectores de prueba que el backend
(`test/features/credits/data/loan_estimate_test.dart`, adaptado de
`PrestaMesta_Server/tests/unit/money.test.js`). La pantalla siempre muestra el aviso "Estimación. El
monto definitivo lo calcula el servidor al enviar la solicitud." — no hay `POST
/prestamos/solicitar` todavía, así que ningún número mostrado aquí puede ser, ni pretende ser, el
valor final. No se muestran mensualidad, tabla de amortización, CAT, ni ningún campo que el backend
no devuelva.

**Comportamiento de carga/actualización** (`CreditsController`, `lib/features/credits/presentation/`):
solo se carga con sesión autenticada (se recrea automáticamente al cambiar de cliente autenticado,
para que el catálogo de una sesión nunca se filtre a la siguiente); no se repite la carga al cambiar
de pestaña y volver; una actualización manual fallida conserva las tarjetas visibles con un aviso no
bloqueante y botón de reintento; si dos cargas se inician, solo la más reciente puede ganar
(protección contra respuestas obsoletas, ver
`test/features/credits/presentation/credits_controller_test.dart`).

## Solicitud de préstamo

**Flujo**: `SimulationScreen` (crédito + monto ya validados) → botón "Continuar con la solicitud"
(crea el borrador en memoria, sin red) → `/app/simulacion/solicitud` (revisión, aval opcional) →
"Enviar solicitud" (el único `POST /prestamos/solicitar` de todo el repositorio) →
`/app/simulacion/confirmacion` (solo con una respuesta `201` real). Ambas rutas están protegidas
por el router: sin borrador válido, `/solicitud` rebota a simulación; sin una respuesta exitosa en
memoria, `/confirmacion` también.

**Body enviado** — exactamente `SolicitudPrestamoInput`: `{credito_id, monto_solicitado, aval?}`.
`monto_solicitado` va como **número JSON** (no string), verificado sin pérdida de precisión para
todo el rango `DECIMAL(12,2)` en `test/features/loans/data/loan_request_test.dart`. Nunca se
envían `cliente_id`, `monto_total_a_pagar`, `saldo_pendiente`, `estado`, `fecha_solicitud`,
`tasa_interes_anual` ni `plazo_meses` — el validador del servidor los rechazaría, y hay pruebas
dedicadas a que nunca aparezcan en el body.

**Aval opcional**: apagado por defecto. Si se activa, exige `nombre` y `teléfono` (7–20
caracteres, igual que `avalSchema` en el backend); `dirección` e `ingreso mensual` son opcionales y
se omiten del body si están vacíos — nunca se envía `null` ni `{}`. El teléfono del aval se
muestra enmascarado (`****4567`) en el resumen de revisión. Los datos del aval solo viven en
memoria (`LoanDraft`) — nunca se guardan en `flutter_secure_storage`, disco, ni logs.

**Confirmación**: muestra únicamente los campos que el propio servidor devuelve
(`prestamoId`, `fechaSolicitud`, `montoSolicitado`, `montoTotalAPagar`, `estado`) — el total del
servidor **sustituye** la estimación local, nunca al revés. `estado` se presenta como "Pendiente de
revisión", nunca como "Aprobado"/"Depositado" — el backend solo devuelve `PENDIENTE` en este
endpoint. Incluye el aviso honesto de que la app no puede volver a consultar esa solicitud después
de cerrar la pantalla (**no existe `GET` de solicitudes propias en el backend**).

**Errores manejados**: `VALIDATION_ERROR` (formulario editable), `CREDIT_NOT_FOUND` (invalida el
borrador y ofrece volver al catálogo con una actualización manual), `TOKEN_EXPIRED`/`TOKEN_INVALID`
(limpia la sesión por el mecanismo global existente y termina en `/login`), `FORBIDDEN` (visible,
no cierra sesión), `429` (visible; el cuerpo real de este `429` es **texto plano**, no el envelope
JSON del resto de la API — confirmado contra `express-rate-limit`, ver
`docs/mobile-api-gaps.md`), `500`/`INTERNAL_ERROR` (mensaje no técnico + `requestId` como
referencia).

**Sin reintento automático, en ningún caso** — ni para errores normales, ni para timeouts. El botón
se deshabilita durante el envío y una segunda pulsación no genera una segunda petición
(`test/features/loans/presentation/loan_submission_controller_test.dart`).

**Resultado ambiguo (`outcomeUnknown`)**: el backend **no tiene idempotencia** (ni
`Idempotency-Key`, ni deduplicación) — confirmado, no es una limitación temporal de esta app.
Cuando la app no puede *probar* que el servidor no recibió el `POST` (`sendTimeout`,
`receiveTimeout`, `connectionError`, un `unknown` de Dio, `transformTimeout`, y también una
cancelación — `cancel` — porque Dio no informa si ya se había enviado algo cuando se canceló), se
lo trata como ambiguo, nunca como éxito ni como fallo normal: se muestra una pantalla dedicada
("No pudimos confirmar si la solicitud fue registrada...") sin botón de reintento inmediato, y ese
intento de envío queda bloqueado permanentemente en memoria — el usuario debe volver
conscientemente a simulación para armar una solicitud nueva. Esto es una mitigación local, **no**
idempotencia real: no protege una llamada hecha directamente contra la API ni sobrevive a
reinstalar la app. Solo `connectionTimeout`/`badCertificate` (la conexión/TLS nunca llegó a
completarse — nada pudo haberse enviado) se tratan como fallo definitivo, no ambiguo.

**El endpoint es exclusivo de clientes**: a diferencia de `GET /prestamos/creditos` (acepta cliente
o admin), `POST /prestamos/solicitar` usa `verificarTokenCliente` en el servidor — un token de
administrador, aunque válido, es rechazado solo por su audiencia con `401 TOKEN_INVALID` (nunca
`403`, nunca un mensaje de "credenciales incorrectas"), y la app lo trata igual que cualquier otro
`TOKEN_INVALID`/`TOKEN_EXPIRED` (cierre de sesión global). La identidad del solicitante siempre
viene del `sub` del token verificado en el servidor — `LoanRequest` no tiene ni tendrá un campo
`cliente_id` que pudiera enviarse por error.

**El `429` de este endpoint es una discrepancia de implementación observada, no un contrato
nuevo**: el contrato general de errores promete `{mensaje, codigo, requestId}`, pero
`express-rate-limit` responde texto plano por defecto para este límite específico (confirmado
empíricamente). La app tolera esto por compatibilidad — nunca muestra el texto plano crudo, nunca
inventa `codigo`/`requestId` cuando faltan, y nunca usa el header `Retry-After` (en segundos, como
fecha HTTP, o ausente/inválido) para reintentar automáticamente — pero no lo trata como el
contrato estable a futuro; si el backend algún día normaliza este `429` para pasar por su manejador
de errores general, la app también lo soporta sin cambios (ver pruebas en
`test/core/network/error_mapper_test.dart` y `test/features/loans/data/loans_repository_test.dart`).

## Inicio, Estado, Calendario y Perfil

**Ninguna de estas cuatro pantallas usa datos ficticios.** No existe un endpoint que liste los
préstamos de un cliente, su historial de pagos, ni un calendario de amortización — así que en vez
de simularlos, estas pantallas muestran exactamente lo que el backend puede confirmar hoy: la
sesión real del cliente y, si corresponde, la respuesta real del último `POST
/prestamos/solicitar` enviado durante la sesión actual.

**Última solicitud de la sesión (`SessionLoanSummaryController`,
`lib/features/loans/presentation/session_loan_summary.dart`)**: guarda únicamente la
`LoanSubmissionResponse` de la última solicitud enviada con éxito — `prestamoId`, `fechaSolicitud`,
`montoSolicitado`, `montoTotalAPagar`, `estado`, `mensaje`. Vive **solo en memoria** (no
`flutter_secure_storage`, no disco, no logs), se llena de forma reactiva en cuanto el envío
resulta en éxito (sin ninguna petición adicional al servidor), nunca incluye datos del aval ni el
borrador ni la estimación local, y se recrea vacía (igual que el catálogo y el borrador) al cerrar
sesión o cambiar de cliente — así que no sobrevive a un reinicio de la app ni se filtra entre
sesiones. Un fallo normal o un resultado ambiguo (`outcomeUnknown`) nunca la modifican.

**Inicio**: saluda con el nombre real (`ClienteSummary.nombre`), nunca muestra el `id` interno del
cliente como dato principal, y da acceso directo a Simulación. Si existe una última solicitud de la
sesión, la muestra etiquetada como "Información recibida al enviar la solicitud" con una nota de
que no se actualiza sola; si no existe, muestra "Aún no has enviado una solicitud durante esta
sesión." — nunca "No tienes préstamos", porque el backend no puede confirmar eso.

**Estado**: sin una solicitud en memoria, es un estado vacío honesto que explica que todavía no
existe consulta de solicitudes propias. Con una solicitud en memoria, muestra únicamente los
valores que el servidor devolvió (folio, monto solicitado, monto total, fecha, estado —
`PENDIENTE` como "Pendiente de revisión", `APROBADO`/`RECHAZADO` solo si fue exactamente lo que se
recibió), con una aclaración de que no representa una consulta actualizada. No fabrica una línea de
tiempo, eventos de revisión, ni fechas de decisión.

**Calendario**: un estado vacío honesto, sin excepciones — el backend no tiene pagos ni tabla de
amortización implementados en absoluto (confirmado en `PrestaMesta_Server/CLAUDE.md`), así que ni
siquiera se puede afirmar "sin pagos pendientes" (eso también requeriría un endpoint que no
existe).

**Perfil**: solo `nombre` y `correo` (`ClienteSummary`, exactamente lo que devuelve
`POST /client/auth/login`) — nunca teléfono (el login no lo devuelve), dirección, documento, score,
ni rol. Incluye una nota informativa no interactiva sobre que la autenticación en dos pasos se
incorporará cuando el servidor la admita — sin ningún toggle que aparente que ya está activa.
Conserva el diálogo de confirmación de "Cerrar sesión", que limpia catálogo, borrador, confirmación
y última solicitud de la sesión (todos recreados vacíos por el mismo patrón de providers atados al
id del cliente autenticado).

**Navegación**: los accesos hacia Simulación/Inicio desde estas pantallas usan `context.go(...)`,
la misma forma en que ya navegaban `loan_review_screen.dart`/`loan_confirmation_screen.dart` — esto
cambia de rama dentro del `StatefulShellRoute` existente sin apilar una segunda copia del shell
(`RootShell`/`AppBar`/bottom nav). Cambiar de pestaña nunca dispara una petición HTTP ni vuelve a
crear la última solicitud de la sesión.

## Configuración de entornos

La app **no arranca** sin `--dart-define=APP_ENV=...` y `--dart-define=API_BASE_URL=...` — ver
`lib/core/config/env_config.dart`. Solo `APP_ENV=local` puede usar `http://` (el emulador Android
contra `10.0.2.2`); tanto `testing` como `production` exigen `https://`. No hay valores
hardcodeados ni por defecto: un `flutter run` sin estas banderas muestra una pantalla de error en
vez de arrancar con una URL adivinada.

```bash
# Local, contra el backend corriendo en tu máquina, desde el emulador Android
# (10.0.2.2 es la IP que el emulador usa para llegar al host)
flutter run -d emulator-5554 \
  --dart-define=APP_ENV=local \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Testing, contra un backend de pruebas (reemplaza el placeholder por la URL real)
flutter run -d emulator-5554 \
  --dart-define=APP_ENV=testing \
  --dart-define=API_BASE_URL=https://API-DE-PRUEBAS

# Producción (build de release, reemplaza el placeholder por la URL real)
flutter build apk --release \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://API-DE-PRODUCCION
```

HTTP (cleartext) solo funciona en builds debug (`android/app/src/debug/AndroidManifest.xml`); un
build de release no puede hacer peticiones HTTP sin cifrar aunque se le pase una URL http por
error, y además `EnvConfig` ya rechaza esa combinación antes de intentar cualquier petición.

**Pendiente de decisión**: `android/app/build.gradle.kts` sigue usando `applicationId =
"com.example.prestamesta_app"` (el valor por defecto de Flutter), y el build de release firma
todavía con la clave de debug (confirmado empíricamente en Checkpoint 6 con `apksigner verify`).
Ambos deben resolverse antes del primer release real — no se modificaron en ningún checkpoint sin
aprobación explícita. Ver `docs/release-checklist.md` para el detalle completo de lo pendiente.

## Cómo correrlo

1. Instala el [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Desde esta carpeta: `flutter pub get`.
3. Corre con uno de los comandos de la sección anterior (o su equivalente en Chrome con
   `-d chrome`, agregando las mismas banderas `--dart-define`).

## Pruebas

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

`flutter test` nunca toca el backend real ni crea préstamos reales — todos los repositorios se
prueban con un `HttpClientAdapter` falso (`test/support/fake_http_client_adapter.dart`).
`flutter analyze` está limpio sin errores, warnings ni infos (verificado en Checkpoint 6).

Antes de considerar la app cerca de un release, ver **`docs/release-checklist.md`** — documenta
qué falta (`applicationId`, firma, dominios de testing/producción, pruebas manuales en
dispositivo físico, política de versión) y por qué esta app no está lista para publicarse todavía.

## Checklist manual — solicitud de préstamo (requiere backend real, opcional)

`POST /prestamos/solicitar` modifica la base de datos real, así que esto **no** se ejecuta
automáticamente en ningún test ni script. Para probarlo a mano, contra un backend local/testing
con una cuenta y un crédito de prueba:

- [ ] Iniciar sesión con una cuenta de cliente real.
- [ ] En Simulación, elegir un crédito real del catálogo y un monto dentro de su rango.
- [ ] Tocar "Continuar con la solicitud" y confirmar que **no** se hizo ninguna petición todavía
      (revisar logs de red del backend).
- [ ] En Revisión, dejar el aval apagado y enviar — confirmar que el body no incluye `aval`.
- [ ] Repetir con el aval activado (nombre + teléfono válidos) — confirmar que el préstamo creado
      en la base de datos tiene su registro en `avales`.
- [ ] Confirmar que la pantalla de confirmación muestra exactamente lo que devolvió el servidor
      (comparar `prestamoId`/`montoTotalAPagar` contra la fila real en `prestamos`).
- [ ] Tocar dos veces seguidas "Enviar solicitud" y confirmar en la base de datos que se creó un
      solo préstamo, no dos.
- [ ] Provocar un monto fuera de rango del crédito (editando el borrador antes de enviar, si es
      posible) y confirmar el mensaje de `VALIDATION_ERROR`.
- [ ] Agotar el límite de `SOLICITUD_RATE_LIMIT_MAX` solicitudes en la ventana configurada y
      confirmar que la app muestra el aviso de `429` (no un error técnico).
- [ ] Dejar expirar el JWT (o invalidarlo manualmente) y enviar — confirmar que la app termina en
      la pantalla de login, no en un error genérico.
- [ ] Si es posible simular un timeout de red (por ejemplo cortando la conexión justo después de
      enviar), confirmar que aparece la pantalla de resultado ambiguo y que no se reintenta solo.

## Checklist manual — Inicio/Estado/Calendario/Perfil (opcional)

- [ ] Iniciar sesión y recorrer las cinco pestañas.
- [ ] Confirmar que no aparece ningún monto ficticio (saldo, próximo pago, cuotas) en ninguna
      pantalla.
- [ ] Abrir Simulación y, solo si decides hacerlo, enviar una solicitud real contra una base de
      prueba (ver el checklist de la sección anterior).
- [ ] Confirmar que Inicio y Estado muestran la respuesta real de esa solicitud.
- [ ] Cerrar sesión.
- [ ] Volver a iniciar sesión (misma cuenta u otra).
- [ ] Confirmar que la respuesta anterior **ya no aparece** en Inicio ni en Estado.
- [ ] Reiniciar la app por completo (no solo cerrar sesión) y confirmar que, tras volver a iniciar
      sesión, la última solicitud tampoco aparece — nunca se persistió en disco.

## Paleta

| Uso                 | Color     |
|----------------------|-----------|
| Navy (marca)          | `#0C222F` |
| Verde inicio gradiente | `#0E7C61` |
| Verde fin gradiente    | `#1DA679` |
| Fondo                  | `#F4F7F8` |

## Siguientes pasos (checkpoints en curso)

Ver `docs/mobile-api-gaps.md` para lo que el backend todavía no soporta (MFA, verificación de
identidad, destino de desembolso, pagos, consulta de solicitudes propias) y por qué las
funcionalidades que dependen de eso no existen aún en esta app.
