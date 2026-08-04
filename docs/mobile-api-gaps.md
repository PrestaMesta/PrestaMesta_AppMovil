# Huecos de API para PrestaMesta_AppMovil

Estado: escrito en Checkpoint 0 (auditoría); actualizado en Checkpoints 4 y 5 solo con precisiones
objetivas confirmadas contra el código real (tipos exactos de campos, forma del `429`, ausencia de
idempotencia, dominio exclusivo de `/prestamos/solicitar`) — ninguna sección `PROPUESTA` fue
modificada. Actualizado de nuevo tras integrar `GET /client/prestamos` y
`GET /client/prestamos/:id` (préstamos del propio cliente): estas dos filas y las de
Home/Estado en la sección 2 ya no describen una limitación — el resto del documento (MFA,
identidad, disbursement, pagos) sigue sin cambios.
Fuente de verdad del contrato: `../PrestaMesta_Server/openapi.yaml` (leído completo el 2026-08-03,
releído para Checkpoints 3, 4, 5 y para esta actualización).
Todo lo marcado `PROPUESTA` en este documento es una hipótesis de diseño para discutir con el
equipo de backend, **no** un contrato existente ni un compromiso de implementación.

---

## 1. Qué existe realmente hoy en el backend

10 endpoints en total (8 + los dos de préstamos propios del cliente), dos dominios de identidad
(`clientes` / `administradores`) con audiencias JWT distintas, sin mecanismo de logout/revocación
(JWT stateless, expira via `JWT_EXPIRES_IN`, por defecto 8h), sin refresh token.

| Método | Ruta | Auth | Notas de contrato exacto |
|---|---|---|---|
| POST | `/api/v1/client/auth/register` | pública | `{nombre, email, password, telefono?}` → `201 {mensaje, clienteId}`. `409 EMAIL_ALREADY_EXISTS`. Password: 12–72 **bytes**, se rechaza fuera de rango, nunca se trunca. |
| POST | `/api/v1/client/auth/login` | pública | `{email, password}` → `200 {mensaje, token, cliente:{id,nombre,email}}`. **`telefono` no se devuelve.** `401 INVALID_CREDENTIALS` idéntico para email inexistente o password incorrecto (anti-enumeración). |
| POST | `/api/v1/admin/auth/login` | pública | Dominio admin, fuera de alcance para esta app. |
| POST | `/api/v1/admin/administradores` | admin SUPERADMIN | Fuera de alcance. |
| GET | `/api/v1/prestamos/creditos` | cliente o admin | Único endpoint de doble dominio. Devuelve `Credito[]` (`id, nombre, monto_minimo, monto_maximo, tasa_interes_anual, plazo_meses, creado_en`), todos como strings decimales excepto `id`/`plazo_meses`. |
| POST | `/api/v1/prestamos/creditos` | admin SUPERADMIN/ANALISTA | Fuera de alcance para el cliente. |
| POST | `/api/v1/prestamos/solicitar` | **cliente exclusivamente** | A diferencia de `GET /prestamos/creditos` (dual-domain), esta ruta usa `verificarTokenCliente`, no `verificarTokenClienteOAdmin` (confirmado en `routes/prestamoRoutes.js` línea 40) — un JWT de administrador, aunque válido y no expirado, es rechazado únicamente por no tener la audiencia `JWT_AUD_CLIENTE` (`utils/jwt.js#verifyClienteToken`), con `401 TOKEN_INVALID`, nunca `403 FORBIDDEN` ni un mensaje que sugiera credenciales incorrectas. `SUPERADMIN`/`ANALISTA`/`COBRADOR` no pueden solicitar préstamos bajo ninguna circunstancia. La identidad del solicitante siempre viene del `sub` verificado del token, nunca de un campo del body — por eso `LoanRequest` (lado móvil) no tiene ni tendrá un campo `clienteId`/`cliente_id`. Body: `{credito_id, monto_solicitado, aval?}` — `credito_id` entero, `monto_solicitado` **número JSON** (no string), `aval` opcional: `{nombre, telefono, direccion?, ingreso_mensual?}` (`telefono` 7–20 caracteres, confirmado en `avalSchema`, no solo en el ejemplo de OpenAPI). **Nunca envíes** `cliente_id`, `monto_total_a_pagar`, `saldo_pendiente`, `estado` — el validador Zod `.strict()` los rechaza si vienen en el body. Responde `201 {mensaje, prestamoId, fechaSolicitud, montoSolicitado, montoTotalAPagar, estado}` — **`montoSolicitado` es número JSON** (eco de lo enviado, no recalculado) **pero `montoTotalAPagar` es string decimal** (`"12400.00"`, calculado por el servidor); confirmado contra `openapi.yaml` y `controllers/prestamoController.js`, no son el mismo tipo. Rate limit propio: 10/hora por IP (`SOLICITUD_RATE_LIMIT_*`), independiente del rate limit de login; **el `429` de este limitador NO usa el envelope `{mensaje,codigo,requestId}`** — es el texto plano por defecto de `express-rate-limit` (`"Too many requests, please try again later."`, `Content-Type: text/html`), confirmado empíricamente contra el middleware real; sí incluye el header `Retry-After` (segundos) porque `standardHeaders: true`. **Esto es una discrepancia de implementación observada frente al contrato general de errores documentado abajo, no un contrato nuevo o estable** — el propio backend debería normalizarla algún día pasando este 429 por `middleware/errorHandler.js` como cualquier otro error; mientras tanto la app la tolera por compatibilidad (nunca muestra el texto plano crudo, nunca inventa `codigo`/`requestId` cuando faltan, nunca usa `Retry-After` — en cualquiera de sus formatos, o su ausencia — para reintentar automáticamente). `404 CREDIT_NOT_FOUND` si `credito_id` no existe. Sin idempotencia confirmada: no hay `Idempotency-Key` ni deduplicación server-side — un timeout de red no permite saber con certeza si la solicitud se creó. |
| PATCH | `/api/v1/prestamos/{id}/estado` | admin SUPERADMIN/ANALISTA | Fuera de alcance para el cliente. |
| GET | `/api/v1/client/prestamos` | **cliente exclusivamente** | `verificarTokenCliente` (`routes/clientePrestamoRoutes.js`) — `cliente_id` sale exclusivamente del `sub` del token verificado, nunca de query/body. Paginado (`?page`, `?limit`, default 1/20, máx. `limit=100`); un `page` más allá del total responde `200 {data: [], pagination}`, nunca `404`. Orden fijo `fecha_solicitud DESC, id DESC` (no configurable). Cada fila (`PrestamoClienteListItem`): `{id, credito:{id,nombre}, monto_solicitado, monto_total_a_pagar, saldo_pendiente, estado, fecha_solicitud, fecha_decision}` — los tres montos son **strings decimales** (columnas `DECIMAL` leídas de MySQL), a diferencia de `montoSolicitado` en la respuesta de `POST /prestamos/solicitar` (número JSON, eco del body) — asimetría real, no normalizada. Un `page`/`limit` repetido en la query (`?page=1&page=2`) responde `400 VALIDATION_ERROR`. |
| GET | `/api/v1/client/prestamos/{id}` | **cliente exclusivamente** | Mismo middleware que el listado. El filtro de propiedad (`WHERE id = ? AND cliente_id = ?`) vive en el SQL — un id inexistente y un id de otro cliente responden **exactamente** el mismo `404 LOAN_NOT_FOUND` (anti-enumeración, mismo principio que el login). Devuelve `PrestamoClienteListItem` más `aval`: `null` si el préstamo no tiene aval registrado (`LEFT JOIN` sin fila), o `{id, nombre, telefono, direccion, ingreso_mensual}` con los campos opcionales ausentes como `null` (nunca `''`/`0`) cuando sí existe. |
| GET | `/health/live`, `/health/ready` | pública | No relevante para la app cliente. |

Envelope de error uniforme: `{ mensaje, codigo, requestId, detalles? }`. Códigos estables:
`INVALID_CREDENTIALS, TOKEN_INVALID, TOKEN_EXPIRED, FORBIDDEN, VALIDATION_ERROR,
EMAIL_ALREADY_EXISTS, CREDIT_NOT_FOUND, LOAN_NOT_FOUND, INVALID_TRANSITION, NOT_FOUND,
INTERNAL_ERROR`. La app debe decidir por `codigo`, nunca por el texto de `mensaje`. **Excepción
confirmada**: el `429` de `SOLICITUD_RATE_LIMIT_*` (y de `AUTH_RATE_LIMIT_*`, mismo middleware
`express-rate-limit`) no pasa por `middleware/errorHandler.js` y por lo tanto no trae este
envelope — ver la fila de `/prestamos/solicitar` arriba.

Estado de préstamo implementado: `PENDIENTE -> APROBADO | RECHAZADO` (ambos terminales). El propio
schema OpenAPI marca `ACTIVO, PAGADO/LIQUIDADO, EN_MORA, CANCELADO` como `x-pendiente-decision` —
no existen en el enum ni en el código.

## 2. Funcionalidad móvil vs. contrato (alcance original, sin MFA/identidad)

| Funcionalidad en la UI actual | Endpoint necesario | Disponible | Decisión para esta fase |
|---|---|---|---|
| Registro de cliente | `POST /client/auth/register` | Sí | Implementar tal cual el contrato. |
| Login de cliente | `POST /client/auth/login` | Sí | Implementar tal cual. Guardar `token` en almacenamiento seguro; usar `cliente.{id,nombre,email}` para lo que la UI muestre de inmediato tras login. |
| Restaurar sesión | — (no hay endpoint `/me` ni refresh) | No | La app solo puede "recordar" el JWT guardado y reutilizarlo hasta que expire o el servidor lo rechace (401 `TOKEN_EXPIRED`/`TOKEN_INVALID`); no hay validación proactiva contra el servidor sin volver a golpear un endpoint protegido (p. ej. el catálogo). |
| Logout | — (no hay revocación server-side) | No (parcial) | Logout = borrar el token del almacenamiento seguro localmente. No hay endpoint que invalide el JWT en el servidor (JWT stateless); esto debe comunicarse como limitación conocida, no simularse. |
| Catálogo de créditos | `GET /prestamos/creditos` | Sí | Implementar tal cual. |
| Simulación de crédito | ninguno calcula `monto_total_a_pagar` sin crear una solicitud real | Parcial | La fórmula está documentada en OpenAPI (`x-formula`, interés simple anual prorrateado) y puede replicarse client-side **solo como estimación visual**, etiquetada explícitamente como "Estimación, el valor final lo calcula el servidor". No debe presentarse como autoritativo. |
| Solicitud de préstamo | `POST /prestamos/solicitar` | Sí | Implementar tal cual; UI solo envía `credito_id`, `monto_solicitado`, `aval?`. Pantalla de confirmación muestra únicamente los campos que el servidor devuelve. |
| Perfil de usuario | ningún `GET /client/me` | No | Perfil se limita a `{id, nombre, email}` obtenidos en el login/registro y guardados en memoria/estado de sesión (no hay endpoint para refrescarlos). `telefono` capturado en registro **no vuelve** en la respuesta de login, así que no se puede mostrar de forma confiable tras reiniciar la app sin re-registrar. |
| Home: préstamo más reciente | `GET /client/prestamos` | Sí | El préstamo más reciente reportado por el servidor ahora mismo (primera fila de la página 1, orden `fecha_solicitud DESC` fijo server-side) — no una copia local de la última respuesta de `POST /prestamos/solicitar`. Sigue sin existir saldo/próximo pago (eso requeriría pagos, ver abajo), así que `HomeScreen` nunca muestra esos dos campos. |
| Estado de solicitud (listado + detalle) | `GET /client/prestamos`, `GET /client/prestamos/:id` | Sí | El cliente puede listar y paginar sus propias solicitudes (actualización manual, sin auto-poll) y ver el detalle de cualquiera de ellas, incluido el aval cuando existe. `estado`/`fecha_decision` reflejan la decisión real de un admin si ya ocurrió — nunca una línea de tiempo fabricada de pasos intermedios (esos no existen en el backend). |
| Calendario de pagos | ninguno (pagos no implementados en absoluto) | No | Implementado (Checkpoint 5) como estado vacío honesto sin excepciones — `HistorialPago` existe como schema Mongoose pero no está conectado a ningún endpoint (confirmado en `PrestaMesta_Server/CLAUDE.md`), así que ni siquiera se puede afirmar "sin pagos pendientes" (requeriría un endpoint que tampoco existe). Esta pantalla no hace ninguna petición de red. |

## 3. Ampliación: MFA, step-up, identidad y destino de desembolso

**Ninguno de estos dominios tiene código, ruta, tabla, ni mención en el backend actual.** Se
confirmó recorriendo `routes/`, `controllers/`, `services/`, `repositories/`, `middleware/`,
`migrations/*.sql` y `openapi.yaml` completos: no existen archivos ni endpoints relacionados con
TOTP, MFA, step-up, verificación de identidad, OCR, selfie, prueba de vida, ni destino de
desembolso. La tabla `clientes` (migración `001_clientes.sql`) solo tiene
`id, nombre, email, password, telefono`.

Esto significa que **todo lo de esta sección es diseño para negociar con el equipo de backend**,
no una integración que la app móvil pueda completar por sí sola.

### 3.1 Separación de conceptos (para que el equipo comparta el mismo vocabulario)

| Concepto | Qué prueba | Qué NO prueba | Dónde vive la decisión |
|---|---|---|---|
| MFA remoto (TOTP) | Que el cliente controla un segundo factor registrado ante el servidor | Identidad civil | Backend (valida el código) |
| Biometría local del dispositivo | Que quien tiene el teléfono desbloqueado es quien configuró la huella/rostro del sistema operativo | Que esa persona es el titular legal de la cuenta; no sustituye MFA remoto ni step-up | Solo local, nunca autoriza nada por sí sola |
| Verificación de identidad (documento + selfie + prueba de vida) | Que un documento es auténtico y que la persona frente a la cámara coincide con él, con niveles de confianza medibles | — | Backend + proveedor especializado o revisión humana; nunca una decisión tomada enteramente en Flutter |

### 3.2 Comparación de estrategias de verificación de identidad

| Opción | Ventajas | Riesgos | Dependencia | Datos que salen del dispositivo |
|---|---|---|---|---|
| **A. Proveedor especializado** (p. ej. servicio KYC de terceros vía SDK/API) | Prueba de vida y comparación facial ya auditadas, cumplimiento regulatorio incluido, tiempo de desarrollo bajo | Costo recurrente, dependencia de disponibilidad de un tercero, requiere due diligence de privacidad/DPA antes de enviar documentos e imágenes | Alta (proveedor externo) | Documento + selfie salen hacia el proveedor, no solo hacia PrestaMesta_Server |
| **B. Backend propio** (captura + almacenamiento + revisión manual + componentes especializados de prueba de vida) | Control total de datos y flujo, sin costo recurrente por verificación | Requiere construir y mantener detección de ataques de presentación, política de retención, cifrado, revisión humana con SLA, y probablemente meses de trabajo de backend que hoy no existe | Media (solo PrestaMesta_Server, pero con mucho trabajo nuevo) | Documento + selfie quedan en infraestructura propia |
| **C. Prototipo limitado, no productivo** (captura + revisión manual básica, sin decisión automática) | Rápido de construir, útil para validar el flujo de UX antes de comprometerse a A o B | No debe presentarse como "verificado" ante el usuario ni usarse para aprobar préstamos reales | Baja | Documento + selfie a revisión manual, sin comparación automática |

**No se selecciona ninguna opción en este checkpoint** — requiere decisión de producto (presupuesto,
cumplimiento regulatorio aplicable a préstamos en México, apetito de riesgo).

### 3.3 Contratos backend propuestos (PROPUESTA, no implementados)

Todos los nombres de ruta/campos son ilustrativos, deben ajustarse al estilo real del backend
(`/api/v1/...`, envelope `{mensaje, codigo, requestId}`, Zod `.strict()`, JWT de audiencia
`prestamesta-client`) antes de construirse.

**Autenticación / MFA**
- `POST /client/auth/login` (modificado): si el cliente tiene MFA activo, responder algo como
  `200 {mensaje, mfaRequerido: true, challengeId, expiraEn}` en vez de `token` directo.
- `POST /client/auth/mfa/challenge` — envía `{challengeId, codigo}`, responde con el `token` final
  solo si el código es válido, no expiró, no se reutilizó y no se excedieron los intentos.
- `GET /client/mfa/estado` — consulta si MFA está activo.
- `POST /client/mfa/enrolar/iniciar` — genera secreto TOTP + QR, se muestra **una sola vez**.
- `POST /client/mfa/enrolar/confirmar` — confirma con el primer código TOTP válido.
- `POST /client/mfa/codigos-recuperacion/regenerar` — invalida los anteriores, requiere step-up.
- `POST /client/mfa/desactivar` — requiere step-up.

**Step-up**
- `POST /client/step-up/iniciar` `{operacion, contextoResumen?}` → `{challengeId}`.
- `POST /client/step-up/verificar` `{challengeId, factor}` → `{stepUpToken, expiraEn}`.
- El `stepUpToken` debe ir ligado server-side a: usuario, operación permitida, expiración,
  identificador único, estado de uso, y — para operaciones financieras — un resumen estable de la
  operación (monto, crédito, destino, versión de datos) para que un token emitido para "cambiar
  contraseña" no sirva para "confirmar préstamo".

**Destino de desembolso**
- `POST /client/destinos-desembolso` (requiere step-up) — tipo de destino aún por decidir con
  producto (cuenta bancaria/CLABE/tarjeta/billetera).
- `GET /client/destinos-desembolso` — devuelve representación **enmascarada** únicamente.
- `PATCH /client/destinos-desembolso/{id}/predeterminado` (requiere step-up).
- `DELETE /client/destinos-desembolso/{id}` (requiere step-up, si el producto lo permite).
- `POST /prestamos/solicitar` (modificado) referenciaría `destino_desembolso_id` en vez de repetir
  datos sensibles, y probablemente exigiría un `stepUpToken` de la operación "confirmar préstamo".

**Identidad**
- `POST /client/identidad/iniciar` — consentimiento + tipo de documento.
- `POST /client/identidad/documento` (frente/reverso) y `POST /client/identidad/selfie` — subida de
  archivo, no base64 en JSON; probablemente vía URL de carga de corta duración.
- `GET /client/identidad/estado` → uno de
  `NO_INICIADA | EN_PROCESO | PENDIENTE_REVISION | VERIFICADA | RECHAZADA | REQUIERE_REINTENTO | EXPIRADA`.
- `POST /client/identidad/reintentar`.

**Idempotencia**: `POST /prestamos/solicitar` y cualquier operación financiera nueva deberían
aceptar una clave de idempotencia (header o campo) para que un timeout de red no produzca una
solicitud duplicada al reintentar. Hoy el endpoint real no la soporta — mitigación actual en la
app (Checkpoint 4, `lib/features/loans/`): deshabilitar el botón de envío, no reintentar
automáticamente un POST financiero, y — cuando el resultado de red es genuinamente ambiguo
(timeout después de enviar, conexión interrumpida) — bloquear permanentemente ese intento de envío
en memoria (`LoanSubmissionController`) en vez de asumir éxito o fracaso. Esto es una mitigación
del lado del cliente, no idempotencia real: no sobrevive a reinstalar la app ni protege una llamada
hecha directamente contra la API.

### 3.4 Persistencia que el backend necesitaría (propuesta, no un diseño de esquema final)

Factores MFA, secretos TOTP cifrados en reposo, códigos de recuperación **con hash** (nunca texto
plano), challenges de MFA/step-up con expiración y contador de intentos, autorizaciones step-up
consumibles una sola vez, destinos de desembolso enmascarados, estados de verificación de
identidad, referencias a documentos (no los binarios en MySQL sin una decisión explícita), y
eventos de auditoría separados por tipo de evento (enrolamiento MFA, cambio/desactivación MFA, uso
de código de recuperación, cambio de destino, resultado de step-up, resultado de verificación de
identidad). Nunca en el JWT: fotografías, datos completos del destino, secretos MFA.

### 3.5 Decisiones de producto pendientes antes de poder implementar cualquier cosa de esta sección

1. ¿Se contrata un proveedor KYC (opción A) o se construye revisión propia (opción B)? Afecta
   presupuesto, cronograma y qué datos viajan a terceros.
2. ¿Qué tipos de destino de desembolso se soportan en el lanzamiento (cuenta bancaria/CLABE,
   tarjeta, otro)?
3. ¿Cambiar contraseña cierra todas las sesiones, solo las demás, o ninguna? (No hay refresh
   tokens ni tabla de sesiones hoy — esto también implica trabajo de backend nuevo.)
4. ¿Correo electrónico se usa como canal de recuperación de MFA? Requiere definir proveedor,
   caducidad, límites de reenvío y protección anti-enumeración antes de construirse.
5. ¿Qué documentos de identidad y países se aceptan en el lanzamiento? Determina qué reglas de OCR
   y validación tienen sentido — no deben inventarse expresiones regulares "universales".

## 4. Qué queda explícitamente fuera de esta fase (no por omisión, por diseño del backend)

Pagos, pagos parciales/anticipados, mora, tabla de amortización, liquidación, cancelación,
scoring, aprobación automática — todos documentados como "deliberadamente no implementados" en
`PrestaMesta_Server/CLAUDE.md`. No se tratan como bugs ni se simulan en la app móvil.
