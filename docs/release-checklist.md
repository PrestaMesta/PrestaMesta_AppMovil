# Checklist de release — PrestaMesta_AppMovil

Estado: creado en Checkpoint 6 (endurecimiento, accesibilidad, validación de release).
**Esta app no está lista para publicarse.** Este documento enumera qué falta y qué decisiones
siguen pendientes — no es una aprobación de ninguna de ellas, y ningún valor de ejemplo aquí debe
tratarse como definitivo.

---

## 1. Estado actual de funcionalidades

| Funcionalidad | Estado |
|---|---|
| Registro y login de cliente | Real, contra `PrestaMesta_Server` |
| Restauración de sesión | Real, solo local (sin `GET /client/me`) |
| Catálogo de créditos | Real |
| Estimación de préstamo | Local, explícitamente no autoritativa |
| Solicitud de préstamo (`POST /prestamos/solicitar`) | Real, aval opcional |
| Resultado ambiguo de envío (`outcomeUnknown`) | Implementado, mitigación local, no idempotencia real |
| Inicio / Estado / Calendario / Perfil | Reales, sin datos ficticios |
| MFA / step-up | **No implementado** (ni en el backend) |
| Verificación de identidad / OCR | **No implementado** (ni en el backend) |
| Destino de desembolso | **No implementado** (ni en el backend) |
| Pagos / calendario de amortización | **No implementado** (ni en el backend) |
| Consulta de solicitudes propias (historial) | **No implementado** (ni en el backend) |
| Logout con revocación server-side | **No implementado** (JWT stateless en el backend) |
| Analytics / crash reporting | No incluido (decisión deliberada hasta ahora) |

Ver `docs/mobile-api-gaps.md` para el detalle completo del contrato y las limitaciones del backend.

## 2. Pruebas requeridas antes de release

- [ ] `flutter analyze` sin errores/warnings/infos (verificado en este checkpoint: limpio).
- [ ] `flutter test` completo en verde (verificado en este checkpoint — ver total en el reporte
      de checkpoint correspondiente).
- [ ] `dart format --set-exit-if-changed` sin cambios pendientes en los archivos tocados.
- [ ] Build de release firmado con la clave real (no la de debug) — **bloqueado**, ver sección 4.
- [ ] Prueba manual en al menos un dispositivo físico Android real (no solo emulador) — ver
      sección 6.
- [ ] Prueba de conectividad real contra los dominios de testing y producción una vez existan —
      ver sección 7.
- [ ] Revisión de privacidad final (sección 5) repetida sobre el build firmado real.

## 3. `applicationId` y namespace — pendiente

El `applicationId` actual:

```
com.example.prestamesta_app
```

es el valor por defecto de la plantilla de Flutter y **bloquea un release formal** (Google Play
rechaza `com.example.*`). **No se cambió en este checkpoint.** Antes del primer release se debe
decidir y documentar aquí:

- `applicationId` definitivo (irreversible una vez publicado en Play Store sin crear una app
  nueva). Ejemplo **solo ilustrativo, no aprobado**: `mx.prestamesta.app`.
- `namespace` en `android/app/build.gradle.kts` (puede coincidir con el `applicationId` o no;
  hoy ambos son `com.example.prestamesta_app`).
- Nombre visible de la app (`android:label`, hoy `"prestamesta_app"` — no es el nombre de marca
  "PrestaMesta").
- Organización o dominio propietario real (para invertir el dominio al elegir el `applicationId`,
  p. ej. `com.prestamesta.*` si el dominio es `prestamesta.com`/`prestamesta.fun`).

## 4. Firma — pendiente

**Confirmado en este checkpoint**: `android/app/build.gradle.kts` firma el build type `release`
con `signingConfigs.getByName("debug")` (comentario del propio template: *"Signing with the debug
keys for now"*). Verificado empíricamente sobre el APK de release generado en este checkpoint con
`apksigner verify --print-certs`:

```
Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
```

Esto significa que el APK de release actual **está firmado con la clave de debug de Android**, no
con una clave de release real — no es instalable como actualización de una instalación firmada de
otra forma, y no cumple los requisitos de Play Store. Antes de un release real hace falta decidir
y documentar:

- Generar un keystore real (`keytool -genkey ...` o equivalente) — **no se generó ninguno en este
  checkpoint**, por instrucción explícita.
- Alias de la clave dentro del keystore.
- Custodia segura de las contraseñas del keystore y del alias (gestor de secretos de la
  organización, nunca en texto plano en el repositorio — `android/key.properties` y `*.jks`/
  `*.keystore` ya están en `.gitignore` desde este checkpoint para que, en cuanto exista un
  keystore real, no pueda comitearse por accidente).
- Estrategia de respaldo del keystore (perder el keystore de un release ya publicado en Play Store
  sin Play App Signing hace imposible publicar actualizaciones futuras de esa misma app).
- Si se usará **Play App Signing** (Google custodia la clave de firma final; se sube una clave de
  "upload" propia) — recomendado para nuevas apps, pero es una decisión de la organización, no
  técnica de este repositorio.

## 5. Dominios — pendiente

`EnvConfig` (`lib/core/config/env_config.dart`) ya exige `https://` para `APP_ENV=testing` y
`APP_ENV=production` — la app está lista técnicamente para apuntar a dominios reales en cuanto
existan. Lo que falta es la decisión/infraestructura, no código:

- Dominio real de la API de testing (usado en este checkpoint solo como ejemplo reservado:
  `https://api.example.invalid` — **no es un dominio real ni aprobado**).
- Dominio real de la API de producción (mismo comentario).
- Confirmar que ambos dominios sirven certificados TLS válidos antes de apuntar builds reales a
  ellos.

## 6. Revisión de privacidad

Auditado en este checkpoint (ver el reporte de Checkpoint 6 para el detalle completo):

- Único permiso de Android: `INTERNET`. Sin cámara, ubicación, contactos ni almacenamiento externo.
- JWT y `ClienteSummary` solo en `flutter_secure_storage`, nunca en `SharedPreferences`/archivos.
- `LoanDraft` y `SessionLoanSummary` solo en memoria — nunca persistidos, nunca en logs.
- `SanitizingLoggingInterceptor` redacta `Authorization`/`Cookie`/`password`/`token`/`jwt`/`email`/
  `nombre`/`telefono`/`direccion`/`ingreso`/`monto`, y solo está activo bajo `kDebugMode`.
- Sin analytics, sin crash reporting de terceros, sin SDKs de rastreo.
- Cleartext (`http://`) solo permitido en el manifest de `debug`; confirmado ausente
  (`usesCleartextTraffic`) en el manifest fusionado del APK de release real, para las cuatro
  variantes (`release`, `arm64-v8a`, `armeabi-v7a`, `x86_64`).

Antes de un release real: repetir esta revisión sobre el build firmado con la clave definitiva (no
solo el de validación de este checkpoint), y confirmar que ningún SDK nuevo agregado después de
este checkpoint introduce recolección de datos no documentada aquí.

## 7. Pruebas manuales en dispositivo físico (pendiente, no ejecutado en este checkpoint)

- [ ] Instalar el APK de debug en un dispositivo Android físico real (no emulador) y repetir el
      checklist manual de `README.md` (login, las cinco pestañas, solicitud de préstamo).
- [ ] Confirmar que `flutter_secure_storage` funciona correctamente en ese dispositivo específico
      (algunos fabricantes tienen implementaciones de Keystore con comportamientos distintos).
- [ ] Probar con el lector de pantalla del sistema (TalkBack) activado en las cinco pestañas y en
      el flujo de solicitud, no solo con las pruebas automatizadas de `Semantics`.
- [ ] Probar con el tamaño de fuente del sistema en "Grande"/"Muy grande" real (Ajustes de
      Android), no solo el `textScaler` simulado en `flutter test`.

## 8. Comprobación de conectividad testing/production (pendiente, no ejecutado en este checkpoint)

Ninguna prueba automatizada de este repositorio golpea un backend real, por diseño — así que esto
requiere verificación manual explícita antes de cada release, contra los dominios reales que
resulten de la sección 5:

- [ ] `flutter run --dart-define=APP_ENV=testing --dart-define=API_BASE_URL=https://<dominio real
      de testing>` — confirmar login/catálogo/solicitud contra el backend de testing real.
- [ ] Repetir contra producción antes de publicar cualquier build de producción.
- [ ] Confirmar que el certificado TLS de cada dominio es válido (no autofirmado) — un certificado
      inválido haría fallar todas las peticiones silenciosamente para el usuario final (la app no
      tiene ningún mecanismo de bypass de certificados, lo cual es correcto, pero significa que un
      certificado mal configurado rompe la app por completo).

## 9. Verificación de actualización y rollback (pendiente, no ejecutado en este checkpoint)

- [ ] Instalar una versión anterior, luego actualizar sobre ella (no reinstalar limpio) y
      confirmar que la sesión existente sigue siendo válida o se pide login de forma controlada.
- [ ] Confirmar que un `versionCode` más alto siempre acompaña a cada release (Play Store lo
      exige; no hay automatización de esto en este repositorio todavía).
- [ ] Definir una política de rollback: si un release tiene un bug crítico, ¿se despublica en Play
      Store, se publica un hotfix, o ambos? Esto es una decisión operativa, no técnica.

## 10. Política de versión (pendiente de decisión)

- `pubspec.yaml` declara `version: 0.1.0` (`versionName="0.1.0"`, `versionCode=1` en el APK
  verificado en este checkpoint) — un valor de desarrollo temprano, no una versión 1.0 de producto.
- No existe todavía una convención documentada de cuándo subir el `versionCode` vs. el
  `versionName`, ni una política de versionado semántico formal para esta app. Debe decidirse
  antes del primer release (p. ej., SemVer para `versionName`, incremento monotónico simple para
  `versionCode`).

## 11. Idempotencia, MFA/step-up, identidad y destino de desembolso — pendientes en el backend

Ninguno de estos existe en `PrestaMesta_Server` hoy (confirmado, no es una limitación de esta app
móvil) — ver `docs/mobile-api-gaps.md` sección 3 para el diseño propuesto (no implementado, no
aprobado) de cada uno:

- **Idempotencia** de `POST /prestamos/solicitar`: mitigada del lado del cliente (bloqueo local
  tras un resultado ambiguo, ver `lib/features/loans/presentation/loan_submission_controller.dart`)
  pero no resuelta — un timeout de red seguido de un reinicio de la app, o una llamada directa a
  la API fuera de esta app, no está protegido.
- **MFA / step-up**: no implementado en ningún lado; login es solo `email`+`password`.
- **Verificación de identidad**: no implementado en ningún lado.
- **Destino de desembolso**: no implementado en ningún lado; el backend no tiene ningún concepto
  de a dónde se deposita un préstamo aprobado.
- **Consulta de solicitudes propias**: no implementado; esta app solo puede mostrar la respuesta
  de una solicitud enviada durante la sesión actual (`SessionLoanSummary`, en memoria).
- **Pagos**: no implementado en absoluto.

**No presentes esta aplicación como lista para producción mientras falte cualquiera de las
secciones 3, 4, 5, 7, 8, 9, 10 y 11 de este documento.**
